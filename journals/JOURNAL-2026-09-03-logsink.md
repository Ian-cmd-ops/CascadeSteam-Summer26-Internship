# 2026-09-03 — Central Log Sink (CT 115)

## What I built
I built a central log sink called "logsink" on pve-lab. It runs as CT 115, a Debian 13 unprivileged container.
The container has one job. It collects logs from every host on the network and writes them to append-only files.

## Why
I had a file deletion incident on the N100 this week. The files were gone and the logs were volatile. I could not prove what deleted them. That gap is the reason this exists.
pve-lab-cs (the internship Proxmox host) had the same problem. Its hostname was still the default `pve` and its logs had nowhere durable to land. Centralizing logs fixes that for both the homelab and the internship deliverables.

## How it works
- CT 115 sits on vmbr0 management, at 10.0.88.X. DNS name is logsink.lan.
- It runs rsyslog with imtcp listening on TCP 514.
- Each sender writes to its own dated file under /var/log/remote. Example: N100/2026-09-03.log.
- Storage is a dedicated 477GB NVMe in pve-lab. I wiped it (it had an old Windows install) and reformatted it ext4, label "logsink". It's mounted at /mnt/logsink by UUID and bind-mounted into CT 115 at /var/log/remote.
- The container is unprivileged. Its UID map is 100000, so the host directory is chowned to 100000:100000.

## Integrity layer
Logs are worthless if someone can edit them after the fact. I added a seal step.
- logsink-seal.timer runs at 00:10. It sets chattr +a on every prior day's file, so old entries can't be altered or deleted, only appended.
- logsink-hash.timer runs at 00:20. It keeps a sha256 manifest at /var/lib/logsink-manifest.sha256 and pushes an urgent ntfy alert on any mismatch.
- I tested both with throwaway files before trusting them.
The chattr step has to run on the pve-lab host, not inside CT 115. Unprivileged containers can't set that attribute themselves.

## Access
There's a read-only viewer for browsing logs without shell access. It runs as a dedicated `logview` user, files are mode 0644, rsyslog's fileCreateMode is 0644, and it's served through ttyd with basic auth.

## Senders
- N100: journald and the Samba audit log.
- LXC 105 (media stack): needs Docker's log driver set to journald first, to capture container stdout. Not done yet.
- pve-lab-cs (internship host): forwards syslog to logsink, same as everything else.

## Design decisions
- Forward by raw IP, not DNS. One less thing that can break the pipe.
- Write-only sink for now. Plain TCP for now, TLS later.
- 180-day retention.
- Kept separate from the log analysis layer. Loki/Alloy/Promtail into the LXC 111 observability stack is a planned next step, not part of this build.

## Still open
- Confirm N100 and LXC 105 sender configs are actually landing in logsink.
- Verify the MikroTik rule allowing VLAN 20 to reach 88:514 (logsink's port).
- Docker log-driver=journald on LXC 105.

## Internship relevance
This is a documentation and monitoring deliverable. It gives the placement a durable, tamper-evident log trail across the internship host (pve-lab-cs) and the rest of the environment it depends on. It also directly supports the backup-automation and containers/virtualization learning outcomes already logged for this placement.
