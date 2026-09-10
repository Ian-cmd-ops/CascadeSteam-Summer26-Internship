# 2026-08-26 — Xbox QoS deprioritization

- Added MikroTik Simple Queue `xbox-limit`, target 10.0.10.X/32
  (Xbox, VLAN 10, static DHCP lease, MAC <MAC>).
- Settings: max-limit=10M/2M, priority=8/8 (flat cap, not a
  parent/priority contention setup).
- Enabled /tool graphing queue for the router; added an explicit
  simple-queue=xbox-limit rule so the graph is guaranteed to track
  this queue specifically.
- Gotcha hit during setup: the first /queue simple add silently
  did not take. A later /queue simple set [find name=xbox-limit]
  ran with no error but matched nothing, since the queue never
  existed. /queue simple print came back empty, which is what
  caught it. Re-ran add and confirmed with print before moving on.
  Lesson: always confirm with print after add, RouterOS does not
  error on a set/find that matches zero queues.
- Next: let graphing run a few days, then compare Xbox traffic
  against the 10M/2M ceiling to decide if it needs adjusting.

## Addendum: FastTrack was bypassing everything

- Found `/ip firewall filter` rule 18 (`fasttrack-connection`,
  connection-state=established,related) had NO address restriction.
  It fasttracked any established/related forwarded connection,
  including Xbox, N100, and future Netbird-marked traffic, bypassing
  Simple Queues for all but the first few packets of each connection.
  The xbox-limit queue was very likely not actually capping anything
  before this fix.
- Added 6 explicit accept rules excluding Xbox (src/dst
  10.0.10.X), N100 (src/dst 10.0.20.X), and the Netbird
  tunnel (src/dst 10.0.25.X, UDP) from FastTrack, placed above
  the fasttrack-connection rule (now pushed to position 24).
- Hit a duplicate-rule snag mid-setup (each add ran 3x from a
  repeated paste); cleaned up with `/ip firewall filter remove
  [find where comment~"Exclude"]` and re-added once each. Final:
  exclusions at 18-23, fasttrack-connection at 24, verified via
  `print stats` that Xbox traffic hits the exclusion rules instead
  of falling through to fasttrack.
- Status: xbox-limit (10M/2M) confirmed actually capping now.
  wan-total parent, n100-priority, and Netbird mangle marking are
  designed but not yet built, waiting on actual WAN speed figure.
  Paused here to watch graphing data before further changes.
