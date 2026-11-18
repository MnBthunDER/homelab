# FortiGate fw3 — security hardening (close the .252 gateway bypass)

> **Applies on top of `fortigate-fw3-plan.md` — do not apply it alone.**
> The `mgmt-trunk-to-internet` rule (edit 1) allows anyone on the shared L2
> to egress through the fw3 if they set their gateway to `10.1.1.252`,
> bypassing the fw1's zero-trust policies. Because all legitimate double-NAT
> traffic arrives as `10.1.1.254` (the fw1's NAT address), we scope
> `srcaddr` to that single host.

## Why this is needed

The fw3's per-VLAN policies use `service ALL`, so a device that bypasses the
fw1 via `.252` gets the fw3's looser rules — e.g. a wifi-162 camera would get
full internet (the fw1 only permits it NTP via `162-ntp`/32). Restricting
edit 1 to `10.1.1.254` blocks the bypass path while preserving the
double-NAT path: the fw1 NATs every client to `10.1.1.254` before forwarding,
so that is the only source the fw3 legitimately needs to allow.

## CHANGE H1 — scope egress to the fw1's NAT address

<!-- CHANGE H1: add an address object for the fw1's NAT address, then scope
     edit 1's srcaddr to it. -->
config firewall address
    edit "ip-fw1-internal"
        set subnet 10.1.1.254 255.255.255.255
    next
end

config firewall policy
    edit 1
        set name "mgmt-trunk-to-internet"
        set srcintf "internal"
        set dstintf "wan1"
        set srcaddr "ip-fw1-internal"   <!-- was "all" -->
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
    next
end

## Order of operations

1. Apply CHANGE 0–1 from `fortigate-fw3-plan.md` (undo vwp, per-VLAN NAT
   policies).
2. Add `ip-fw1-internal` and update edit 1 `srcaddr` (this file).
3. Test: normal internet from any VLAN still works (fw1 NAT → `10.1.1.254`
   → fw3 → wan1). A host that sets its gateway to `.252` (source `10.1.1.x`)
   gets NO egress.

## Rollback

1. Set edit 1 `srcaddr` back to `"all"`.
2. Optionally delete the `ip-fw1-internal` address.

## Gotchas

- Do NOT change `srcintf` on edit 1 — fw1 traffic arrives untagged as
  `internal`; keep `srcintf "internal"`.
- The fw3 per-VLAN policies (edit 2–8, `service ALL`) remain the documented
  `.252` backup path for ground-floor clients. This hardening does not touch
  them; if you want them as strict as the fw1's rules, mirror the service
  restrictions there too.
