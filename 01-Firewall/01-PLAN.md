Objective: Design a secure, segmented network with a unified Layer 2 domain spanning both floors, operating within the constraint of a single 1Gbps inter-floor uplink.
## Topology

```
                          ┌──────────────────┐
                          │   fw1 (2nd fl)   │
                          │  mgmt-trunk      │
                          │  10.1.1.254/24   │
                          │  ├─ int1: PVE 1  │
                          │  ├─ int2: PVE 2  │
                          │  ├─ int3: PVE 3  │
                          │  ├─ int4: AC Pro │
                          │  └─ int5: trunk──╫───┐
                          │  default → fw2   │   │
                          │  (10.1.1.252)    │   │
                          └──────────────────┘   │
                                                 │
                                            inter-floor
                                            trunk (L2)
                                     all VLANs + mgmt
                                                 │
                          ┌──────────────────┐   │
                          │   fw3 (ground)   │   │
                          │  mgmt-trunk      │   │
                          │  10.1.1.252/24   │   │
                          │  ├─ int1: U6 Pro │   │
                          │  └─ int5: trunk──╫───┘
                          │  wan1 = NBN      │
                          │  (DHCP + NAT)    │
                          └──────────────────┘
```
# fw1 interfaces
| vlanid | interface | mode        | usage                | ip/netmask        |
|  ----- |  -------- |  ---------- |  ------------------- |  ---------------- |
| n/a    | int A     | interface   | lan-corp             | 172.16.100.254/24 |
| 10     | int B     | vlan        | datastore            | 10.1.10.0/24      |
| n/a    | int 1-3   | vlan switch | mgmt-pve             | 10.1.1.0/24       |
| 20     | int 1-3   | vlan        | vlan-pve             | 10.1.20.0/24      |
| 30     | int 1-3   | vlan        | vlan-prod            | 10.1.30.0/24      |
| 40     | int 1-3   | vlan        | vlan-dmz             | 10.1.40.0/24      |
| 50     | int 1-3   | vlan        | vlan-guest           | 10.1.50.0/24      |
| n/a    | int 4     | vlan switch | UniFI AP             | 10.1.1.101/32     |
| 100    | int 4     | vlan        | wifi-guest           | 192.168.100.0/24  |
| 101    | int 4     | vlan        | wifi-162 (cctv)      | 172.16.101.0/24   |
| 102    | int 4     | vlan        | wifi-secure          | 172.16.102.0/24   |
| 103    | int 4     | vlan        | wifi-iot             | 172.16.103.0/24   |
| n/a    | int 5     | vlan switch | trunk                | 10.1.1.254/32     |
| n/a    | dmz       | interface   | cgnat (Lab Internet) | 100.98.49.0/24    |
| n/a    | wan1      | interface   | unused               | dhcp              |
| n/a    | wan2      | interface   | unused               | dhcp              |

# fw3 interfaces
| vlanid | interface | mode        | usage    | ip/netmask    |
| :----- | :-------- | :---------- | :------- | :------------ |
| n/a    | int 1     | vlan switch | UniFi AP | 10.1.1.102/32 |
| n/a    | int 5     | vlan switch | trunk    | 10.1.1.252/32 |
| n/a    | wan1      | sd-wan      | ISP      | dhcp          |
| n/a    | wan2      | sd-wan      | unused   | n/a           |        

Post-migration: the fw1 keeps every gateway (`*.254`), policy and DHCP
server, but its default route and internet policies point at the fw3
(`10.1.1.252`) with NAT on (double NAT). The fw3 holds the NBN public IP on
`wan1` and NATs all egress. A transparent-pipe/vwp pass-through was tried
and rejected on-box (FortiOS won't accept a VLAN over the `internal`
hard-switch as a vwp member, and there's only one inter-floor cable), so NAT
lives on the fw3.

## Current state

- **fw1** has all VLAN gateways (`*.254`), all firewall policies, and the current DSL internet on `wan2` (active).
- **fw3** has the same VLANs with `*.252` IPs on a shared L2 domain. Used as ground-floor AP extension. No policies yet.
- **Inter-floor trunk** connects `internal5` on both sides, carrying all VLANs.
- **DHCP** on the fw1 assigns `*.254` as gateway — all traffic flows through fw1 for policy enforcement.

## Future — WAN migration

Make the fw3 the internet edge for the NEW NBN FTTP (terminates ground floor, plugs into `wan1`); cut over from the current DSL once the design is proven. The fw3 holds the NBN public IP on `wan1` and NATs all egress; the fw1 keeps every gateway, policy and DHCP server but forwards internet to the fw3 with NAT **ON** — intentional double NAT that lets the fw3 use ZERO static routes (the fw1 NATs clients to `10.1.1.254`, a directly-connected subnet on the fw3):

- fw3: per-VLAN NAT policies (`internal` + each VLAN → `wan1`). No routes.
- fw1: default route → `10.1.1.252`; dismantle sd-wan; repoint the 13 `dstintf "sd-wan"` policies → `internal`, NAT stays on.

Pre-NBN testing feeds the fw3's `wan1` over an EoP/powerline link from the upstairs DSL (fw1 `wan2`); on cutover the EoP leg is swapped for the NBN ONT.

See `fortigate-fw3-plan.md` / `fortigate-fw1-plan.md` for exact CLI changes (marked `<!-- CHANGE -->`).

