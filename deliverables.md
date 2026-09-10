# Deliverables

## 1. Automated laptop backup and recovery
- Pull-based rsync hardlink snapshots from the laptop to the N100 NAS.
- Runs every 15 minutes when the laptop is reachable. LAN first, Netbird mesh second.
- Read-only rrsync scoping on the laptop. ntfy alerts on failure.
- Full restore drill completed on 2026-08-14 over the mesh.
- Repo: rsync-snapshot (script, systemd units, README, DESIGN, TROUBLESHOOTING, ACCEPTANCE, RESTORE-PLAYBOOK, bats tests, journal).
- Status: working. Open item: second hardware token and off-site escrow copy.

## 2. Remote access
- Netbird mesh replaced Tailscale. Gateway LXC 110 on pve-svc.
- Scoped policies: laptop reaches home VLANs, family peer reaches one service, phone reaches Caddy on 443 only.
- Internal services on a Let's Encrypt wildcard cert (DNS-01 via Cloudflare) behind Caddy.
- Status: working.

## 3. Monitoring (Zabbix)
- pve-lab-cs (Cascade STEAM host): Zabbix 7.0 LTS in CT 100. Six dummy LXCs (web, svc, db, dns, app, cache) as a Lab Fleet. chaos-monkey service for alert testing.
- pve-svc: Zabbix CT 113 monitoring Proxmox (API), Docker on N100, MikroTik via SNMP, DHCP leases via RouterOS REST API.
- BMS PVE1: Zabbix 7.4 Docker stack in CT 105 at <BMS-IP>. Deployment guide and SNMP security guide published.
- BMS monitoring proposal (Word doc): six services evaluated, Agent 2 and pull checks chosen, Feenics API licensing flagged.
- Status: working. Open item: mentor Netbird access to CT 100.

## 4. Centralized logging
- CT 115 logsink on pve-lab. rsyslog TCP 514, per-host dated files on a dedicated NVMe.
- Daily seal (chattr +a) and sha256 manifest with ntfy on mismatch.
- All LXCs across three hosts forward to it. Samba audit logging on the N100 share.
- Status: working.

## 5. Documentation
- Append-only changelogs, journals, runbooks, IP table, network topology diagram, hardware inventory.
- Repos: homelab-docs, home-docs.
- Status: current as of 2026-09-08.

## 6. Network
- MikroTik Controller and AP2 VLAN layout rebuilt and documented after two outages.
- IPv6 black hole root-caused and fixed. QoS and FastTrack exclusions in place.
- VLAN 50 (CascadeSTEAM) L2 path: open item.
