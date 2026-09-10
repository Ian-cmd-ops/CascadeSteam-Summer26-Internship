# rsync-snapshot

Living-off-the-land laptop backup. Hardlink snapshots over SSH to a NAS. No third-party binaries. Only rsync, ssh, and systemd.

Built as an internship deliverable for Cascade STEAM. The acceptance criteria: recover the laptop from a full wipe, keep at least two restorable snapshots, prove restore by standing the backup up as a VM, and work from anywhere.

## How it works

1. The script picks a target by location, not by reachability. It reads the source IP the kernel selects for the NAS's LAN address. A home address means true LAN. Anything else means the VPN mesh.
2. One SSH probe checks the chosen target. If the target is down, the script aborts and logs it. The systemd timer retries later.
3. rsync copies the source into a hidden work folder named `.incomplete-<timestamp>`. Unchanged files become hard links to the last snapshot. They take almost no new disk space.
4. On success, the script renames the work folder to its final timestamp name. Rename is atomic. A folder with a final name is a complete snapshot. There is no in-between state.
5. The `latest` symlink moves to the new snapshot. Snapshots past the newest 14 are pruned.
6. At the start of every run, the script deletes any leftover `.incomplete-*` folders. These are wrecks from runs that died hard (power loss, kill -9). This is safe because a lock file guarantees only one run is alive.

The design in one sentence: build in the dark, rename into the light. A snapshot name is a promise.

## The rule behind the path selection

Requirement: on my network, use ssh and not the VPN. Off my network, use the VPN.

The signal is the kernel's chosen source address for the NAS LAN IP:

| Situation | Source address | Target |
|---|---|---|
| Home LAN (Wi-Fi or wired) | 192.168.x.x | `n100-lan` |
| VPN tunnel holds the route | 100.72.x.x (mesh IP) | `n100-mesh` |
| Foreign network | that network's range | `n100-mesh` |

This matches the trusted-network-detection pattern used by commercial VPN clients: a cheap local signal, then an authenticated check. The SSH host key is the authenticated check. A foreign network that also uses 192.168.x cannot receive a backup. Its fake NAS fails host key and key auth, and the run aborts. Worst case is a skipped backup, never a wrong one.

SSID detection was considered and rejected. It has an ethernet blind spot and it couples the script to a network name.

## Files

| File | Purpose |
|---|---|
| `rsync-snapshot.sh` | The backup script |
| `rsync-excludes` | Exclude list (deploys to `/root/.rsync-excludes`) |
| `rsync-snapshot.service` | systemd service unit |
| `rsync-snapshot.timer` | Daily timer, `Persistent=true` |
| `rsync-recover.sh` | Pull-restore script (dry-run by default, supports FIDO token keys) |
| `RESTORE-PLAYBOOK.md` | Full wipe-to-working restore procedure |


## Deploy

1. Copy `rsync-snapshot.sh` and `rsync-recover.sh` to `/ian/rsync-script/`. Set mode 700.
2. Copy `rsync-excludes` to `/root/.rsync-excludes`.
3. Add SSH aliases to `/root/.ssh/config`. `n100-lan` points at the NAS LAN IP. `n100-mesh` points at its mesh IP. Both use `IdentityFile /root/.ssh/id_restic` and `IdentitiesOnly yes`.
4. Install the systemd units and enable the timer:

```
sudo cp rsync-snapshot.service rsync-snapshot.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now rsync-snapshot.timer
```

The service must carry `SuccessExitStatus=0 24`. rsync exit 24 means a file vanished during the copy. That is normal for a live home directory and must not count as failure.

## Run

Manual run with live progress:

```
sudo /ian/rsync-script/rsync-snapshot.sh
```

Check results:

```
tail -5 /var/log/rsync-snapshot.log
```

The completion line names the path used: `complete via n100-lan` or `complete via n100-mesh`. That is the visible LAN-versus-away signal.

## Retention

The newest 14 snapshots are kept. This is a count, not a day range. Manual runs consume slots. At the daily schedule, 14 snapshots is about two weeks of history. Disk cost per snapshot is only the changed data. Measured on this laptop: a 16G full, then 70 to 200M per incremental.

## Restore

See `RESTORE-PLAYBOOK.md`. Short version: install a matching OS in a fresh VM, pull `latest` from the NAS with `rsync-recover.sh`, restore `/home`. The acceptance drill rebuilds the laptop as a VM on the Proxmox lab host.

## Known limits

- Scope is `/home` only. `/etc` and an installed-apps manifest are planned. **unverified** until added, a wipe recovery rebuilds apps by hand.
- The off-network path is deployed but a completed off-network run is still pending verification.
- Recovery depends on NAS credentials that must live outside the backup. A two-token hardware key plan with encrypted escrow covers this. Enrollment is in progress.

## Repository layout

```
rsync-snapshot.sh              the backup script (deploys to /ian/rsync-script/)
rsync-recover.sh               pull-restore script (copy from the laptop, not in repo yet)
rsync-excludes                 exclude list (deploys to /root/.rsync-excludes)
systemd/rsync-snapshot.service oneshot service, SuccessExitStatus=0 24
systemd/rsync-snapshot.timer   daily 02:00, Persistent=true
docs/DESIGN.md                 requirements, decisions, rejected alternatives
docs/TROUBLESHOOTING.md        real incidents: symptom, test, fix
docs/ACCEPTANCE.md             internship criteria status map
journal/                       append-only work journal, one file per session
RESTORE-PLAYBOOK.md            wipe-to-working procedure (copy from the laptop)
```

Journal convention: entries are append-only. Corrections go in a later entry, never by editing history. Unverified claims are labeled **unverified** inline.
