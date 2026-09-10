# Acceptance Criteria Status

Deliverable: an automatic laptop backup system, documented, restorable, working from anywhere. Status as of 2026-08-14.

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | Recover the laptop from a full wipe | Partial | Restore playbook and pull-restore script exist. The proving drill (criterion 3) has not run. |
| 2 | Back up home directory, apps, and data | Partial | /home is covered. /etc and the installed-apps manifest are planned, not built. A wipe recovery currently rebuilds apps by hand. |
| 3 | Minimum two restorable snapshots | Met, pending proof | Multiple snapshots exist on the NAS with a working hardlink chain (16G full, 70 to 200M incrementals). "Restorable" is proven only by criterion 4. |
| 4 | Stand the backup up as a VM on the Proxmox lab host | Not run | VM 201 restore drill is the acceptance test. Scheduled next. |
| 5 | Works from anywhere | Partial | Location-based path selection is deployed and verified for the home case. A completed off-network run (`complete via n100-mesh` in the log) is still pending. |
| 6 | Living off the land | Met | rsync, ssh, systemd, coreutils only. No third-party binaries. |
| 7 | Reuse existing infrastructure | Met | Existing NAS, existing SSH keys, existing VPN mesh. |
| 8 | Daily schedule | Met | systemd timer, daily, Persistent=true, randomized delay. |
| 9 | Playbook online | Partial | This repo is the playbook. PDF/DOCX export and push to the org docs repo pending. |

## The critical path to full acceptance

1. Extend scope: /etc plus apps manifest.
2. One completed off-network run.
3. VM 201 restore drill on the Proxmox lab host.
4. Export and file the documentation.
