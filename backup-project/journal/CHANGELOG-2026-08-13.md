# Changelog 2026-08-13

Session scope: pass the key gate, land the first real snapshots, harden the script, update the mesh alias after the VPN rebuild.

## Blocker cleared

The NAS root authorized_keys was empty (0 bytes, dated April 2025). The key install had been assumed, never verified. Every prior backup attempt failed on this. The public key install was completed and confirmed: KEY OK.

## Snapshots landed

1. Full: 2026-08-13T10-14-07, 16G.
2. Incremental: 2026-08-13T13-02-37, exit 0, roughly 80 MB sent, hardlink speedup around 307.

The two-restorable-snapshots criterion is met on disk. Proof waits for the VM drill.

## Script hardening

Rewritten with: flock single-instance lock, cleanup trap (EXIT/INT/TERM deletes the run's own partial), --info=progress2 live output, 14-snapshot prune, and a completion log line naming the path used (`complete via <target>`). Earlier "missing latest symlink" and leftover-partial symptoms were interrupted runs, not a script bug. Two junk snapshot folders from interrupted runs were removed by hand.

## VPN interaction

The mesh was rebuilt this day (new peer IPs). The n100-mesh SSH alias was updated to the NAS's new mesh address. Known regression at session end: the deployed script's LAN-first probe cannot tell a true LAN path from a tunneled one, and route flapping during the rebuild caused mid-transfer resets. Both threads continue in the next entry.

## Hardware key plan

Two-token FIDO plan adopted for recovery credentials. Token A is on hand. Token B to buy. The daily timer keeps a file key because unattended runs cannot touch a hardware token. Recovery and escrow move to the tokens. NAS root password reset still pending, needed for a real restore.
