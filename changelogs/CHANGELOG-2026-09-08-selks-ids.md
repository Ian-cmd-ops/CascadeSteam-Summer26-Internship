# 2026-09-08 (evening, cont'd) - SELKS / IDS build

## Installed

- SELKS (Suricata + EveBox + Scirius) on the "eve" NUC (NUC5i3RYK), via balenaEtcher (had to grab a newer release build, v2.1.6, since the Cloudsmith-repo .deb was a stale 1.14.3 with broken GTK2-era dependencies on this OS version - the balena team's own changelog confirms this exact fix landed in v2.1.5).
- Static lease 10.0.88.X on Controller's dhcp-mgmt, matching its existing dynamic lease. Same MAC as the old "eve" VLAN 20 Klipper-era lease (stale duplicate left in place, not yet cleaned up).
- Changed both selks-user passwords (OS and web) from the documented SELKS defaults immediately after first login.

## IDS traffic mirroring - not working yet, root cause fully diagnosed

- Confirmed via three separate controlled tests (tcpdump on the NUC while pinging from a separate device, both LAN-side ether2 and WAN-side ether1 as mirror source) that the MikroTik Controller's switch chip (IPQ-PPE) only mirrors broadcast/ARP/STP/CDP/LLDP frames, never real unicast traffic. This is a hardware/firmware limitation, not a misconfiguration - ruled out definitively.
- Attempted RouterOS's TZSP streaming tool (`/tool sniffer`) as an alternative, since it captures via the CPU rather than the switch chip and can send real traffic to a remote host. Blocked by RouterOS's `device-mode` security lock, which requires a physical button press on the Controller to unlock. Not resolved this session.
- Built the full receiving pipeline on the NUC anyway, in case the device-mode block gets cleared later: compiled `tzsp2pcap` from Debian's source tarball (package wasn't actually available even via bookworm-backports, despite initial search results suggesting it was), set up a `dummy0` virtual interface, wired both into a systemd service (`tzspstream.service`) running `tzsp2pcap | tcpreplay` in a detached screen session. Confirmed the pipeline itself works via `tcpdump -i dummy0`. It's just never received real Controller traffic because the Controller side never got past the device-mode block.
- Identified the TL-SG105E (already in the physical chain between Controller and AP2) as a hardware-confirmed-capable alternative mirror point - its official product spec/manual confirms real ingress+egress unicast port mirroring. Used its Port Statistics page to identify Port 1 and Port 2 as the live trunk (heavy sustained traffic on both), Port 3 as genuinely free.
- Left a stray Port Mirror config on the TL-SG105E (Enable, Mirroring Port = Port 2) from before it was clarified the NUC hadn't actually been moved there yet. Port 2 is a live trunk port - this needs to be set back to Disable.
- Decision: hold off on choosing between the physical move (to TL-SG105E Port 3) and clearing the RouterOS device-mode block for TZSP. Both are viable, neither executed.

## Cleanup still pending (not urgent, but real)

- `/interface ethernet switch set switch1 mirror-source=none mirror-target=none` on the Controller (currently still set to ether1/ether4 from testing)
- Disable Port Mirror on the TL-SG105E (currently Enable, Port 2)
- Remove stale VLAN 20 lease for "eve" (10.0.20.X, same MAC as the new SELKS lease)
- `tzspstream.service` still running/idling on the NUC - harmless, but should be stopped if the TZSP path is ultimately abandoned

## Full reasoning behind mirror-point choice

Documented in selks-ids.md: the Controller<->TL-SG105E<->AP2 link carries
nearly all traffic worth inspecting (WAN-bound, inter-VLAN, and everything
downstream of AP2 including the whole rack and wifi clients), since routing
happens at the Controller. Accepted blind spot: purely local traffic between
two devices on the same leaf switch (e.g. GS305-connected Xbox/Win11) never
crosses this link and won't be visible regardless of which mirror approach
is chosen.
