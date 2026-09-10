# Troubleshooting

Every entry here comes from a real incident in this lab. Symptoms first, then the test, then the fix.

## Read the log first

```
tail -20 /var/log/rsync-snapshot.log
```

The two lines that matter:
- `src: <ip> -> target: <name>` is the location decision.
- `complete via <target>` or an abort line is the outcome.

## Symptom: "target: n100-lan" but the run aborts, and you are home

The script says home and the NAS does not answer. The script is telling the truth. The NAS side is broken.

Test from the laptop:

```
ping -c2 -W2 10.0.20.X
nc -zvw3 10.0.20.X 445
```

Test from inside the NAS (go through the Proxmox host if ssh is dead):

```
ip route get <laptop-ip>
ip route show table netbird
```

If the reply route shows `dev wt0`, the NAS's VPN agent installed a route covering the laptop's subnet and replies are diving into the tunnel. Fix on the NAS:

```
sudo ip rule add to 10.0.10.X/24 lookup main pref 100
```

Pin every home subnet, not only the one that broke. Persist the rules in a networkd-dispatcher hook, because manual ip rules do not survive reboot. This exact class of bug hit twice before on other subnets (2026-07-28 and 2026-08-07 against VLAN 25, 2026-08-14 suspected against VLAN 10).

## Symptom: home, VPN up, and LAN services (SMB, ssh) to the NAS time out

Test on the laptop:

```
ip route get 10.0.20.X
```

`dev wt0` means the laptop installed the VPN route for the NAS's subnet and LAN traffic is riding the tunnel. Stopgap:

```
netbird routes deselect <route-id>
```

Real fix, server side: a Peer Network Range posture check with the Block action, listing all home subnets, attached to the laptop's route policy. When the laptop holds a home address, the routes are not distributed at all. Do not match on the public egress IP. The ISP address changes.

## Symptom: intermittent total blackout to the NAS, then it heals itself

Seen 2026-08-14, roughly 14 minutes. Ping, 22, 445, 8096 all dead from the laptop while Caddy-proxied services stayed up. Discriminator: services that stayed up were reached from a subnet the NAS pins to its main table. The dead client was in an unpinned subnet. During the next occurrence, run `ip route show table netbird` on the NAS. A populated table during the outage confirms the reply-hijack theory. An empty table during the outage kills it, and the next suspects are the Wi-Fi layer and the router firewall.

## Symptom: rsync exits 24 and the service shows failed

Exit 24 means files vanished during the copy. Normal on a live home directory. The unit must carry `SuccessExitStatus=0 24`. If the service shows failed on 24, the unit is missing that line. Add it, then `systemctl daemon-reload`.

## Symptom: leftover .incomplete-* or junk snapshot folders on the NAS

Should be self-healing. The trap removes the current run's partial on failure. The start-of-run sweep removes anything a hard death left behind. If junk with a final timestamp name exists, it predates the atomic-rename design. Delete it by hand once. Folders created by the current script cannot be junk if they carry a final name.

## Symptom: probe fails with the target clearly up

Check the ssh alias, not the network first:

```
sudo ssh -v -o ConnectTimeout=5 n100-lan true 2>&1 | tail -15
```

Common causes seen here: the mesh alias pointing at a stale mesh IP after a peer re-enrollment, and an empty authorized_keys on the target (the key install was assumed, never verified). BatchMode hides password prompts, so a missing key looks like a timeout-free instant failure, not a hang.

## Notes that save time

1. sudo on this laptop is sudo-rs. Three failed password attempts lock you out for a cooldown. Slow down.
2. Snapshot folder mtimes on the NAS can predate the run. rsync preserves source directory times. Trust the folder names and the log, not ls dates.
3. `netbird routes select none` is invalid syntax. Deselect by route ID from `netbird routes list`.
4. When ssh to a machine is dead, go around: the Proxmox hosts have legs on multiple VLANs and `pct exec` reaches every container.
