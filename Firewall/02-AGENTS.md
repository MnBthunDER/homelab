# AGENTS.md - Fibre Upgrade Plan

## What this repo is

Homelab network infrastructure documentation. Six Markdown files — no code, no CI, no tests.

- `PLAN.md` — high-level topology.
- `fortigate-fw3.md` / `fortigate-fw1.md` — live (current) `config system interface` + `config router static` dumps for each firewall. Canonical source of truth for deployed state.
- `fortigate-fw3-plan.md` / `fortigate-fw1-plan.md` — proposed configs for the WAN migration (moving the NBN line from the fw1's `wan2` to the fw3's `wan1`; the fw3 becomes the internet edge and NATs all egress, the fw1 forwards with NAT ON — intentional double NAT). Changed lines are marked with `<!-- CHANGE -->` comments.

## Architecture

Both firewalls share a unified L2 domain via an inter-floor trunk. Each has a `mgmt-trunk` hardware switch bridging all ports and carrying all VLANs.

### fw1 — core router

- `internal` hardware switch (alias `mgmt-trunk`): `10.1.1.254/24`, members `internal1-5`
  - `internal1-3` → Proxmox hosts
  - `internal4` → UniFi AC Pro (2nd floor)
  - `internal5` → uplink to fw3 (inter-floor trunk)
- All VLAN subinterfaces under `internal`:
  - vlan‑pve (20): `10.1.20.254/24`
  - vlan‑prod (30): `10.1.30.254/24`
  - vlan‑dmz (40): `10.1.40.254/24`
  - wifi‑162 (101): `172.16.101.254/24`
  - wifi‑guest (100): `192.168.100.254/24`
  - wifi‑iot (103): `172.16.103.254/24`
  - wifi‑secure (102): `172.16.102.254/24`
- `wan2` = current DSL internet (active now; decommissioned after migration — the NBN FTTP is NEW, terminates ground floor, and plugs into the fw3's `wan1`)
- `wan1` = spare (DHCP, unused; removed from sd-wan after migration)
- `a` = lan-corp (`172.16.100.254/24`)
- `b` = carries `vlan-datastore` (10) → `10.1.10.254/24`
- `dmz` physical port with CGNAT (`100.98.40.254/24`)

### fw3 — ground floor WAN edge

- `internal` hardware switch (alias `mgmt-trunk`): `10.1.1.252/24`, members `internal1, internal5`
  - `internal1` → UniFi U6 Pro (ground floor)
  - `internal5` → uplink to fw1
- Same VLAN subinterfaces as fw1, with `.252` IPs:
  - vlan‑pve: `10.1.20.252/24`, vlan‑prod: `10.1.30.252/24`, etc.
- `wan1` = NBN (DHCP) — becomes the NAT'd internet edge after migration; the NBN ONT connects here (tested pre-NBN via an EoP/powerline feed from the upstairs DSL)
- `dmz` = `10.10.10.1/24` (unused mgmt segment)
- No firewall policies except the 8 per-VLAN `*-to-internet` NAT policies (post-migration)
- The `.252` VLAN subinterfaces are retained post-migration — the fw3 needs the connected routes so replies to shared-L2 clients go out directly (do not delete them)
## Key VLANs

| VLAN |      Subnet      |         Aliases                    |
|------|------------------|------------------------------------|
| 20   |    10.1.20.0/24  | pve (Proxmox VM traffic)           |
| 30   |    10.1.30.0/24  |         production                 |
| 40   |    10.1.40.0/24  |            dmz                     |
| 100  | 192.168.100.0/24 |         wifi-guest                 |
| 101  | 172.16.101.0/24  |         wifi-162                   |
| 102  | 172.16.102.0/24  |         wifi-secure                |
| 103  | 172.16.103.0/24  |         wifi-iot                   |
| 10   | 10.1.10.0/24     | datastore (on port `b`, fw1 only)              |

Both gateways live on the same L2 per VLAN. DHCP determines which client uses. Currently all DHCP points to `.254` (fw1) so policy enforcement stays on the fw1.

## WAN migration (see fortigate-*-plan.md)

Goal: make the fw3 (ground floor) the internet edge so the NEW NBN FTTP — which terminates ground floor — plugs into `wan1`; cut over from the current DSL once the design is proven. The fw3 holds the public IP on `wan1` and NATs ALL egress for both floors. The fw1 keeps every gateway, policy and DHCP server but forwards internet egress to the fw3 with NAT **ON** — intentional double NAT (the fw1 NATs clients to `10.1.1.254`, the fw3 NATs again). Double NAT is what lets the fw3 use ZERO static routes. You're on CGNAT, so inbound port-forwarding is already impossible and the double-NAT trade-off costs nothing.

Pre-NBN testing: feed the fw3's `wan1` over an EoP (ethernet-over-power) link from the upstairs DSL path (fw1 `wan2`). This exercises the real forwarding/NAT path. On cutover, swap the EoP leg for the NBN ONT on `wan1`.

```
client → fw1 VLAN gateway (.254) → policy dstintf "internal" (NAT on → 10.1.1.254)
  → trunk → fw3 "internal" (.252) → NAT policy → wan1 (NBN) → internet
```

Changes touch ONLY:

- **fw3**: `wan1` = DHCP (NBN); add per-VLAN internet NAT policies — `internal` plus each of the 7 VLANs → `wan1` (`nat enable`). **No static routes.**
- **fw1**: default route sd-wan → static via `10.1.1.252`; dismantle sd-wan; repoint all 13 `dstintf "sd-wan"` policies → `"internal"` keeping `nat enable` (the 3 deny rules keep deny).

**Gotcha — do NOT attempt a transparent-pipe/vwp passthrough.** It was tried and rejected on-box: FortiOS will not accept a VLAN sub-interface over the `internal` hard-switch as a virtual-wire-pair member (`entry not found in datasource`), and there is only one inter-floor cable (no second run for a dedicated WAN bridge). The Virtual-VLAN-switch feature that could tag the NBN into a VLAN is **not supported on the fw3** in FortiOS 7.4 (supported list: 40F/50G/60F/70F/.../140E). So the NBN must terminate on the fw3, and NAT lives on whichever box holds the public IP — the fw3.

**Gotcha — the fw3 NAT policy `srcintf` MUST include `"internal"`.** fw1-forwarded traffic arrives untagged as `internal`, never as a VLAN srcintf — a per-VLAN srcintf like `"wifi-iot"` never matches and fw1 traffic is dropped by implicit deny.

**Gotcha — the fw3 needs NO return routes (because of double NAT).** The fw1 NATs every client to `10.1.1.254` before forwarding, so `a` 172.16.100.0/24, vlan-datastore 10.1.10.0/24 and cgnat `dmz` 100.98.40.0/24 never appear as sources on the fw3. Replies go back to the directly-connected `10.1.1.0/24`. Do NOT flip the fw1 to `nat disable` unless you add those 3 routes back on the fw3.

**Gotcha — fw1 internet policies: NAT STAYS ON, no blanket catch-all.** Turning `nat enable` → `nat disable` on the 10 allow policies would break the double-NAT symmetry and blackhole the fw1-only subnets (no return routes exist). A catch-all is first-match and would override the deny rules (`trunk-block`/17, `datastore-block`/22, `162-block`/33). Repoint each of the 13 policies individually.

**Gotcha — throughput.** All egress now traverses the weaker 2017-era fw3. The fw1 is the newer/faster box; keep security profiles on the fw3 light if NBN speed matters.

## Editing config

- `fortigate-fw3.md` / `fortigate-fw1.md` are live FortiGate CLI dumps — the canonical deployed state. Update them to match reality.
- `fortigate-fw3-plan.md` / `fortigate-fw1-plan.md` are the proposed WAN-migration configs (fw3 does the internet NAT; fw1 double-NATs through). Lines to apply are marked `<!-- CHANGE -->`.
- Traffic on the unified L2 domain means both firewalls see the same broadcast domains. DHCP server should stay on the fw1 to control which gateway clients use.

## No toolchain

No build, test, lint, typecheck, or format commands exist. Editing `.md` files is the entire workflow.