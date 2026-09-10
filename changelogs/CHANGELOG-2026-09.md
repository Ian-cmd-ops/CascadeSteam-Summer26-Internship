
## 2026-09-01: Hard power-loss outage recovery (correction/addition)

- Physical cabling changed during recovery: switch-to-AP2 uplink cable and AP2-to-pve-lab cable were both replaced
- Two hard shutdowns on AP2/rack (2026-08-31 00:50 and 20:59) — power outage, not attack (SSH login-failure entry from 10.0.25.X confirmed benign, netbird-gw's own IP)
- N100 ether4 port on AP2 stopped showing RUNNING (R flag) despite link-ok; correct pvid=20 was already set. Cleared by a full AP2 reboot — cable/port state issue, not a config problem
- N100 switched from DHCP to static IP 10.0.20.X/24 via /etc/netplan/50-cloud-init.yaml (dhcp4: false) to prevent future VLAN-drift lease reassignment (was seen bound to 10.0.88.X on the mgmt VLAN pool during the incident)
- pve-lab (10.0.88.X) and pve-lab-cs (10.0.88.X) both recovered via direct console access after the hard shutdowns and cable replacement
- LXC 105 (media stack) failed to start post-recovery: pre-start CIFS mount to N100 (//10.0.20.X/RAID) hadn't remounted after N100's outage, causing a missing-directory error for tobesorted. Fixed with a manual `mount /mnt/n100-raid` on pve-svc
- TODO: UPS for the rack is still not in place — this is the second hard-shutdown-driven outage; recommend prioritizing this
- TODO: LXC 105's CIFS mount has no automatic retry after a network blip — consider x-systemd.automount on the fstab entry

## 2026-09-01: Additional detail — ether4 cable

- The failed cable was flat Cat6, installed prior to Ian's ownership/setup. Flat Cat6 is prone to conductor damage from kinks, staples, tight bends — likely multiple latent failure points from the original install, not something introduced during this session. Replaced with a standard round Cat6 cable.

## 2026-09-01: Correction — ether4 root cause

- Correction to earlier entry: the N100 ether4 RUNNING-flag issue was fixed by the physical cable swap (switch-to-AP2 uplink and AP2-to-pve-lab cables replaced), not by the AP2 reboot as previously logged. The reboot coincided with the swap but was not the actual fix. Likely a degraded/failing cable on that run, possibly damaged by the two hard power-loss events.

## 2026-09-01 (end of day): Session journal — lessons learned, CascadeSTEAM changes

### What I learned today
- A switch/AP port showing `link-ok` in `/interface ethernet monitor` does NOT mean it's actually passing traffic — the RUNNING (R) flag in `/interface ethernet print` is the real signal. A degraded cable can pass cable-test and show link-ok while still failing to forward frames.
- Flat Cat6 is a real liability — prone to conductor damage from kinks/staples/tight bends. Worth treating any flat-cable run from a prior install as suspect, not just the one that failed.
- MikroTik bridge port PVID and bridge VLAN table membership are two separate things that can drift independently — a port can have the correct PVID but still be missing from the VLAN table's untagged/tagged list, breaking traffic silently.
- `systemctl enable` vs `systemctl start` matters a lot — a timer/service can be running fine in the moment but silently NOT survive the next reboot if only `start` (not `enable`) was ever run. Worth periodically auditing critical automation (`systemctl is-enabled <unit>`) rather than assuming "it's running now" means "it'll still be running after a reboot."
- Zabbix's default Apache install only aliases `/zabbix`, not root `/` — easy to mistake for a broken install when it's actually just the wrong URL path.
- ntfy topics benefit from severity separation — a flat feed mixing critical DOWN alerts with routine print-job notifications makes critical alerts easy to miss. Tiered topics (info/warn/critical) were already planned in docs but not fully wired up end-to-end.

### CascadeSTEAM (pve-lab-cs) changes
- Zabbix (CT 100) web frontend confirmed reachable — Apache serving at `/zabbix` alias (not root), package `zabbix-apache-conf` installs to `/etc/zabbix/apache.conf`
- Added Caddy route: `cs-zabbix.example.internal` → `10.0.88.X:80` (LXC 103 Caddyfile), inherits the `*.example.internal` wildcard cert automatically
- Confirmed pve-lab-cs also runs VMs 300-306 (`dummy-web/svc/db/dns/app/cache/legacy`) — a simulated multi-tier app, not previously documented, likely built for monitoring/fault-injection demo purposes
- Netbird mentor access plan finalized (not yet executed): dedicated `cs-mentor` peer group + a `/32`-scoped resource for `10.0.88.X` only (Zabbix), TCP 80, one-directional — explicitly avoiding the existing `cascadesteam` group since that's the VLAN 50 routing-peer group, not a client-access group
- Confirmed pve-lab-cs hardware: i7-6700 @ 3.40GHz (8 cores), 7.6GB RAM, 238.5GB NVMe — documented in hardware-inventory.md

### Homelab changes (recap, already logged above but consolidated here)
- N100 switched from DHCP to static IP (10.0.20.X) after a VLAN-drift/lease incident
- AP2 ether4 cable (N100's link) replaced — flat Cat6 → round Cat6
- pve-lab and pve-lab-cs recovered via direct console access after the 2026-08-31 hard power-loss outages
- LXC 105 CIFS mount to N100 manually remounted post-outage
- **rsync-snapshot.timer found DISABLED on N100** (likely a side effect of today's reboots/troubleshooting) — re-enabled with `systemctl enable --now`, confirmed will survive future reboots
- All three Proxmox hosts + N100 hardware fully documented (hardware-inventory.md)
- Zabbix (personal instance, CT 113) already has working dashboards: Global view, LXC Uptime, N100, Zabbix server, Zabbix server health — Proxmox VE by HTTP template and Linux by Zabbix agent active template both confirmed live and populating data

### Open items carried forward
- UPS for the rack — still the top-priority unresolved item, root cause of today's entire cascade
- ntfy severity-tier wiring (info/warn/critical) — designed today, not yet implemented for either the watchdog script or Zabbix
- Netbird mentor access for CascadeSTEAM — planned, not yet built in dashboard
- Zabbix credentials for personal instance — was reset/unknown, resolved via default Admin/zabbix or DB reset (confirm which)
