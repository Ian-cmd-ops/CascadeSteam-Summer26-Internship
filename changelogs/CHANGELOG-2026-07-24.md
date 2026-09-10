# Homelab Changelog — 2026-07-24

First changelog since 2026-05-17. Two months of undocumented drift closed out.

Session theme: remote access migrated from Tailscale to Netbird, and a
lockout that proved the migration had never been verified from off-network.

---

## Overlay VPN consolidated on Netbird

Two overlays were running with overlapping advertised subnets — Tailscale
(LXC 110, routes never approved) and Netbird (added ~2026-07-21 for the
laptop backup project). Debugging routing with both live is not viable.

**Decision: Netbird only.** Tailscale LXC 110 destroyed 2026-07-23.

Rationale unchanged from the original Tailscale choice — WAN is a Comcast
modem in router mode with a changing public IP, so inbound WireGuard on the
MikroTik is unreliable. Both overlays solve this; running one of them is
the point.

Full detail in `netbird-remote-access.md`.

---

## LXC 110 rebuilt as Netbird routing peer

Same container ID, same IP (10.0.25.X), new role.

| Property | Old | New |
|----------|-----|-----|
| Software | Tailscale 1.96.4 | Netbird 0.75.0 |
| Template | Debian 12 | Debian 13 (13.6-1) |
| Enrollment | Interactive | Setup key |
| Routes | 4 subnets, never approved | None configured yet |

Build issues worth recording:

- **`--nameserver` omitted at create.** Container inherited no DNS. `apt
  update` returned `Ign:` on every line then `Temporary failure resolving`.
  The old Tailscale 110 had the same problem and the same fix — this is a
  recurring PVE behavior, not a one-off.
- **Template version guessed.** `debian-13-standard_13.0-1` does not exist;
  current is `13.6-1`. Failure mode is ugly: rootfs gets created, then
  removed, then the create fails. `pveam available --section system` is
  authoritative.
- **TUN passthrough syntax changed.** Old doc says `pct set 110 --dev0
  /dev/net/tun`. Used the conf-append form instead:
  ```
  lxc.cgroup2.devices.allow: c 10:200 rwm
  lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
  ```
- **FQDN collision.** Enrolled while the retired CT 200 peer still held the
  name `netbird-gw`, producing `netbird-gw-19-199.netbird.cloud`. Stale peer
  not yet deleted.

---

## Lockout incident — remote access that had never been tested remotely

Attempted to reach the homelab from an off-site network. Findings:

**Two of four peers were missing from the mesh.** pve-svc (was <MESH-IP>)
and the N100 both absent. `netbird status -d` from the laptop showed only
Home Assistant and LXC 110.

Consequence: the restic repo lives on the N100 and is reached over the mesh.
**Off-network backup was non-functional and nothing reported it.**

Suspected cause is Netbird peer login expiration — default 24h, applies only
to SSO-enrolled peers, setup-key peers exempt. Both were SSO-enrolled.
**Unconfirmed** — dashboard peer status was not checked before access was lost.

**LXC 110 was reachable but unusable.** Mesh-connected, P2P, 213ms — and SSH
refused. Debian defaults to `PermitRootLogin prohibit-password` and no key
was installed at build time. The routing peer was the only remaining entry
point and it had no login path.

Resolved on-LAN by pushing a key through Proxmox. `ssh-copy-id` cannot
bootstrap this — with `prohibit-password` there is no password path to
authenticate the copy:

```bash
KEY=$(cat ~/.ssh/id_gitea.pub)
ssh root@10.0.88.X "pct exec 110 -- bash -c 'mkdir -p /root/.ssh && \
  chmod 700 /root/.ssh && echo \"$KEY\" >> /root/.ssh/authorized_keys && \
  chmod 600 /root/.ssh/authorized_keys'"
```

**Off-network verification still owed.** LAN success does not prove remote
access works — that is the entire lesson of this incident.

---

## pve-lab excluded from the mesh (deliberate)

CT 200 had been running as a Netbird routing peer **on pve-lab**, the host
running the WRCCDC training environment: VM 901 (kali-attacker) and target
images on isolated `vmbr1`.

`seclab-planning.md` requires no path from that lab to the production
network. A mesh interface on the host sits above the bridge-level isolation
that requirement depends on.

**Risk/Impact:** a container escape from the routing peer, or a guest escape
from an intentionally vulnerable target VM, reaches a host dual-homed into
the production overlay. Compromise of a disposable training target becomes
lateral movement into Vaultwarden, Gitea, and the backup repository.

Routing role moved to LXC 110 on pve-svc. **pve-lab is not a peer and should
not become one.** If remote access to its web UI is needed, route
`10.0.88.X/32` through LXC 110 with a policy scoped to TCP/8006 only.

CT 200 still present on pve-lab — not yet destroyed.

---

## Gitea SSH — was never exposed

`gitea.lan` resolves to **10.0.25.X (Caddy)**, not Gitea. Caddy
reverse-proxies HTTP only, so `ssh git@gitea.lan` was hitting Caddy's own
sshd. Gitea is LXC 102 at **10.0.25.X**.

Gitea runs in Docker and the compose file published **only port 3000**. No
SSH mapping existed at all — git-over-SSH had never worked, and no key would
have made it work.

Fixed by publishing `2222:22` in the compose file. Verified:

```
Hi there, ian! You've successfully authenticated with the key named lan-wubtop,
but Gitea does not provide shell access.
```

Laptop SSH config:

```
Host gitea gitea.lan
  HostName 10.0.25.X
  User git
  Port 2222
  IdentityFile ~/.ssh/id_gitea
  IdentitiesOnly yes
```

`IdentitiesOnly yes` matters — without it ssh offers every agent key and can
exhaust `MaxAuthTries` before reaching the right one.

Note: push-to-create is disabled for users. Repos must exist before first
push, via the web UI or the API.

---

## restic backup — no schedule existed

`crontab -l`: none. `systemctl list-timers --all`: only `dpkg-db-backup`.

**Every snapshot in the repo was manual.** Last one 2026-07-21. The daily
schedule described in the backup design had never been created.

Timer added 2026-07-23:

```ini
# /etc/systemd/system/restic-backup.timer
[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true
```

`Persistent=true` is required on a laptop — without it a run scheduled while
asleep is skipped silently rather than deferred to next boot.

Service runs `backup /home /etc` then `forget --keep-daily 7 --keep-weekly 4
--keep-monthly 6 --prune`.

### Off-network verification — PASSED 2026-07-24

Ran the full service from a foreign network. Not a snapshot listing — a
listing only proves the tunnel is up.

| Measure | Result |
|---------|--------|
| N100 connection type | **P2P** (not relayed) |
| Peers | 2/2 connected |
| Exit status | 0 |
| Snapshot | 26.947 GiB, `/home /etc /root` |
| Wall clock | 1m 37s |
| CPU | 1m 58s |
| Peak memory | 8.7 GB of 24 GB |

The timer also fired unattended at 00:05:43 the same night (randomized delay
off midnight), before any manual start. Daily cadence confirmed working.

### Host alias fault — the reason it had never worked remotely

```
subprocess ssh: ssh: connect to host 10.0.20.X port 22: Connection timed out
```

The `n100` SSH host alias resolved to the **LAN IP**, so restic's SFTP backend
dialed 10.0.20.X regardless of mesh state. Every prior test passed because
they were all run on the LAN. Off-network backup had never been possible, and
nothing about the on-LAN results would have revealed it.

Repointed to the Netbird IP (<MESH-IP>), which resolves correctly from
both inside and outside the house.

Note: `ssh_config` takes the **first** matching value for a keyword, so
appending a second `Host n100` block does not override an existing one — the
value has to be edited in place.

### Netbird control plane unreachable from VLAN 10

Laptop on 10.0.10.X showed `Management: Disconnected` and
`Signal: Disconnected`, timing out to port 443, 1/4 relays.

Ruled out: DNS sinkhole (all 35 static 127.0.0.1 entries are Samsung/Amazon/
Google ad domains, nothing Netbird-adjacent).

Not root-caused. Other segments connect fine — N100 on VLAN 20 and LXC 110 on
VLAN 25 both reach the control plane without issue, so it is VLAN-10-specific.

One lead worth chasing: `getent hosts api.netbird.io` returns an **IPv6-only**
answer. glibc prefers IPv6 when present, so a segment that advertises IPv6
without routing it produces exactly this hang. Test with `curl -4` vs
`curl -6` before hunting firewall rules.

### Still not solved: silent success and silent failure

Tonight's run was only known to have succeeded because it was watched. ntfy is
deployed at 10.0.25.X and unused for this — an `OnFailure=` hook is the
obvious fix and is not built.

### Memory note

Peak 8.7 GB, driven by `--prune` in `ExecStartPost` — prune loads the full
repository index, and that scales with repository size rather than with how
much changed. Comfortable on 24 GB today. If it climbs toward 15–16 GB as the
repo fills, split `prune` onto a separate weekly timer and leave `forget` on
every run.

### Recovery credential gap (still open)

Backup scope is `/home` and `/etc`. The credentials that reach the repo live
in `/root`:

- `/root/.restic/repo`
- `/root/.restic/pass`
- `/root/.ssh/id_restic`

None are in the backup. That is correct — storing them inside would be
circular — but **if the laptop dies, restore is impossible.** Flagged in July
and still open. Escrow to Vaultwarden (10.0.25.X).

---

## LVM thin pool — approaching a cliff

Surfaced as warnings on every `pct` operation:

```
Sum of all thin volume sizes (197.01 GiB) exceeds the size of thin pool
pve/data and the amount of free space in volume group (16.00 GiB).
```

| Metric | Value |
|--------|-------|
| `pve/data` size | 141.23 GiB |
| `pve/data` used | 79.11% |
| Provisioned across volumes | 197.01 GiB |
| VG free extents | 16.00 GiB |
| `vm-105-disk-0` (media LXC) | **99.91%** |

Autoextend enabled (threshold 80, percent 20), but 20% of 141 GiB is ~28 GiB
against 16 GiB of available extents. **This buys time, not safety.**

If the pool fills, every volume on `local-lvm` goes read-only simultaneously —
Vaultwarden, Gitea, Caddy, all of it. Not a gradual degradation.

Note: the `sed` used to enable autoextend matched commented variants and left
duplicate keys, producing `WARNING: Ignoring duplicate config value` on every
LVM call. Harmless but noisy; deduplicate `/etc/lvm/lvm.conf`.

**Action needed:** move LXC 105 media to the N100's 14TB RAID1 (which is what
it is for), or add disk. Not resolved this session.

---

## Documentation

- `netbird-remote-access.md` — new. Full Netbird reference: peers, enrollment,
  LXC 110 build, Networks model, pve-lab exclusion, recovery procedures.
- `homelab-reference.md` — LXC 110 section rewritten, remote access updated.
- `infrastructure-ip-table.md` — LXC 110 row updated.
- Two patch files from 2026-05-17 (`homelab-reference-PATCH`,
  `lxc-111-PATCH`) remain unmerged. Own review flagged these as stale-by-design
  two months ago.

---

## Open Items After This Session

### Critical
1. ~~N100 back on the mesh~~ — DONE, <MESH-IP>
2. ~~Verify backup from off-network~~ — DONE 2026-07-24, P2P, exit 0
3. **pve-svc back on the mesh** (setup key) — still absent
4. **Backup failure alerting** via ntfy — silent success and silent failure
5. **Escrow restic credentials** — `/root` is now in backup scope, which does
   not solve it. The passphrase is needed *before* the repo can be opened.
   Vaultwarden covers device loss but sits in the same building as the backup
   target, so it does not cover site loss. Print the passphrase and repo path.
6. **Off-network SSH to LXC 110** — still unverified

### High
6. LVM thin pool headroom — `vm-105-disk-0` at 99.91%
7. Destroy CT 200 on pve-lab
8. Delete stale `netbird-gw` peer record in Netbird dashboard
9. Remove destroyed Tailscale node from Tailscale admin console
10. No Network resources configured — nothing agentless is reachable remotely

### Medium
11. Netbird DNS not configured — peers addressable by IP only
12. Client version drift — laptop 0.74.7, LXC 110 0.75.0
13. Merge or delete the two stale patch files
14. Deduplicate `/etc/lvm/lvm.conf` autoextend keys

---

## Carried Forward, Unresolved

From the 2026-05-17 review, still open:

- SSH password auth in use across the estate
- Root SSH login enabled
- No fail2ban anywhere
- MikroTik forward chain has **no default drop rule** — VLAN 25 → VLAN 88 and
  VLAN 25 → VLAN 20 pass by absence of a rule, not by policy. Adding a proper
  default drop will break routing through LXC 110 unless accept rules are
  added first.
