# Changelog 2026-08-01

Session scope: design and first build of the rsync-based backup, replacing the restic implementation.

## Why replace restic

The restic system worked (verified restore, off-network runs completed 2026-07-24). It was replaced for one reason: the living-off-the-land requirement. restic is a third-party binary. rsync ships with the OS. The internship objective is a backup that can be rebuilt anywhere with stock tools.

## Decisions made

1. Tool: rsync with --link-dest hardlink snapshots. Compared against dd, tar+gz, and Proxmox backup tooling. See docs/DESIGN.md for the comparison table.
2. Architecture: push, laptop to NAS. A pull design was explored (security argument: the laptop should not hold standing credentials to the NAS). Pull required an SSH server on the laptop and put the schedule on the wrong machine. Returned to push after weighing the tradeoffs.
3. Path rule stated this period, governing all later work: on my network, use ssh and not the VPN. Off my network, use the VPN. First implementation was a reachability probe (try the LAN address, fall back to the mesh address). **unverified at the time** whether a reachability probe can distinguish home from tunneled. Later falsified. See CHANGELOG-2026-08-14.
4. Retention: hardlink snapshots with a keep-newest count, pruned after each successful run.
5. Bugs found during the build: set -e plus find on permission-denied paths silently killed the script before the symlink step, and the script lacked a lock and an interrupt trap. All three fixed.

## State at end of session

Script, excludes, and schedule design in place. Key authorization to the NAS not yet verified. That gate blocked the first real snapshot and carried into the next session.
