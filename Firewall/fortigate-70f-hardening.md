# FortiGate 70F — security hardening (restore mgmt-trunk zero-trust)

> **Applies on top of `fortigate-70f-plan.md` — do not apply it alone.**
> The WAN migration repoints the internet policies from `dstintf "sd-wan"`
> to `dstintf "internal"`. That one-word change has a side effect:
> `dstaddr "all"` now also matches the directly-connected `10.1.1.0/24`
> mgmt-trunk, which the `sd-wan` policies could never reach. This rule
> restores the original posture.

## Why this is needed

`srcaddr` and `service` on the internet policies are unchanged by the
migration, so this is NOT "allow everything everywhere". But
`dstaddr "all"` + `dstintf "internal"` expands the reachable set from
"internet only" to "internet + the mgmt-trunk subnet" — before the repoint,
`dstintf "sd-wan"` could only egress the WANs.

`10.1.1.0/24` is the management plane:

- PVE mgmt: `10.1.1.1`–`10.1.1.4` (`ip-mgmt-pve1`–`4`)
- Firewall mgmt: `10.1.1.254` (70F), `10.1.1.252` (60E), `10.1.1.253` (OPNsense)
- AP mgmt: `10.1.1.101` (AC Pro), `10.1.1.102` (U6 Pro)

Affected source VLANs gain new reachability to `10.1.1.0/24`:

| Policy                     | srcintf        | service       |
|----------------------------|----------------|---------------|
| `cgnat-internet` / 2       | dmz (cgnat)    | ALL           |
| `datastore-internet` / 21  | vlan-datastore | HTTPS/NTP/DNS |
| `dmz-internet` / 26        | vlan-dmz       | ALL           |
| `162-ntp` / 32             | wifi-162       | NTP           |
| `wifi-guest-internet` / 34 | wifi-guest     | ALL           |
| `wifi-iot-internet` / 36   | wifi-iot       | ALL           |
| `wifi-secure-internet` / 41| wifi-secure    | ALL           |

`a` (lan-corp) is deliberately NOT blocked — `corp-trunk`/8 already grants
it full mgmt access by design.

## CHANGE H1 — deny rule

<!-- CHANGE H1: place this rule AFTER `noc`/1 (so the cgnat PING-to-APs rule
     still matches first) and BEFORE `cgnat-internet`/2. In CLI, add the
     policy, then `move 90 after 1`. -->
config firewall policy
    edit 90
        set name "block-vlans-to-mgmt-trunk"
        set srcintf "dmz" "vlan-dmz" "vlan-datastore" "wifi-162" "wifi-guest" "wifi-iot" "wifi-secure"
        set dstintf "internal"
        set srcaddr "all"
        set dstaddr "nw-mgmt-trunk"
        set schedule "always"
        set service "ALL"
        set action deny
        set logtraffic all
    next
end
# move 90 after 1

## Order of operations

1. Apply CHANGE 1–4 from `fortigate-70f-plan.md` (default route, sd-wan
   dismantle, policy repoints to `internal`).
2. Add edit 90 and `move 90 after 1` (this file).
3. Test: from a wifi-guest / wifi-iot / wifi-secure client, `ping 10.1.1.1`
   must FAIL; `ping 1.1.1.1` must still work. Confirm `noc` still PINGs the
   APs (10.1.1.101/.102).

## Rollback

1. `config firewall policy` → `delete 90`.

## Gotchas

- The deny MUST precede the repointed internet allows (edits
  2/21/26/32/34/36/41), or first-match lets `dstaddr all` through first.
- It MUST follow `noc`/1, or the cgnat PING to the APs breaks.
- Reverse (stateful) traffic for RTSP / established sessions is unaffected —
  they are not re-evaluated against the new deny.
