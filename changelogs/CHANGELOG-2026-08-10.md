# Homelab Changelog — 2026-08-10 (doc refresh + MAC sweep)

The three reference docs had drifted three months behind the infrastructure.
Two migrations that happened in late July, Tailscale to Netbird (07-23) and
`.lan` to `*.example.internal` (07-30), were never written back into the docs, so
the IP table, the reference, and the client playbook all still described a
network that no longer exists. This session reconciled all three against
current state and pulled the LXC/VM MAC addresses that had been a standing
gap. No infrastructure changed today except the reads; the config-side fixes
below are queued, not applied.

## Docs updated

### infrastructure-ip-table.md (was 2026-05-17)
- LXC 110 row: Tailscale subnet router to `netbird-gw`.
- All service hostnames `.lan` to `*.example.internal`.
- Cert section rewritten around the Let's Encrypt wildcard; the per-client
  Caddy-CA trust matrix removed.
- Added VLAN 25 `.14` kanboard, `.15` searxng, `.16` open-webui; VLAN 20
  `.253` grafana (LXC 111).
- `.20.221` promoted from "unverified TODO" to identified (pve-svc VLAN 20 leg).
- MAC column filled (see below).

### homelab-reference.md (was 2026-05-15)
- Migration banner added at top.
- LXC 103 Caddy section: local CA replaced with the LE wildcard, single
  `*.example.internal` block description, custom xcaddy build (Cloudflare DNS-01),
  4G to 8G resize.
- LXC 110 section fully rewritten to netbird-gw (networks, policies,
  off-network DNS path, jump-host role).
- DNS Records section replaced with the regexp-resolution model.
- TLS Trust matrix retired. Security Status and Pending Action Items
  repointed off Tailscale/Caddy-CA. Recent Changes extended 05-17 to 08-10.
- Fedora labels corrected to Lubuntu where they referred to the workstation;
  the cosmic-files recovery note marked legacy.

### client-setup-playbook.md (was 2026-05-17)
- The three "Install Caddy Root CA" sections (Fedora, Windows, iPhone) struck
  through as no longer needed under the public LE cert.
- Tailscale remote-access section rewritten to Netbird.
- Cert-warning and Samsung-TV troubleshooting rewritten around the public cert.
- Banner flags that the Fedora-specific setup commands (`dnf`, `/etc/pki`)
  still need Ubuntu equivalents on Lubuntu. Those command bodies were left
  as-is rather than guessed at.

## MAC sweep

Pulled via `pct config` / `qm config` on pve-svc. All Proxmox-assigned
(BC:24:11:xx). CT 111 answered on pve-svc, confirming grafana is not on
pve-lab.

```
for id in 101 102 103 104 106 107 108 110 111; do
  printf "CT %-3s " "$id"; pct config $id | grep -ioE '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1
done
printf "VM 100 "; qm config 100 | grep -ioE '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1
```

| CT/VM | Service | IP | MAC |
|-------|---------|-----|-----|
| 101 | vaultwarden | 10.0.25.X | <MAC> |
| 102 | gitea | 10.0.25.X | <MAC> |
| 103 | caddy | 10.0.25.X | <MAC> |
| 104 | rustdesk | 10.0.25.X | <MAC> |
| 106 | bambu | 10.0.20.X | <MAC> |
| 107 | obico-ml | 10.0.20.X | <MAC> |
| 108 | ntfy | 10.0.25.X | <MAC> |
| 110 | netbird-gw | 10.0.25.X | <MAC> |
| 111 | grafana | 10.0.20.X | <MAC> |
| VM 100 | homeassistant | 10.0.20.X | <MAC> |

IP table MAC column now complete for infrastructure hosts.

## Fixes queued (commands drafted, NOT yet applied)

### rustdesk static reservation (10.0.25.X)
Now that CT 104's MAC is known (<MAC>), convert the existing
dynamic lease in place on the MikroTik:
```routeros
/ip dhcp-server lease make-static [find where address=10.0.25.X]
/ip dhcp-server lease set [find where address=10.0.25.X] comment="rustdesk LXC104"
```
Verify the `D` flag is gone afterward.

### N100 route leak (root-cause fix for the recurring jellyfin 502)
Dashboard change, not an N100 change. Remove the N100 peer from the group
that distributes the 10.0.25.X/24 network resource. The N100 is a
resource/media host reached via netbird-gw; it must never route into VLAN 25.
Verify on the N100:
```bash
ip route get 10.0.25.X     # want: via 10.0.20.X dev enp1s0 (NOT dev wt0 table netbird)
netbird routes list            # 10.0.25.X/24 no longer selected
```
Once confirmed, the `50-netbird-fix` networkd-dispatcher hook becomes
redundant. Leave it until a reboot confirms the route stays put, then remove.
Do not remove it before confirming, or the 502 reopens.

### Duplicate MikroTik input-chain DNS-accept rules (from 07-30)
List, then remove surplus by explicit number (keep one udp + one tcp). Do
not `remove [find ...]`, that would take the keeper too.
```routeros
/ip firewall filter print where chain=input dst-port=53 src-address=10.0.25.X/24
```

### Samsung-TV-1 (10.0.10.X) VLAN decision (open, needs a choice)
The example.internal migration changed the calculus: with the public cert the TV
no longer needs VLAN 10 for HTTPS to work. Two viable paths:
- VLAN 30 (IoT) plus one firewall exception allowing that TV IP to reach
  `10.0.20.X:8096` only. VLAN 30's RFC1918 drop otherwise blocks Jellyfin.
- Keep on VLAN 10 with DNS sinkholes, accept the trust tradeoff.
No command until the path is chosen.

## Discrepancies to reconcile (flagged, not resolved)

- **netbird-gw Netbird IP**: `<MESH-IP>` (07-23 enrollment) vs
  `<MESH-IP>` (07-30 DNS work). `netbird status` on CT 110 settles it.
- **arr stack location**: Caddy targets `.250` (LXC 105) but there are notes
  of sonarr/prowlarr/radarr on the N100 (`.11`, 8989/9696/7878). `docker ps`
  on both hosts. One is stale.
- **Management switch model**: reference says TL-SG105E, IP table says
  CSS106-1G-4P-1S, same `.88.3` slot. One is wrong.
- **Vaultwarden version**: last seen 1.36.0, below the 1.36.1+ that fixed the
  earlier client/server mismatch. Bump.

## Items surfaced (not done)

- **homelab-docs was never cloned to the Lubuntu laptop.** `~/homelab-docs`
  was an empty directory and `find ~ -type d -name .git` returned nothing.
  The migration off Fedora did not restore the working clone (and likely not
  `~/.ssh` either, so the `gitea` SSH alias + `id_gitea` key need verifying
  before a push will work). The current doc set exists only in the export
  zip plus today's updates until a fresh clone is committed.
- The `.deb`/apt equivalents for the Fedora-specific client-playbook commands
  still need writing.

## Process notes

- Fixes were kept separate from claims of completion. Only the doc edits and
  the MAC read actually happened this session; everything MikroTik-side and
  the route-leak dashboard change are drafted and waiting, and are filed as
  queued rather than done.
- Per repo convention this changelog is append-only; the reference docs and
  IP table were rewritten in place as current-state snapshots. Corrections to
  anything here go in a later changelog.
