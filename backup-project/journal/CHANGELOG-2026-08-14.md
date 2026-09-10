# Changelog 2026-08-14

Session scope: replace reachability-based target selection with location-based selection. Harden partial cleanup. Diagnose a home-LAN outage. Prepare the repo for Gitea and GitHub.

## Problem carried in

At home with the VPN up, SMB to the NAS (10.0.20.X) failed. Turning the VPN off fixed it. Root cause: the laptop installs the vlan20 mesh route, so LAN traffic to the NAS rides the tunnel. This also broke the backup script's target probe. The probe tested reachability, and 10.0.20.X is reachable through the tunnel, so `target: n100-lan` runs were actually riding the mesh. Governing requirement (stated July): on my network use ssh, not the VPN. Off my network, use the VPN.

## Changes to the script

1. Target selection rewritten. First attempt used the egress device (`dev != wt0` means LAN). A real run falsified it at 10:30: away-with-VPN-down and home-without-route both show a physical device, so the label lied. Replaced with the kernel-chosen source address: `ip route get 10.0.20.X`, read the `src` field. `192.168.*` selects `n100-lan`. Anything else selects `n100-mesh`. Verified in a live run: `src: 10.0.10.X -> target: n100-lan`.
2. Fallback loop removed. One selection, one probe, loud abort. The Persistent timer retries. A fallback would mask a sick target, which is exactly how the tunnel hijack stayed hidden.
3. Atomic snapshots. rsync now writes into `.incomplete-<stamp>`. On success the folder is renamed to its final name. Rename is atomic, so a final-named folder is complete by definition. The `latest` symlink and the prune only ever touch final names.
4. Start-of-run sweep. Any leftover `.incomplete-*` is deleted before the new run. Safe under the flock. This catches power-loss and kill -9 orphans the EXIT trap cannot see. The two junk snapshots removed by hand on 08-13 were this failure class.
5. Foreign-192.168.x edge accepted: a stranger's network could mislabel as home, but the SSH host key and key auth abort the run. Worst case is a skipped backup, never a wrong one.

Detection research: the industry pattern is Trusted Network Detection. Commercial clients combine a cheap network signal with an authenticated server check. This script follows the same shape with stock tools. SSID matching was proposed (prior art: the May home-mount.sh) and rejected for the backup: ethernet blind spot, tool dependency, name coupling. Gateway-MAC checking noted as optional future hardening. Not built.

## Outage investigated (10:30 to 10:44)

Total blackout laptop to NAS on the true LAN: ping, 22, 445, 8096 all dead. Laptop VPN fully down, laptop route clean via 10.0.10.X. Caddy-proxied services (VLAN 25) never blinked. The outage self-healed. ssh then worked and tcpdump on the NAS showed the live session.

- UFW port-22 theory: falsified. LAN ssh worked with no firewall change.
- Leading theory (**unverified**): the NAS's netbird agent intermittently installs VLAN routes, so its replies to 192.168.10.x dive into wt0. The NAS's ip rule pins cover only 10.0.20.X/24 and 10.0.25.X/24, which is why Caddy survived and the laptop did not. The netbird table was empty when checked, but that check happened during a good window.
- Fix prescribed: pin 192.168.10/30/40/88 .0/24 to the main table (pref 100) on the NAS and extend the networkd-dispatcher hook to all six subnets. Verification for the next outage: `ip route show table netbird` on the NAS. Populated during an outage confirms the theory.

## Dashboard work decided, not yet built

Peer Network Range posture check, Block action, listing all six home subnets, attached to the laptop route policy. When the laptop is home, the VLAN routes drop and SMB uses the true LAN. Public-egress-IP matching rejected: the ISP address changes.

## State at end of session

Done: src-IP script deployed. Selection verified correct in a live run. Atomic snapshot and sweep design in place.
Pending: first `complete via n100-lan` run (blocked by the outage window during the session). Off-network `complete via n100-mesh` run. NAS ip rule pins. Posture check. `SuccessExitStatus=0 24` confirmation in the service unit. VM restore drill. Scope extension to `/etc` plus an apps manifest. Playbook export.
