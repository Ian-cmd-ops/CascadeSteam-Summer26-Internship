# Homelab Changelog — 2026-09-03 (Misc deletion, log retention, central sink, pve-lab-cs rename)

A movie file vanished from the Jellyfin adult library (`stripe-recovery/Misc`)
and the hunt for the cause ran into dead end after dead end, because every log
that could have named the culprit was volatile: dmesg reset on reboot,
`docker logs` died with `docker rm`, Samba had no audit trail. The cause was
never conclusively proven. That failure drove the rest of the session: make
deletion structurally impossible on that folder, then make sure the next
incident is never again un-investigable. Built a central log sink, hardened
retention on the N100, and fixed a hostname collision that surfaced along the
way. One near-miss during a PVE node rename, recovered from backup.

## Incident: Misc file deletion

- Multiple adult-content files deleted from `stripe-recovery/Misc` at exactly
  03:00:04 on 08-31 (several in the same instant, e.g. two OnlyFans Minipack
  parts). Files gone from disk; `.trickplay` folders and `.nfo` left behind,
  which is what confirmed a real file-level delete rather than a mount blip.
- **Ruled out** as the cause, each checked against its own logs: N100
  cron/systemd timers, Whisparr (does not even mount `/data/misc`), ClamAV,
  qBittorrent, SABnzbd, and Jellyfin's own library scan (only *reported* the
  files already missing).
- **Trickplay researched and cleared.** Every known Jellyfin trickplay bug
  leaves junk behind; none deletes source video. The 03:00 "Media not found"
  warnings are trickplay finding files already gone (matches jellyfin issue
  #15483) — a witness placing the deletion *before* 03:00:04, not the culprit.
- **Leading suspect, unproven:** the Stash or ThePornDB Jellyfin plugin. Ian
  removed one plugin (~00:46, unsure which). The Stash plugin was failing with
  "Connection refused (10.0.20.X:9999)" because the standalone Stash app
  container had been exited/dead for weeks; ThePornDB's AddCollection task was
  throwing exceptions. Neither produced an actual delete log line. **Cause
  remains unconfirmed.** [unverified]
- **Path correction:** the local path behind the Samba `[RAID]` share on the
  N100 is `/mnt/backups` — `/mnt/n100-raid` is only the CIFS client-side mount
  name as seen from LXC 105. The affected folder is
  `/mnt/backups/stripe-recovery/Misc`.

## Structural fix: read-only mount

- In `/opt/media/docker-compose.yml` both bind mounts of that folder set
  read-only: jellyfin `/data/misc:ro` (line 87) and the standalone `stash`
  service `/data:ro` (line 177). `docker inspect jellyfin` confirms
  `/data/misc false`.
- Nothing inside Jellyfin or its plugins (or Stash) can delete from that folder
  now, regardless of the unproven root cause. The kernel refuses the write.
- jellyfin `/data/movies`, `/data/tvshows`, `/data/tobesorted` remain RW.
- Compose backed up as `docker-compose.yml.bak-2026-09-03`.

## Backup for the Misc folder (was unprotected)

- Built `misc-snapshot.service` + `.timer` on the N100: daily 04:00, hardlink
  rsync via `--link-dest`, modeled on the existing `rsync-snapshot.sh` pattern.
  Backs up `/mnt/backups/stripe-recovery/Misc`, which had zero backup/snapshot
  coverage before this.
- Destination `/mnt/backups/shares/misc-snapshots` needed a manual
  `chown ian:ian` (parent `/mnt/backups/shares` is root-owned 755).
- Deployed a live inotify tripwire on that folder, converted to a systemd unit
  `misc-delete-watch.service` (Restart=always). The `inotifywait` command lives
  in `/home/ian/misc-snapshot/delete-watch.sh` because `%w`/`%f` in ExecStart
  collide with systemd specifiers. Output to journald, verified catching
  deletes.

## Log retention on the N100

- journald was already persistent (`/var/log/journal` since 2025); capped via
  `/etc/systemd/journald.conf.d/retention.conf` (SystemMaxUse=2G,
  MaxRetentionSec=90day).
- Samba `full_audit` enabled on the `[RAID]` share. **Op names on Samba 4.19.5
  are `unlinkat renameat`, NOT the old `unlink`/`rmdir`/`rename`** — the old
  names made every CIFS mount fail with error(5). Config: prefix `%u|%I|%m`,
  facility local5. full_audit calls `syslog()` directly; an rsyslog rule writes
  `/var/log/samba-audit.log` (moved out of root-owned `/var/log/samba/` so the
  syslog user can create it), 90-day logrotate. Verified: a delete over the
  share logs `ian|10.0.20.X|media|unlinkat|ok|<path>`.
- `smb.conf` backed up as `smb.conf.bak-2026-09-03`.

## CIFS password rotation

- Rotated the CIFS password via `smbpasswd ian` on the N100 (it had been in
  LXC 105's `/etc/fstab` in clear text). Moved it out of fstab into
  `/root/.smbcreds` (mode 600, `credentials=` in fstab) on LXC 105. Old
  password is dead. Both fstab lines (RAID and NAS-STORAGE) updated;
  `/etc/fstab` backed up.

## Central log sink

- Built "logsink" as CT 115 on pve-lab: Debian 13 unprivileged, on vmbr0
  (management), 10.0.88.X/24, DNS `logsink.lan` via Controller static.
- Runs rsyslog (imtcp on TCP 514) writing per-host dated files under
  `/var/log/remote/<hostname>/YYYY-MM-DD.log`.
- **Storage:** the 477GB nvme in pve-lab (`nvme0n1`) was wiped — it held an old
  Windows install, erase confirmed — and reformatted ext4 label `logsink`,
  mounted `/mnt/logsink` (by UUID in fstab), bind-mounted into CT 115 at
  `/var/log/remote` (host dir chowned 100000:100000 for the unprivileged map).
- **Design:** forward by raw IP, not DNS, so a DNS failure or poisoning can't
  silently divert the evidence stream. Write-only sink, plain TCP now / TLS
  later, 180-day retention target. Kept deliberately separate from the planned
  Loki analysis layer (evidence copy vs search).
- **Senders verified landing** (each with a test marker): N100 (journald +
  Samba audit), pve-svc, pve-lab-cs. All three VLAN 88 or VLAN 20; VLAN 20→88
  crossing confirmed working via the N100.

## pve-lab-cs hostname rename

- pve-lab-cs (10.0.88.X) still carried the Proxmox default hostname `pve`
  until now — it collided at the sink, filing entries under a generic `pve`
  folder. Renamed to `pve-lab-cs` (hostnamectl + `/etc/hosts`, FQDN
  `pve-lab-cs.cascadesteam.lab`). Reboot confirmed the rename persists; all 9
  guests came back running.
- **Near-miss / lesson:** during the PVE node-dir rename,
  `/etc/pve/nodes/pve` was `rm -rf`'d while its 9 guest configs were still in
  it (CT 100 zabbix, 108 ntfy, 300-306 the WRCCDC dummy targets). Recovered
  from a pre-made backup at `/root/pve-node-backup` by recreating
  `/etc/pve/nodes/pve-lab-cs/lxc` and copying the `.conf` files back; only the
  config files were removed, not container data, so `pct list` showed all 9
  still running throughout. **pmxcfs does NOT reliably auto-create the new node
  dir on a hostname change** — on a PVE node rename, back up
  `/etc/pve/nodes/<old>` first and restore into the new dir; never `rm` the old
  dir before the new one is populated.

## Open / queued (not done this session)

- LXC senders to the sink: most LXCs are VLAN 25, LXC 105 is VLAN 20. The
  VLAN 25→88:514 path is unproven — test one container before the rest.
- LXC 105 Docker log capture: set Docker `log-driver=journald` so container
  stdout survives `docker rm`, then forward. Needs container recreation.
- Sink hardening: append-only (`chattr +a`) on the per-host files; logrotate on
  the sink for the 180-day retention; consider TLS on the transport.
- **Planned — IDS/IPS on the old NUC:** bare-metal Debian + Suricata, ET Open
  ruleset, IDS-first via a MikroTik mirror/SPAN port (inline IPS later if the
  NUC has a 2nd NIC). Suricata EVE JSON to ship to the sink/Loki. NUC specs not
  yet confirmed. Ties into WRCCDC prep.
- **Planned — host FIM (Wazuh):** on N100 + LXC 105, the direct upgrade to the
  inotify tripwire; catches local file deletion a network IDS can't. Complements
  the NUC IDS, doesn't replace it.
