# FortiGate fw3 — internet edge (NAT)

> fw3 holds the NBN public IP on `wan1` and NATs **all** internet egress for
> both floors. The fw1 keeps every gateway, policy and DHCP server and ALSO
> NATs on the way through — **double NAT is the design**, and it is exactly
> what removes every return route from this box. (You're on CGNAT, so the
> usual double-NAT downside — inbound port-forwarding needs a VIP on both
> boxes — is already moot.)

## Why this design (not a transparent pipe)

The transparent-pipe / vwp approach was tried and **rejected on-box**:
FortiOS will not accept a VLAN sub-interface over the `internal` hardware
switch as a virtual-wire-pair member (`entry not found in datasource`), and
there is only one inter-floor cable (no second run for a dedicated WAN
bridge). The Virtual-VLAN-switch feature that *could* tag the NBN into a
VLAN on the switch fabric is **not supported on the fw3** in FortiOS 7.4
(supported list: 40F/50G/60F/70F/.../140E). So the NBN terminates
on the fw3, and NAT lives on whichever box holds the public IP.

## How it works (double NAT — no return routes)

```
client → fw1 VLAN gateway (.254) → fw1 policy dstintf "internal" (NAT on → 10.1.1.254)
  → 10.1.1.252 via trunk → fw3 "internal" (.252) → NAT policy → wan1 (NBN) → internet
```

The fw1 NATs every client to `10.1.1.254` before forwarding, so the fw3 only
ever sees a **directly-connected** source. Replies come back to `10.1.1.254`
(a connected subnet) and the fw1 un-NATs and delivers. The fw1-only subnets
(`a` 172.16.100.0/24, vlan-datastore 10.1.10.0/24, cgnat dmz 100.98.40.0/24)
never appear as sources on the fw3 — **so the fw3 needs ZERO static routes.**

## What fw3 currently has

- `wan1` = DHCP (currently unused; the NBN ONT plugs in here on cutover — test-feed via EoP until then)
- **No** firewall policies, **no** static routes
- `.252` VLAN subinterfaces on `internal` (shared L2 with the fw1 — keep
  them; the fw3 needs the connected routes so replies to shared-L2 clients
  go directly out L2)

## Changes (only these)

<!-- CHANGE 0: undo the abandoned vwp attempt. Delete the `wan` VLAN
     sub-interface (id 7) if you created it, delete the `wan-pipe` vwp if it
     was created, and restore wan1 to DHCP. -->
config system interface
    delete "wan"
end
config system virtual-wire-pair
    delete "wan-pipe"
end
config system interface
    edit "wan1"
        set mode dhcp
        set allowaccess ping
        set type physical
        set role wan
    next
end

<!-- CHANGE 1: one outbound NAT policy per source interface (kept separate
     instead of one multi-srcintf rule so each VLAN is independently visible).
     The "internal" policy is the critical one — fw1-forwarded traffic arrives
     untagged via the trunk as srcintf "internal", so it MUST have its own
     rule; a per-VLAN srcintf like "wifi-iot" alone never matches it. The
     VLAN policies catch ground-floor clients that use a .252 gateway. These
     are the ONLY policies on the fw3. -->
config firewall policy
    edit 1
        set name "mgmt-trunk-internet"
        set srcintf "internal"
        set dstintf "sd-wan"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
    edit 2
        set name "vlan-dmz-internet"
        set srcintf "vlan-dmz"
        set dstintf "sd-wan"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
    edit 3
        set name "vlan-prod-internet"
        set srcintf "vlan-prod"
        set dstintf "sd-wan"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
    edit 4
        set name "vlan-pve-internet"
        set srcintf "vlan-pve"
        set dstintf "sd-wan"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
    edit 5
        set name "wifi-162-internet"
        set srcintf "wifi-162"
        set dstintf "sd-wan"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
    edit 6
        set name "wifi-guest-internet"
        set srcintf "wifi-guest"
        set dstintf "sd-wan"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
    edit 7
        set name "wifi-iot-internet"
        set srcintf "wifi-iot"
        set dstintf "sd-wan"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
    edit 8
        set name "wifi-secure-internet"
        set srcintf "wifi-secure"
        set dstintf "sd-wan"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
end

## Gotchas

- **`srcintf "internal"` is mandatory** — the `mgmt-trunk-to-internet` rule
  (edit 1) must exist; fw1-forwarded traffic never arrives as a VLAN srcintf.
- **No return routes — ever.** The fw1 NATs everything to `10.1.1.254`
  (connected on the fw3). The fw1-only subnets (`a`, vlan-datastore, cgnat
  dmz) are invisible to the fw3's routing table. If you later flip the fw1
  to single NAT (`nat disable`), THIS box needs the 3 return routes back.
- **These are the only allow policies.** Everything else is implicitly denied —
  the fw3 must not route between VLANs or accept anything else.
- **Throughput.** All house egress now traverses the 2017-era fw3. Keep
  security profiles light if the NBN speed matters (the fw1 is the
  faster box).

## Order of operations

1. Apply CHANGE 0–1 on the fw3 (pre-stage — NBN not live yet).
2. Apply the fw1 changes (see `fortigate-fw1-plan.md`).
3. Test via the EoP rig: plug one powerline leg into fw3 `wan1`, the other end
   into the upstairs DSL path (fw1 `wan2`). The fw3 now NATs egress over the
   simulated WAN — same forwarding path as the real NBN.
4. Cutover (when NBN is ready): unplug the EoP leg from fw3 `wan1` and plug in
   the NBN ONT. `wan1` re-DHCPs on the NBN public IP; nothing else changes.
5. Verify:
   - fw3 `get system interface wan1` — lease acquired.
   - Internet from a shared-VLAN client (wifi), lan-corp (`a`), a cgnat dmz
     host, and a vlan-datastore host — all NAT'd through the fw3 (double NAT).
   - `diagnose sniffer` on wan1 / log the NAT policy to confirm egress.

## Rollback

1. Unplug the NBN/EoP from fw3 `wan1` and restore the DSL path to the fw1's
   `wan2`.
2. fw1: restore the sd-wan default route and sd-wan members; flip the 13
   policies back to `dstintf "sd-wan"` (`nat` was left enabled the whole time).
3. fw3: delete the 8 NAT policies (edit 1–8).
