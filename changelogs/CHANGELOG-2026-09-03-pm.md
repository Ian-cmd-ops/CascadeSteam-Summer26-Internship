# Homelab Changelog — 2026-09-03 pm (LXC senders, log viewer, alerting, arr retirement)

Second session of the day. The morning built the sink and enrolled three
hosts; this session enrolled every LXC, put a web viewer on the sink, added
push alerting for concerning log lines, and retired Homarr, Sonarr and Radarr
from the media stack. See `logsink-README.md` for the how-to.

## Log sink: every LXC now sends

- VLAN 25 to VLAN 88:514 proven open with a raw netcat line from gitea
  (CT 102); no MikroTik rule was needed. VLAN 20 was proven earlier via N100.
- Enrolled with the same `90-forward-sink.conf` on every guest:
  pve-svc 101, 102, 103, 104, 106, 107, 108, 109, 111, 112, 113;
  pve-lab 114; pve-lab-cs 100, 108, 300–306. Skipped: 115 (the sink itself),
  200 (stopped), 105 (see Open).
- Hostname collision: pve-lab-cs CT 108 is also named `ntfy`. Tagged it
  `ntfy-cs` with `global(localHostname="ntfy-cs")` so it files separately
  from pve-svc's ntfy.
- Cleared junk folders at the sink created during testing: `10.0.25.X`
  (homepage before its hostname was set), `HEAD` (a stray line from the
  earlier git push), `pve` (pre-rename pve-lab-cs), and the netcat test folder.
- Sink now holds 25 per-host folders.

## Log viewer: logs.example.internal

- ttyd + lnav on CT 115, `logviewer.service`, Caddy route
  `logs.example.internal -> 10.0.88.X:7681` on LXC 103.
- Two traps that cost an hour, recorded so they are not repeated:
  1. The lnav **static musl build** (0.14.0) fails inside the container with
     "unable to initialize notcurses" for every TERM value, even with
     `TERMINFO` / `TERMINFO_DIRS` set. Its bundled notcurses cannot find the
     terminfo database. The **Debian package** (`/usr/bin/lnav`, 0.12.4,
     ncurses-linked) works. Static binary left in `/usr/local/bin` but unused.
  2. ttyd defaults to **read-only** without `-W`. lnav rendered blank and
     ignored every key until `-W` was added.
- Also had to `rm -rf /root/.lnav` once: state left by the 0.14 binary made
  0.12.4 fail with a zookeeper.sql "unknown database lnav_db" error.
- Wrapper `/usr/local/bin/logview.sh` exports TERM and expands
  `/var/log/remote/*/` in a real shell (skips `lost+found`).
- **Basic auth added** (`ttyd -c ian:…`). Without it the session is a root
  shell on the evidence sink; lnav can run commands. Auth is the stopgap; a
  read-only service user is the fix.
- CT 115 can reach Debian mirrors (apt works) but has no general internet
  path; `ttyd` was pushed in as a static binary via `pct push`.

## Alerting: concerning lines to ntfy

- `/etc/logsink-alert/rules.conf` (prio|name|regex), scanner
  `/usr/local/bin/logsink-alert.sh`, `logsink-alert.timer` every 2 min.
  State (per-host byte offsets, cooldowns) in `/var/lib/logsink-alert/`.
- ntfy topic `logsink-alerts` on 10.0.25.X. First runs "failed" silently
  because **curl was not installed on CT 115** and because the topic was not
  subscribed in the app. Both fixed.
- Policy decided: **single Samba deletes stay quiet; 3 or more unlink/rename
  lines from one host in one 2-minute window page at urgent** ("MASS
  DELETE"). Other high rules push individually with a 10-minute cooldown:
  docker container remove, sudo from anywhere but the laptop IP, md RAID
  degraded, OOM, disk I/O errors, SSH brute-force signatures, segfaults.
  Generic error/warn words batch into one low-priority message per run.
  Silent-host check: no lines for 30 min -> one warning per hour.
- Log lines carry no syslog priority (receiver template is timestamp host
  program message), so severity is inferred from message text. Caddy's JSON
  `"level"` is matched directly.
- **Evidence note:** to test the mass-delete rule, six fake `smbd_audit
  ... unlinkat|ok|.../fake{1..6}.mp4` lines were appended by hand to
  `/var/log/remote/N100/2026-09-03.log` on the sink. They are not real
  deletions. This is exactly what the planned append-only/hash layers exist
  to make visible.

## Retired: Homarr, Sonarr, Radarr

- Sonarr and Radarr containers were already absent on LXC 105; Homarr was
  running. All three config dirs tarred to `/opt/media/retired-2026-09-03/`.
- Homarr stopped and removed. Service blocks for all three deleted from
  `/opt/media/docker-compose.yml` (backup
  `docker-compose.yml.bak-2026-09-03-retire`); `docker compose config`
  validates. Remaining stack: gluetun, qbittorrent, prowlarr, jellyfin,
  clamav, homer, nextcloud, sabnzbd, whisparr, stash (defined, not running,
  read-only mount), stash-vr.
- Caddy routes for sonarr/radarr/homarr removed on LXC 103 (backup
  `Caddyfile.bak-2026-09-03-retire`), validated, reloaded.
- Homepage tiles for Sonarr, Radarr, Homer removed from `services.yaml`
  earlier; Homer container still defined and running, pending decision.

## Open

- LXC 105: Docker `log-driver=journald` so container stdout reaches the sink.
- Viewer as a non-root read-only user; `chattr +a` on closed daily files;
  auditd watch on `/var/log/remote`; daily sha256 manifest.
- logrotate on the sink for 180-day retention; TLS for the rsyslog transport.
- Tune alerting after a day of real volume (`SILENT_MIN`, `generic-warn`).
- N100 logs a UFW multicast block every few seconds (SSDP/mDNS from
  10.0.20.X); allow it or suppress the log, it drowns that host's file.
- Homer: retire or keep. archivedocs: scope to Netbird-only. Homepage tile
  for logs.example.internal. Homepage widget API keys.
