# Design

This document records the requirements, the decisions, and the alternatives that were rejected. The journal records when each decision happened.

## Requirements

1. Recover the laptop from a full wipe.
2. Keep a minimum of two restorable snapshots. View and revert changes between them.
3. Prove restore by standing the backup up as a VM on the Proxmox lab host.
4. Work from anywhere, home or away.
5. Living off the land. Use only tools that ship with the OS: rsync, ssh, systemd, coreutils.
6. Reuse existing lab infrastructure. The N100 NAS is the target.
7. Daily schedule.
8. Path rule, stated 2026-07: on my network, use ssh and not the VPN. Off my network, use the VPN.

## Tool selection

rsync was chosen over the alternatives for the living-off-the-land requirement.

| Tool | Verdict | Reason |
|---|---|---|
| dd | Rejected | Imaging a live filesystem gives inconsistent snapshots. Needs full-size scratch space. |
| tar + gz | Rejected | Stages monolithic temp archives. No native incrementals. |
| Proxmox Backup Server | Rejected | Fleet backup is not a goal. PBS server is Debian-only. The NAS runs Ubuntu. |
| restic | Replaced | Excellent tool and the previous implementation. Rejected here because it is a third-party binary, which violates requirement 5. |
| rsync --link-dest | Selected | Ships everywhere. Hardlink snapshots give point-in-time history at delta cost. |

## Architecture

Push, laptop to NAS, over SSH. Pull was designed and rejected: it requires an SSH server on the laptop and puts the schedule on the NAS, which is off when the laptop roams. Push keeps the schedule with the machine that knows its own location.

Snapshots use `rsync --link-dest`. Each snapshot is a full directory tree. Unchanged files are hard links to the previous snapshot. Measured cost on this laptop: 16G for the first full, 70 to 200M per daily incremental.

## Location detection

The industry name for this problem is Trusted Network Detection. Commercial VPN clients solve it with a cheap network signal plus an authenticated server check. This script uses the same shape with stock tools.

The signal is the source address the kernel selects for the NAS LAN IP: `ip route get 10.0.20.X`, read the `src` field.

| Situation | Source address | Target |
|---|---|---|
| Home LAN, Wi-Fi or wired | 192.168.x.x | n100-lan |
| VPN holds the route | 100.72.x.x | n100-mesh |
| Foreign network | its own range | n100-mesh |

The authenticated check is the SSH probe. Host key verification and key auth run before any data moves.

Alternatives evaluated:

| Method | Verdict | Reason |
|---|---|---|
| Reachability probe (v1) | Replaced | Tests the wrong question. The NAS LAN IP is reachable through the tunnel, so the probe cannot tell home from tunneled. Falsified in production. |
| Egress device, dev != wt0 (v2) | Replaced | Cannot distinguish home-without-route from away-with-VPN-down. Both show a physical device. Falsified by a real run on 2026-08-14. |
| Source IP (v3, current) | Selected | Correct in all four states. Zero new dependencies. |
| SSID match | Rejected | Ethernet blind spot. Tool dependency. Couples the script to a network name. Prior art exists in this lab (a desktop auto-mount uses SSID), which fits that job but not this one. |
| DNS suffix match | Rejected | Depends on DHCP handing the suffix to every VLAN. Documented false negatives on docked wired clients. |
| Internal DNS probe | Rejected | Split DNS is reachable over the tunnel by design here. The probe would answer "home" when away. |
| Gateway MAC check | Deferred | Strongest local-presence proof. Hardcodes a MAC. Noted as optional future hardening. Not built. |

Known edge: a foreign network that also uses 192.168.x mislabels as home. The SSH probe catches it. The impostor NAS fails host key and key auth. Worst case is one skipped backup, never a wrong one.

## Failure and interrupt design

Principles: abort loudly, never guess, never leave junk that looks like a snapshot.

1. No fallback between targets. One selection, one probe. If the chosen target is down, the run aborts and the Persistent timer retries later. A fallback would mask a sick path. That masking is exactly how the v1 probe hid the tunnel hijack.
2. Atomic snapshots. rsync writes into `.incomplete-<stamp>`. On success the folder is renamed to its final name. Rename is atomic on one filesystem. A final-named folder is complete by definition.
3. Two cleanup layers. An EXIT/INT/TERM trap deletes the current run's partial on any normal failure. A start-of-run sweep deletes any `.incomplete-*` left by a hard death (power loss, kill -9). The sweep is safe because the flock guarantees no other run is alive.
4. The prune glob `20*` can never match a work folder. Retention never counts junk. The `latest` symlink only ever points at a promoted snapshot.
5. rsync exit 24 (files vanished mid-copy) is success. The service unit carries `SuccessExitStatus=0 24`.

## Retention

Newest 14 snapshots. This is a count, not a day range. Manual runs consume slots. At the daily schedule this is about two weeks of history.

## Security model

1. Key auth only. The backup uses a file key because an unattended timer cannot touch a hardware token.
2. Recovery authenticates with a hardware security key (FIDO resident SSH key). Two tokens: one carried, one stored offline as backup and escrow.
3. Credentials needed for recovery must live outside the backup. An encrypted escrow bundle on separate offline media covers the repo target account and passphrases. This closes the chicken-and-egg where the key that reaches the backup lives inside the backup.
4. The script never falls back to passwords. BatchMode=yes everywhere.

## Out of scope, planned

1. Extend scope to /etc plus an installed-apps manifest (apt-mark showmanual, dpkg selections, flatpak list). The restore method depends on the manifest.
2. Off-site 3-2-1 leg on a separate machine.
3. Gateway MAC as a second location signal, if ever needed.
