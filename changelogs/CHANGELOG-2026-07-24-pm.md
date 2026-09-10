# Homelab Changelog — 2026-07-24 (PM session)

Continuation of the morning session. Theme: a night of remote-access failures
that turned out to have one root cause — and it wasn't Netbird.

---

## ROOT CAUSE: RouterOS advertising IPv6 with no IPv6 upstream

**Credit where due: the router was the suspect from early in the session, and
that call was right.** The diagnosis kept going to Netbird instead — lazy
connections, stale WireGuard sessions, per-host DNS — and each of those was
real but downstream.

### The fault

RouterOS ships a default Neighbor Discovery entry, `interface=all`, enabled.
The router was sending Router Advertisements on every VLAN — telling every
client "I can route IPv6" — while having:

- no DHCPv6-PD client (never requested a prefix from the ISP)
- no global IPv6 address (link-local `fe80::` only, everywhere)
- no `::/0` default route
- an **empty IPv6 firewall filter table**

Clients heard the RA, installed a default IPv6 route toward the router, and
sent every AAAA-preferring connection into a black hole. glibc prefers IPv6
when a AAAA record exists, and `api.netbird.io` resolves AAAA-first.

### Why it was so hard to see

**Established connections survived; only fresh dials failed.** A machine that
connected before its route table went bad stayed healthy until restarted —
so every diagnostic restart *created* the symptom on a previously-working
machine, making the restart look like the cause. The laptop broke on VLAN 10;
the gateway broke on VLAN 25 the moment it was restarted "to fix" the laptop's
problem.

Symptoms this single fault produced over the week:
- Netbird `Management: Disconnected ... context deadline exceeded`
- `ping: sendmsg: Required key not available` (no handshake possible with a
  peer whose control-plane is dead)
- Relays 1/4 from home vs 5/5 elsewhere
- Peers stuck at `Connecting` with ICE candidates `-/-`

### The fix

```
/ipv6 nd set 0 disabled=yes
```

Verified: entry 0 shows the `X` flag. One line, fixes every device on the
network at once — including ones never touched (HAOS, all LXCs, phones).

Clients hold the poisoned route until RA lifetime (30 min) expires or their
networking bounces. Cleared immediately with `nmcli device reconnect` on the
laptop and `pct reboot 110` for the gateway.

### Redundant workarounds now in place (harmless, documented)

`precedence ::ffff:0:0/96  100` in `/etc/gai.conf` on the laptop forces IPv4
preference. Applied during diagnosis; no longer needed with ND disabled, but
left in place.

### If IPv6 is ever wanted for real

Deliberate build, in this order: write the IPv6 firewall FIRST (current
filter table is empty = accept-everything, which exposes every host directly),
then DHCPv6-PD client on ether1, pool → VLAN assignment, ND re-enabled with
the delegated prefix. Weekend project; seclab isolation must be considered.

---

## Gateway (LXC 110) recovery

Compounding fault found during diagnosis: the container's `/etc/resolv.conf`
had reverted to `nameserver 10.0.10.X` — the unreachable address PVE
injects, the same issue fixed at build time. DNS resolution inside the
container was fully dead (`getent` returned nothing).

Resolved wholesale with `pct reboot 110` after `pct set 110 --nameserver`,
which regenerates resolv.conf, flushes stale v6 routes, and restarts netbird
in one step — the lesson being that for LXC network-state problems, a
container reboot beats incremental service restarts every time.

---

## Verification from a second foreign network

With ND disabled and the gateway rebooted, tested from a different off-site
network than the previous verification:

| Check | Result |
|-------|--------|
| Mesh peers | **2/2 connected** — first time the full mesh has been up off-network |
| N100 ping | 0% loss, ~50ms avg (27–100ms, higher jitter than network #1) |
| Backup service run | Started; higher-latency network, longer run expected |

Two different NATs now confirmed for the mesh path. The gateway being up
off-network also closes the jump-host verification owed since the lockout
incident — pending the SSH landing, which was queued behind the backup run.

---

## Unblocked by tonight's fixes

Now that the mesh holds from foreign networks:

- **Nextcloud remote access** — N100 is a direct peer; needs `trusted_domains`
  entry for the Netbird IP and a UFW allow on `wt0` for the port
- **ntfy → mobile** — Bambuddy→ntfy wiring is LAN-only (pending since May);
  phone-side needs the phone enrolled as a peer plus the VLAN 25 Network
- **Remote Gitea without tunnels** — same VLAN 25 Network

## Still open

1. **The `10.0.25.X/24` Network in the Netbird dashboard** — repeatedly
   deferred all week; five minutes; unlocks Gitea, ntfy, Vaultwarden remotely
2. Backup failure alerting via ntfy (silent success/failure remains)
3. Credential escrow (Vaultwarden entry + printed copy)
4. Restore drill — Outcome 2 still has zero evidence
5. pve-svc host re-enrollment on the mesh
6. VLAN 10 → VLAN 88 SSH path (`No route to host` to 88.10 observed during
   the session, untriaged — may have been transient, worth a check from home)
7. Thin pool: discard/fstrim work incomplete; vm-105 media move undecided


---

## RESOLVED — remote service access working (end of session)

After the ND fix and gateway reboot, built the Netbird Network that had been
deferred all week. The 422 errors along the way had one cause worth recording:

**A policy's source group may contain only peers; network resources must live
in their own group. Mixing the two in one group produces
`422: specify either sources or source resources, not both`.** Every failed
attempt tonight violated this — including a suggested shortcut that reused the
existing peer group for resources, which was structurally impossible.

Working configuration:

| Element | Value |
|---------|-------|
| Resource | `10.0.25.X/24` → group `home-services` |
| Resource | `10.0.20.X/32` → group `home-services` |
| Routing peer | netbird-gw |
| Policy | source `HOME-INFRA` (peers) → dest `home-services` (resources), TCP 2222/3000/8000 |

Verified off-network:

- Gitea `10.0.25.X:3000` → **200 OK**
- Bambuddy `10.0.20.X:8000` → **405 on HEAD** — reachable; the server
  rejects HEAD requests, which is a response, not a failure. A GET returns the
  UI. This confirms the VLAN 25 → VLAN 20 crossing through the MikroTik works.
- Home Assistant `<MESH-IP>:8123` → reachable as a direct peer, no Network
  needed.

Vaultwarden is inside the /24 and reachable once port 443 is added to the
policy; over the bare IP it throws a cert warning (Caddy's cert is for the
hostname), so a hosts entry or Netbird DNS is the clean path.

## Access cheatsheet (IP, no DNS)

| Service | URL |
|---------|-----|
| Gitea | http://10.0.25.X:3000 |
| Bambuddy | http://10.0.20.X:8000 |
| Home Assistant | http://<MESH-IP>:8123 |
| Vaultwarden | https://10.0.25.X (add 443 to policy first) |
