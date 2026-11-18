# FortiGate 70F — forward internet to the 60E (NAT stays ON)

> The 70F keeps every gateway, DHCP server and LAN policy, but stops being
> the internet edge. It forwards internet egress to the 60E (which holds the
> NBN public IP and NATs) **with NAT still ON** — double NAT by design. This
> is deliberate: it is what lets the 60E get away with ZERO static routes.
> The NBN no longer lives on the 70F; `wan2`/sd-wan is decommissioned (the
> NBN is singular — no backup path).

## Direction (confirmed)

- **60E does the internet NAT** (it holds the NBN public IP on `wan1`).
- **70F internet policies repoint to `internal` but KEEP `nat enable`** — the
  70F NATs each client to `10.1.1.254`, then the 60E NATs to the public IP.
  Double NAT is intentional; it eliminates the 60E return routes entirely.
- **70F default route moves from sd-wan to `10.1.1.252`** (the 60E).
- The `internal` switch, port members, and all VLAN subinterfaces are
  UNCHANGED — the trunk and `.254` gateways stay exactly as they are.
- You're on CGNAT, so inbound port-forwarding was already impossible — the
  usual double-NAT cost (a VIP on both boxes) is moot.

## Changes (only these)

<!-- CHANGE 1: default route — replace the sd-wan default with a static via
     the 60E. The 70F now sends unknown traffic to 10.1.1.252. wan2 is
     decommissioned (no backup). -->
config router static
    edit 1
        set device "internal"
        set gateway 10.1.1.252
        set dst 0.0.0.0 0.0.0.0
        set distance 1
        unset sdwan-zone
    next
end

<!-- CHANGE 2: dismantle sd-wan (no more dual-WAN). Remove both wan members so
     the 70F no longer advertises wan2/wan1 as egresses. -->
config system sdwan
    set status disable
    config members
        delete 1
        delete 2
    end
    config health-check
        delete "Default_DNS"
        delete "Default_Office_365"
        delete "Default_Gmail"
        delete "Default_Google Search"
        delete "Default_FortiGuard"
    end
end

<!-- CHANGE 3: repoint every internet policy from `dstintf "sd-wan"` to
     `"internal"`. NAT STAYS ENABLED — this is the double-NAT design. Affected
     allow policies in your config:
       edit 2   cgnat-internet        (dmz → internal)
       edit 9   corp-internet         (a → internal)
       edit 15  pve-internet          (internal → internal)
       edit 16  unifi-internet        (internal → internal)
       edit 21  datastore-internet    (vlan-datastore → internal)
       edit 26  dmz-internet          (vlan-dmz → internal)
       edit 32  162-ntp               (wifi-162 → internal)
       edit 34  wifi-guest-internet   (wifi-guest → internal)
       edit 36  wifi-iot-internet     (wifi-iot → internal)
       edit 41  wifi-secure-internet  (wifi-secure → internal)
     Each one: dstintf → "internal" only. Do NOT touch `nat enable`. -->

<!-- CHANGE 4: the DENY rules that blocked internet via `sd-wan` also repoint
     to `internal`, so they still match and keep blocking:
       edit 17  trunk-block     (internal → internal, no NAT)
       edit 22  datastore-block (vlan-datastore → internal)
       edit 33  162-block       (wifi-162 → internal)
     (deny rules keep action deny; only dstintf changes.) -->

Example — repointing one allow policy (`edit 9`, corp-internet) and one deny rule:
```
config firewall policy
    edit 9
        set name "corp-internet"
        set srcintf "a"
        set dstintf "internal"      <!-- was "sd-wan" -->
        set srcaddr "mac-corp-hp-usb-c-dock-g5" "mac-corp-asix-usb-to-ethernet"
        set dstaddr "all"
        set schedule "always"
        set service "ALL"
        set logtraffic all
        set nat enable              <!-- UNCHANGED — double NAT is the design -->
    next
    <!-- ... repeat dstintf change for each policy in the CHANGE 3 list ... -->
end
```

## Gotchas that drive the changes

- **NAT stays ON — double NAT is deliberate.** The 70F NATs clients to
  `10.1.1.254`; the 60E NATs again to the public IP. Because every source the
  60E sees is `10.1.1.254` (directly connected), the 60E needs NO return
  routes for the 70F-only subnets (`a` 172.16.100.0/24, vlan-datastore
  10.1.10.0/24, cgnat dmz 100.98.40.0/24). Do NOT flip these to `nat disable`
  unless you also add those routes back on the 60E.
- **Do NOT add a blanket catch-all.** It is first-match and would override
  the deny rules (`trunk-block`/17, `datastore-block`/22, `162-block`/33).
  Repoint each existing policy individually.
- **`dstintf "internal"` is intentional for both allow and deny.** It is the
  70F's L3 interface toward `10.1.1.252`; policy ordering is preserved (e.g.
  `162-ntp`/32 still precedes `162-block`/33, so NTP passes and the rest is
  denied).

## Order of operations

1. Apply the 60E changes first (see `fortigate-60e-plan.md`) — pre-stage.
2. On the 70F: repoint the default route (CHANGE 1) → `10.1.1.252`.
3. Dismantle sd-wan (CHANGE 2) — remove both wan members.
4. Repoint the internet + deny policies (CHANGE 3 & 4) to `internal` (NAT on).
5. Test via the EoP rig: feed 60E `wan1` from the upstairs DSL path (EoP leg
   into `wan1`, other leg at the 70F `wan2`) — the 70F NATs and forwards, the
   60E NATs again (double NAT).
6. Cutover (when NBN is ready): swap the EoP leg on 60E `wan1` for the NBN ONT.
7. Test internet from: a shared-VLAN client (wifi), lan-corp (`a`), a
   cgnat/dmz host, and a vlan-datastore host — all must NAT via the 60E.

## Rollback

1. Unplug the NBN/EoP from 60E `wan1` and restore the DSL path to 70F `wan2`.
2. Restore the sd-wan default route (`set sdwan-zone "sd-wan"`) and re-add
   sd-wan members 1 (`wan2`) and 2 (`wan1`).
3. Flip the 13 policies back to `dstintf "sd-wan"` (`nat` was left enabled
   the whole time, so no NAT changes needed on rollback).
