# Changelog -- 2026-08-30

## pve-svc: unintended Proxmox 8 -> 9 jump
A plain apt update && apt full-upgrade -y on pve-svc pulled it onto
Debian Trixie / PVE 9.1.1. Root cause: no pve-no-subscription.sources
existed -- only a disabled pve-enterprise.sources -- so apt had no
Proxmox-specific repo constraining the upgrade and fell through to plain
Debian trixie.

Fixes applied:
- Added /etc/apt/sources.list.d/pve-no-subscription.sources
- Installed proxmox-headers-6.17.2-1-pve (package name is
  proxmox-headers-*, not linux-headers-*) so DKMS could find kernel
  headers
- dkms autoinstall rebuilt zfs/2.3.9 against the running kernel --
  confirmed installed, not just added
- Flagged but not yet done: grub-efi-amd64 install (EFI boot warning),
  VM 100 (haos) needs a stop/start to pick up the upgraded qemu binary

## Caddy (LXC 103): lost custom Cloudflare DNS module
Same apt upgrade replaced the xcaddy-built Caddy binary (with the
caddy-dns/cloudflare module needed for the *.example.internal wildcard's
DNS-01 challenge) with the stock cloudsmith package binary, which doesn't
have that module. Caddy failed to start:
module not registered: dns.providers.cloudflare

Fix: rebuilt with xcaddy build --with github.com/caddy-dns/cloudflare.
Had to first update Go on LXC 103 from 1.19.8 (too old -- Caddy 2.11.4
requires 1.25.1+) to 1.23.4, which then self-upgraded via go get to
1.25.1 during the build. Swapped the binary into /usr/bin/caddy,
restarted, confirmed clean start and TLS automation. Set
apt-mark hold caddy on LXC 103 to prevent apt from overwriting the
custom binary again.

## ntfy: installed on LXC 108 (Docker, not apt)
Discovered ntfy was already running via Docker on LXC 108 (3 months old,
port 80) -- an apt-installed ntfy also got set up in parallel and conflicted
on port 80. Removed the apt version; using the existing Docker container.
Confirmed reachable internally (10.0.25.X:80) and via Caddy
(ntfy.example.internal).

Topics in use:
- laptop-backup -- dedicated to the rsync backup script (start/success/fail)
- homelab-info / homelab-warn / homelab-critical -- severity-tiered,
  for the new service watchdog

## Backup script: added start notification
/home/ian/rsync-snapshot/rsync-snapshot.sh on the N100 already had
notify() wired for failure cases (unreachable target, rsync failure,
promote/prune failure). Added a notify "low" call right after target
selection so a "backup starting" push fires too, not just success/failure.

## New: homelab service watchdog
/opt/homelab-watchdog/check-services.sh on pve-svc, run via a 5-minute
systemd timer (homelab-watchdog.timer). Checks state-change only (not
every run) for:
1. ntfy (LXC 108, Docker container running)
2. Caddy (LXC 103, systemd service active)
3. netbird-gw (LXC 110, mesh peer count matches, management connected)
4. Vaultwarden (HTTPS reachability)
5. Gitea (HTTPS reachability)
6. Jellyfin (N100, port 8096 reachability)

Alerts to homelab-critical on down, homelab-info on recovery. Script
committed to home-docs at scripts/homelab-watchdog.sh.

## MikroTik: Bambuddy -> ntfy firewall exception
Bambuddy's built-in ntfy notification integration failed silently
(connection hung, not refused) -- traced to firewall rule 45
("Lab -> Infra DENY"), which blocks all VLAN 20 -> VLAN 25 traffic by
design. Added a narrow exception above rule 45 (10.0.20.X Bambuddy
-> 10.0.25.X ntfy, TCP port 80). Confirmed working -- curl from
LXC 106 to 10.0.25.X connects instead of hanging.

## Netbird: phone/mobile access + laptop routing fix
Added a new peer group phone/mobile for Ian's iPhone, scoped to a new
dedicated resource caddy-host (10.0.25.X/32, routed via netbird-gw),
policy TCP 443 only. Covers Vaultwarden, Gitea, Home Assistant, Bambuddy,
and ntfy in one policy since all are Caddy-fronted subdomains.

Also fixed the same asymmetric-routing bug on the laptop that the N100 had:
with Netbird up while also on the home LAN, traffic to 10.0.25.X (Caddy)
was routing via wt0 (tunnel) instead of the direct WiFi interface,
breaking/slowing ntfy and Bambuddy access. Fixed with the identical
ip rule add to <subnet> lookup main pref 100 pattern across all 7 home
VLANs, persisted via /etc/networkd-dispatcher/routable.d/50-netbird-fix.

netbird-gw itself was also updated from 0.75.0 to 0.77.1 to match the rest
of the fleet (pve-svc, LXC 106, LXC 108 were already on 0.77.1).

## Repo consolidation: homelab-docs merged into home-docs
homelab-docs and home-docs had diverged into two separate repos with
unrelated histories. Merged homelab-docs into home-docs with
git merge --allow-unrelated-histories, keeping both commit histories.
Single conflict on .gitignore (both repos had one), manually merged to
keep all entries from both. home-docs is now the single canonical repo;
homelab-docs can be retired/archived on Gitea.
