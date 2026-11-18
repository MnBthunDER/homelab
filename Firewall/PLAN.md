Objective: Secure, segmented network infrastructure with unified L2 domain across both floors.

## Topology

```
                          ┌──────────────────┐
                          │   70F (2nd fl)   │
                          │  mgmt-trunk      │
                          │  10.1.1.254/24   │
                          │  ├─ int1: PVE 1  │
                          │  ├─ int2: PVE 2  │
                          │  ├─ int3: PVE 3  │
                          │  ├─ int4: AC Pro │
                          │  └─ int5: trunk──╫───┐
                          │  default → 60E   │   │
                          │  (10.1.1.252)    │   │
                          └──────────────────┘   │
                                                 │
                                            inter-floor
                                            trunk (L2)
                                     all VLANs + mgmt
                                                 │
                          ┌──────────────────┐   │
                          │   60E (ground)   │   │
                          │  mgmt-trunk      │   │
                          │  10.1.1.252/24   │   │
                          │  ├─ int1: U6 Pro │   │
                          │  └─ int5: trunk──╫───┘
                          │  wan1 = NBN      │
                          │  (DHCP + NAT)    │
                          └──────────────────┘
```

Post-migration: the 70F keeps every gateway (`*.254`), policy and DHCP
server, but its default route and internet policies point at the 60E
(`10.1.1.252`) with NAT on (double NAT). The 60E holds the NBN public IP on
`wan1` and NATs all egress. A transparent-pipe/vwp pass-through was tried
and rejected on-box (FortiOS won't accept a VLAN over the `internal`
hard-switch as a vwp member, and there's only one inter-floor cable), so NAT
lives on the 60E.

## Current state

- **70F** has all VLAN gateways (`*.254`), all firewall policies, and the current DSL internet on `wan2` (active).
- **60E** has the same VLANs with `*.252` IPs on a shared L2 domain. Used as ground-floor AP extension. No policies yet.
- **Inter-floor trunk** connects `internal5` on both sides, carrying all VLANs.
- **DHCP** on the 70F assigns `*.254` as gateway — all traffic flows through 70F for policy enforcement.

## Future — WAN migration

Make the 60E the internet edge for the NEW NBN FTTP (terminates ground floor, plugs into `wan1`); cut over from the current DSL once the design is proven. The 60E holds the NBN public IP on `wan1` and NATs all egress; the 70F keeps every gateway, policy and DHCP server but forwards internet to the 60E with NAT **ON** — intentional double NAT that lets the 60E use ZERO static routes (the 70F NATs clients to `10.1.1.254`, a directly-connected subnet on the 60E):

- 60E: per-VLAN NAT policies (`internal` + each VLAN → `wan1`). No routes.
- 70F: default route → `10.1.1.252`; dismantle sd-wan; repoint the 13 `dstintf "sd-wan"` policies → `internal`, NAT stays on.

Pre-NBN testing feeds the 60E's `wan1` over an EoP/powerline link from the upstairs DSL (70F `wan2`); on cutover the EoP leg is swapped for the NBN ONT.

See `fortigate-60e-plan.md` / `fortigate-70f-plan.md` for exact CLI changes (marked `<!-- CHANGE -->`).
