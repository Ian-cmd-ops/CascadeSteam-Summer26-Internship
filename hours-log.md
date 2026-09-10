# Internship Hours Log

Cascade STEAM Service Corps, Technology Intern. CIS 190, WCC, Summer 2026.

| Date | Hours | Category | Work |
|---|---|---|---|
| 2026-07-14 | 4 | Research | Backup tooling research: restic vs rsync vs tar/dd vs Proxmox backup; SFTP vs rest-server; living-off-the-land constraint; Netbird vs Tailscale vs WireGuard for remote path |
| 2026-07-17 | 5 | Meetings | Cascade STEAM Friday standup and on-site work at Bellingham Makerspace (progress review, mentor check-in, community group coordination) |
| 2026-07-21 | 5.5 | Backup / Recovery | Backup session 1 (from worklog 13:30-17:00, 20:00-22:00): Netbird routing peer LXC, laptop and N100 enrolled, SSH keys, restic repo over SFTP, first full backup (23.8 GiB), restore verified, passphrase escrowed |
| 2026-07-23 | 3 | Backup / Recovery | Daily systemd timer and prune policy for restic; Netbird mesh audit; found SSH alias pointing at LAN IP; LXC 110 rebuilt as netbird-gw on pve-svc; Gitea SSH on port 2222 working |
| 2026-07-24 | 4 | Networking | Root-caused IPv6 black hole on MikroTik (ND advertised with no upstream); Netbird Networks and policies live; off-network backup verified from two foreign networks |
| 2026-07-24 | 5 | Meetings | Cascade STEAM Friday standup and on-site work at Bellingham Makerspace (progress review, mentor check-in, community group coordination) |
| 2026-07-25 | 2 | Admin | Learning Placement Form revision: five learning outcomes rewritten to CIS outcomes, job description rewritten, hours section corrected |
| 2026-07-29 | 2 | Documentation | DNS-01 wildcard cert plan (example.internal, Cloudflare, xcaddy); cloned csdocs repo; reviewed plan doc duties |
| 2026-07-29 | 2 | Research | Wildcard cert options: DNS-01 challenge, Cloudflare API token scope, xcaddy Cloudflare module, MikroTik regexp DNS |
| 2026-07-30 | 3 | Infrastructure | Wildcard *.example.internal cert live via Let's Encrypt DNS-01; custom Caddy build; 18 site blocks migrated; MikroTik regexp DNS |
| 2026-07-30 | 2 | Networking | Netbird DNS over VPN debugging: nameserver route, 10.0.10.X/32 resource, MikroTik input-chain DNS rules; off-network access verified; hours log reconciled |
| 2026-07-31 | 5 | Meetings | Cascade STEAM Friday standup and on-site work at Bellingham Makerspace (progress review, mentor check-in, community group coordination) |
| 2026-08-07 | 2 | Networking | Asymmetric route recurrence; persistent ip rule fix via networkd-dispatcher hook on N100 |
| 2026-08-07 | 5 | Meetings | Cascade STEAM Friday standup and on-site work at Bellingham Makerspace (progress review, mentor check-in, community group coordination) |
| 2026-08-09 | 3 | Software / Deployment | Stood up SearXNG (search.example.internal) and Open WebUI (ai.example.internal) on VLAN 25; home-docs partial export |
| 2026-08-10 | 2 | Documentation | Homelab reference docs refreshed for Tailscale to Netbird and .lan to example.internal migrations |
| 2026-08-12 | 3 | Research | Hardlink snapshot pattern (rsync --link-dest), inodes vs symlinks; FIDO/YubiKey resident SSH keys; GPG escrow and Shamir split |
| 2026-08-13 | 6 | Backup / Recovery | Moved to rsync hardlink snapshots; YubiKey + escrow design; KEY OK gate passed; two real snapshots; Netbird rebuild and routing-peer root cause (N100 elected as router) |
| 2026-08-14 | 7 | Backup / Recovery | Target selection redesign (src-IP), atomic snapshots, script frozen; repo package (README, DESIGN, TROUBLESHOOTING, ACCEPTANCE, journal); RESTORE-PLAYBOOK and rsync-recover.sh; first full restore drill completed over mesh; GitHub push |
| 2026-08-14 | 5 | Meetings | Cascade STEAM Friday standup and on-site work at Bellingham Makerspace (progress review, mentor check-in, community group coordination) |
| 2026-08-19 | 1 | Documentation | Corrected laptop OS/DE record; restore-drill VM spec updated |
| 2026-08-21 | 5 | Meetings | Cascade STEAM Friday standup and on-site work at Bellingham Makerspace (progress review, mentor check-in, community group coordination) |
| 2026-08-24 | 5 | Software / Documentation | BMS Zabbix monitoring proposal (Word doc): Agent 2 vs Agent, pull vs push, six services evaluated (Feenics door access, BookStack, Music Assistant, Pi display, log server), BookStack worked check, open questions |
| 2026-08-24 | 3 | Research | Zabbix fundamentals: Agent vs Agent 2, passive vs active checks, templates, LLD; Feenics/HID REST API and licensing; BookStack health checks |
| 2026-08-26 | 5 | Backup / Software | Pull-model redesign: backupsrc user with ACLs and rrsync forced command, SSH exit-code reachability, first-run config prompt; nine-file doc set and journal; Gitea mirror |
| 2026-08-26 | 3 | Networking | MikroTik QoS: Torch analysis, FastTrack bypass found and fixed with exclusion rules, xbox-limit queue, graphing enabled; CHANGELOG pushed |
| 2026-08-26 | 1 | Learning | SNMP study: versions, MIB/OID tree, MikroTik enterprise OID, SNMPv3 config |
| 2026-08-26 | 2 | Physical Install | Racked pve-lab-cs; ran and terminated ethernet cables (crimp, test); cabled to AP2 |
| 2026-08-27 | 7 | Cascade STEAM Infra | pve-lab-cs stood up (10.0.88.X); AP2 outage recovery (physical reset via pad short, port map rebuilt from bridge host tables, VLAN 25 row added); Zabbix 7.0 LTS installed in CT 100 (nesting, schema import, locale fixes) |
| 2026-08-27 | 3 | Networking | VLAN 50 (CascadeSTEAM) L2 troubleshooting: tcpdump on nic0, AP2 bridge VLAN table, Controller ARP split test; Netbird resource group and legacy route fixes |
| 2026-08-28 | 4 | Backup / Recovery | N100 outage before demo: sshd disabled, failing USB SATA drive, RAID verified healthy; pull-backup units installed and timer enabled (every 30 min 08-22) |
| 2026-08-28 | 4 | Software | rsync-snapshot.sh rewritten to pull model; rrsync read-only scoping on laptop; ntfy notify() with non-fatal failures; excludes file |
| 2026-08-28 | 5 | Meetings | Cascade STEAM Friday standup and on-site work at Bellingham Makerspace (progress review, mentor check-in, community group coordination) |
| 2026-08-29 | 5 | Software / Cascade STEAM | Zabbix lab fleet on pve-lab-cs: six dummy LXCs (CT 300-305: web, svc, db, dns, app, cache) with agent2; Lab Fleet host group, 491 items; chaos-monkey.sh v3 as systemd service |
| 2026-08-29 | 5 | Software / Deployment | Second Zabbix server CT 113 on pve-svc from scratch (Debian 12, Postgres 15, nginx, PHP-FPM); thin-pool fix; agent2 on pve-svc and N100; LVM thin-pool UserParameters; Proxmox API token |
| 2026-08-29 | 4 | Software / Monitoring | N100 Netbird pin fix via ExecStartPost drop-in; Proxmox VE by HTTP, Docker by agent 2, MikroTik SNMP templates (204 items); zabbix.example.internal via Caddy |
| 2026-08-29 | 1 | Documentation | README-zabbix.md compiled covering lab fleet and BMS proposal |
| 2026-08-30 | 2 | Infrastructure | pve-svc unplanned upgrade to PVE 9 recovered; Caddy xcaddy rebuild and apt hold |
| 2026-08-30 | 2 | Documentation | infrastructure-ip-table.md rewritten and pushed to Gitea; centralized logging scoping |
| 2026-08-30 | 6 | Backup / Networking | N100 unreachable over mesh diagnosed via jump host (stale client 0.74.7, upgraded); AP2 SNMP fixed; backup-poll timer redesign; SABnzbd uid fix; vzdump tiers in jobs.cfg; fstrim reclaimed ~117 GB; route-hijack playbook doc |
| 2026-08-31 | 4 | Software / Backup | Four backup faults fixed; probe-based target selector; bats test suite (8 passing); deploy script rewrite; zip bundle, journal, Gitea push and N100 redeploy |
| 2026-09-01 | 5 | Networking / Documentation | AP2 power-loss outage recovery: cable replacement, N100 static IP, LXC 105 mount fix, timer re-enabled; CHANGELOG-2026-09, hardware-inventory.md, seclab-planning update |
| 2026-09-01 | 2 | Physical Install | Replaced degraded flat Cat6 runs (N100 and switch uplink) with new round Cat6; made and tested cables; re-seated rack cabling |
| 2026-09-02 | 4 | Networking | AP2 hard-reboot root cause; 5 GHz channel plan from frequency scan; laptop wifi power-save jitter fix; NTP on both APs; duplicate rules cleaned; exports committed |
| 2026-09-03 | 5 | Security / Forensics | Misc share deletion investigation; read-only container mounts; misc-snapshot timer; inotify tripwire service; Samba full_audit; journald retention; CIFS credential rotation |
| 2026-09-03 | 5 | Software / Deployment | Central log sink CT 115 (rsyslog TCP 514, dedicated NVMe); seal and hash integrity timers with ntfy; all LXCs enrolled; pve-lab-cs hostname rename and node-config recovery |
| 2026-09-03 | 2 | Software | laptop-backup.sh unified rewrite (79 lines) with change gate, atomic promote, age-based prune, ntfy |
| 2026-09-03 | 1 | Documentation | Logsink journal to home-docs; IP table patch to homelab-docs |
| 2026-09-04 | 4 | Monitoring / Software | AP2 gigabit negotiation and switch error-counter analysis; Zabbix DHCP lease LLD via RouterOS REST API with TLS, read-only API user, JavaScript preprocessing |
| 2026-09-04 | 5 | Meetings | Cascade STEAM Friday standup and on-site work at Bellingham Makerspace (progress review, mentor check-in, community group coordination) |
| 2026-09-06 | 2 | Software / Backup | rsync exit 23 root cause; both backup scripts patched; excludes extended; journal |
| 2026-09-06 | 3 | Cascade STEAM / BMS | BMS network discovery: nmap snap sandbox issue fixed via apt; host discovery on <BMS-IP>/24 and <BMS-IP>/24 (30 hosts each); two Markdown inventory reports |
| 2026-09-07 | 6 | Networking / Documentation | AP2 port layout redesign; N100 Linux bridge netplan with self-rollback; LXC 105 CIFS fix; DHCP reservations; topology doc with Mermaid, runbooks, inventory, changelog pushed |
| 2026-09-07 | 1.5 | Help Desk / Documentation | Netbird macOS install guide written for a non-technical user; scoped family VPN access via MikroTik address-list |
| 2026-09-07 | 2 | Physical Install | Relocated Win11 box and GS305 switch; recabled AP2 ports for the new layout; moved Samsung TV port |
| 2026-09-08 | 5 | Software / Deployment | Authentik SSO (LXC 114) with Gitea OIDC; Pixoo 64 HA dashboard (six pages, custom icons in Gitea, firewall rule); homepage dashboard CT 112 |
| 2026-09-08 | 4 | Cascade STEAM / BMS | BMS PVE1: Zabbix 7.4 Docker stack in CT 105 (<BMS-IP>); two published guides (deployment walkthrough, SNMP security hardening with templates) |
| 2026-09-08 | 3 | Networking | pve-lab unreachable after AP2 reboots; Win11 static IP conflict; Controller restore after config paste; ether5 hardening and negotiation |
| 2026-09-09 | 3 | Software | HA DNS outage fix (Netbird nameserver); Seahawks Pixoo REST/template sensors and three automations; changelog |
| Various | 4 | On-site | On-site time at Cascade STEAM (3 to 4 hours total across the placement) |

**Total: 219 hours**  
Meetings: 40 hours
