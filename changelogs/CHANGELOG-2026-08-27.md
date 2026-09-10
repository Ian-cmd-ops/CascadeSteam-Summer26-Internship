# CHANGELOG-2026-08-27 — AP2 outage, recovery, and rack re-map

## Incident
- Whole-house outage during pve-lab-cs bring-up. Initial theory (bridge port removal on AP2) was wrong: ether1/ether2 were never bridge members in the restored config. Actual trigger **unverified** — RouterOS clock was months off (showed April), so AP2 log timestamps from tonight are unreliable.
- AP2 restored from backup file. The backup was STALE: it predated the ether5 trunk config and the VLAN 25 bridge-vlan row. Restoring it silently broke pve-svc reachability and all VLAN 25 services.

## Root causes found
- "VLAN 88" does not exist on AP2. The 192.168.88.x management subnet rides VLAN 1 (Management native). Any pvid=88 config is wrong on this device.
- pve-svc (ether5) and pve-lab (ether3) sit on AP2 ports that were access pvid=20 in the stale backup. Their untagged mgmt traffic landed on VLAN 20. Fix: trunk both ports.
- LXCs 101 (vaultwarden), 103 (caddy), 110 (netbird-gw) were down on pve-svc after the outage. netbird-gw being down made the laptop's Netbird DNS hijack example.internal resolution (nameserver route dead). Workaround: netbird down on the laptop while home.

## AP2 config changes (2026-08-27)
- ether1: added to bridge, pvid=1, comment "pve-lab-cs" (access, mgmt)
- ether3: pvid=1, tagged VLAN 20, comment "pve-lab trunk"
- ether4: pvid=1, tagged VLAN 20 — comment stale, port holds unknown device (see Open)
- ether5: pvid=1, tagged VLAN 20+25, comment "pve-svc trunk"
- Bridge VLAN table: added VLAN 25 row (tagged ether2, ether5). VLAN 20 row: untagged now empty; tagged bridge,ether2,ether5,ether4,ether3.

## AP2 port map (verified from bridge host table)
| Port | Role | Config |
|---|---|---|
| ether1 | pve-lab-cs | access, pvid=1 |
| ether2 | Trunk uplink to Controller | untagged 1, tagged 10/20/25/30/40 |
| ether3 | pve-lab | trunk, pvid=1, tagged 20 |
| ether4 | unknown device <MAC> | trunk, pvid=1, tagged 20 |
| ether5 | pve-svc | trunk, pvid=1, tagged 20+25 |

## New host
- pve-lab-cs: standalone Proxmox (internship/Cascade STEAM), Debian 13 base, on AP2 ether1. Currently DHCP at 10.0.88.X; target static .13 pending cAP-ac move to .3. Zabbix CT 100 created (debian-12-standard_12.12-1, 10.0.88.X/24, gw .1, onboot). Zabbix 7.0 install NOT started — stopped before repo/package step.

## Open items
- [ ] Identify device <MAC> on ether4; it was VLAN 20 access before, now on a pvid=1 trunk — may be broken
- [ ] cAP-ac lease → 10.0.88.X; pve-lab-cs static → .13
- [ ] Fresh AP2 export + backup pulled OFF-device (old backup proven stale)
- [ ] AP2 reset button physically broken — repair (tactile switch solder job) or note as RMA risk
- [ ] AP2 NTP — clock was months off
- [ ] netbird-gw (LXC 110) health after reboot; laptop netbird up re-test; posture-check for home-LAN route suppression still unbuilt
- [ ] pve-svc LXC onboot/startup-order review (101/103/110 did not survive outage cleanly)
- [ ] Zabbix install (repo step onward); mentor Netbird peer plan: agent in CT 100, internship peer group, mentor→internship TCP 80 only
# 2026-08-27 — VLAN 50 remote access (CascadeSteam) + AP2/FastTrack/CAPsMAN review

## CascadeSteam Lab VLAN 50 — NetBird remote access fixed end-to-end
- Root cause chain: wrong NetBird resource group (thenetyeti instead of
  laptop's group), route existed only in NetBird's newer "Networks"
  system while the client (0.74.7) only read the legacy "Network
  Routes" system, no VLAN 50 interface on pve at all, VLAN 50 not
  tagged on pve's physical nic0 (bridge-level tag existed, NIC-level
  didn't), and no MikroTik firewall rule allowing pve into VLAN 50
  (only Zabbix had rules).
- Fixes applied: NetBird resource group -> cascadesteam; legacy route
  created (10.0.50.X/24 via netbird-gw); client updated 0.74.7 ->
  0.77.1; pve given vlan50 sub-interface (10.0.50.X/24) persisted
  in /etc/network/interfaces; `bridge vlan add dev nic0 vid 50` run
  and persisted via bridge-vids; MikroTik firewall rules added
  (10.0.88.X <-> 10.0.50.X/24 accept, placed above the vlan50
  isolate/drop rule).
- Result: pve confirmed reaching 10.0.50.X and can serve as the
  only host with access into VLAN 50, per the "pve + VLAN 50 services
  only" access decision.
- OPEN: remote laptop can reach the VLAN 50 gateway (.1) over NetBird
  but not pve (.10) or anything else on VLAN 50 -- NetBird's tunnel
  source range (<MESH-IP>/16) has no firewall rule into VLAN 50.
  Confirmed via /tool torch (zero traffic reaches the vlan50
  interface). Decision pending: allow the whole <MESH-IP>/16 range,
  or scope to just the laptop's NetBird IP (<MESH-IP>/32).

## AP2 outage and hardware recovery (Zabbix/pve-lab-cs bringup)
- Outage caused by a pvid=88 bridge port command; AP2 has no VLAN 88 --
  192.168.88.x rides VLAN 1 (management native) on that device.
- Recovery: stale backup restore made it worse (predated ether5 trunk
  + VLAN 25 bridge-vlan row, broke pve-svc + LXC 101/103/110).
  Physically opened AP2, shorted the broken reset button pads with a
  jumper to reset, rebuilt bridge/VLAN table by hand reading the live
  bridge host table MAC by MAC.
- Final AP2 port layout: ether1 pve-lab-cs (pvid=1 access), ether2
  trunk uplink, ether3 pve-lab trunk (pvid=1, tagged 20), ether4 N100
  (pvid=20 access, reverted after a mismatch broke LXC 105 CIFS
  pre-start mounts), ether5 pve-svc trunk (pvid=1, tagged 20+25).
  VLAN 25 row added to AP2 bridge VLAN table.
- Zabbix 7.0 LTS installed in CT 100 on pve-lab-cs (Debian 12,
  10.0.88.X, nesting=1 for MariaDB). Web UI confirmed working.
  NetBird agent installed on pve-lab-cs itself for remote mentor
  access (scoped peer group planned, not yet built).
- STILL OPEN: N100 LXC 105 CIFS pre-start hook failure
  (/mnt/n100-raid/media/downloads/tobesorted missing on host, stale
  mount from N100 being off-network). AP2 reset button still
  physically broken. AP2 clock badly wrong (showed April instead of
  August) -- log timestamps on that device are unreliable until fixed.

## FastTrack was bypassing Simple Queues
- chain=forward fasttrack-connection rule had no address restriction,
  so it bypassed xbox-limit (and any future queue) for all but the
  first few packets of established/related traffic.
- Fix: 6 explicit accept rules excluding Xbox (10.0.10.X), N100
  (10.0.20.X), and the Netbird tunnel (10.0.25.X, UDP) from
  FastTrack, placed above the fasttrack rule. Confirmed xbox-limit
  (10M/2M) now actually caps traffic.
- STILL OPEN: wan-total parent queue (needs real WAN speed), 
  n100-priority queue, Netbird mangle marking -- designed, not built.

## CAPsMAN — remote APs not registering
- AP2 and cAP-ac not appearing under
  `/interface wifi capsman remote-cap print` despite being enabled.
  AP2 reachable at 10.0.88.X with cap-wifi1/cap-wifi2 present but
  unbound; cAP-ac not appearing on the network at all.
- Leading theory: AP2 lacks a dedicated mgmt VLAN interface and
  CAPsMAN listens only on `bridge`, so no L2 adjacency for discovery.
- STILL OPEN: run `/interface wifi cap print` on AP2 to check enabled
  state, discovery-interfaces, and cert mode. Not yet done.
