# Laptop Restore Playbook

Pull an rsync snapshot from the N100 and recover it into a fresh VM.

This playbook restores the laptop backup made by `rsync-snapshot.sh`.
It targets a rebuild as VM 201 on pve-lab. This is the internship
acceptance path: stand the backup up as a VM.

## Scope

- The backup stores snapshots at `/mnt/backups/mirror-laptop/` on the N100.
- `latest` points at the newest snapshot.
- Each snapshot is a plain file tree. A restore is just rsync in reverse.

Warning: The current backup captures `/home/ian` only. It does not capture
`/etc` or an apps list. So this playbook fully restores your home directory.
A full machine rebuild needs those extra items first. See "Extend the backup".
The laptop runs Ubuntu 26.04 LTS. Always install the same version in the
restore VM, so the apps list matches the repos.

## Before you start

Confirm all four items. Do not restore until each one passes.

1. A good snapshot exists. Run on any machine that reaches the N100:
   - `ssh ian@10.0.20.X 'ls -l /mnt/backups/mirror-laptop/'`
   - You must see a timestamped folder and `latest ->` pointing at it.
2. The snapshot has real files:
   - `ssh ian@10.0.20.X 'ls /mnt/backups/mirror-laptop/latest/ | head'`
3. You can log in to the N100 as `ian` with a password.
4. pve-lab is up and you can create a VM on it.

## Access model

The restore VM is new. It has no SSH key on the N100.
Pick one access model before you pull.

- Model A, quick drill: pull as `ian` over the LAN with a password.
  Files land owned by `ian`. This is correct for a `/home/ian` restore.
  Use this model for the acceptance drill.
- Model B, exact ownership: pull as `root` with `--numeric-ids`.
  This keeps original UIDs and GIDs. It needs the VM key authorized on the
  N100 first. Use this only if you restore system files that need root.

This playbook uses Model A. Model B steps are in "Exact-ownership restore".

## Step 1: Create the restore VM

1. On pve-lab, create a new VM.
2. Name it `laptop-restore`. Use VM ID 201.
3. Install Ubuntu 26.04. Match the laptop's OS version.
4. Put the VM on VLAN 20, the same network as the N100.
5. Create a user named `ian` during install.
6. Boot the VM and log in as `ian`.

## Step 2: Prepare the VM

Run these on the VM.

1. Update the package list:
   - `sudo apt-get update`
2. Install rsync:
   - `sudo apt-get install -y rsync`
3. Test the path to the N100:
   - `ping -c 3 10.0.20.X`
   - `ssh ian@10.0.20.X true`

Warning: Both tests must pass before you pull. If ping fails, the VM is on
the wrong network. Fix the VLAN first. A pull to an unreachable host hangs.

## Step 3: Restore the home directory

Run this on the VM as `ian`.

1. Pull the latest snapshot into your home directory:
   ```
   rsync -aAX ian@10.0.20.X:/mnt/backups/mirror-laptop/latest/ /home/ian/
   ```
2. Wait for rsync to finish. It prints a summary at the end.

Note: The trailing slash on `latest/` copies the contents into `/home/ian`.
Do not drop that slash. Without it, rsync makes a `latest` subfolder.

Tip: To preview first, add `-n` for a dry run. This shows what would move
and changes nothing:
```
rsync -aAXn ian@10.0.20.X:/mnt/backups/mirror-laptop/latest/ /home/ian/
```

## Step 4: Verify the restore

Run these on the VM.

1. List your home directory:
   - `ls -la /home/ian/`
2. Spot-check a few known files open and read correctly.
3. Check the size looks right:
   - `du -sh /home/ian/`

The restore is done when your files are present and readable.

## Practice drill: VM on the laptop

Use this to rehearse the restore before the pve-lab drill. It proves the
pull and the YubiKey flow. It is not the acceptance drill. The acceptance
drill runs on pve-lab as VM 201.

Host: the laptop (24 GB RAM, Ryzen 5 8640HS, Ubuntu 26.04).

1. Install the hypervisor on the laptop:
   - `sudo apt-get install -y virt-manager qemu-kvm`
   - `sudo adduser ian libvirt`
   - Log out and log back in.
2. Download the Ubuntu 26.04 desktop ISO from ubuntu.com before the demo.
   The file is large. Do not download it during the demo.
3. Open Virtual Machine Manager. Create a new VM:
   - Install media: the 26.04 ISO.
   - Memory: 6144 MiB. The field is MiB, not GB.
   - CPUs: 4.
   - Disk: 40 GB. Keep the image in the default location
     (`/var/lib/libvirt/images`). Do not put it under `/home`,
     or the backup will capture it.
   - Network: default NAT. The VM only makes outbound SSH.
4. Install Ubuntu 26.04 in the VM. Create user `ian`.
5. Inside the VM, prepare and test the path:
   - `sudo apt-get update && sudo apt-get install -y rsync libfido2-1 openssh-client`
   - `ping -c 3 10.0.20.X`
6. Copy `rsync-recover.sh` into the VM. Fetch it from the N100 or paste it.
7. First pass: restore with the ian password. Follow "Step 3: Restore the
   home directory". This proves the pull with no hardware in the path.
8. Second pass, YubiKey flow (only after the token key is enrolled on the
   N100):
   - Plug the YubiKey into the laptop (USB-C).
   - In the VM window menu: Virtual Machine > Redirect USB device.
     Tick the Yubico entry. The key moves into the VM.
   - In the VM: `ssh-keygen -K` and enter the FIDO2 PIN. This writes the
     key handle from the token.
   - Run `./rsync-recover.sh --list`, then `--run`. Enter the PIN and
     touch the key when it blinks.

Note: A restore onto the same laptop that holds the VM does not prove
disaster recovery. A dead laptop takes this VM host with it. The pve-lab
drill is the real proof.

## Restore a single file or folder

You do not need a full restore to get one file back.

1. List snapshots to find the date you want:
   - `ssh ian@10.0.20.X 'ls /mnt/backups/mirror-laptop/'`
2. Pull just the path you need. Example for one folder:
   ```
   rsync -aAX ian@10.0.20.X:/mnt/backups/mirror-laptop/2026-08-13T09-00-00/Documents/ /home/ian/Documents/
   ```

## Exact-ownership restore (Model B)

Use this only when you must keep original UIDs and GIDs.

1. On the VM, make a key for root:
   - `sudo ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_restore`
2. Print the public half:
   - `sudo ssh-keygen -y -f /root/.ssh/id_restore`
3. On the N100, add that public line to root's authorized keys.
   Log in as `ian`, then run:
   - `sudo tee -a /root/.ssh/authorized_keys` and paste the line, then Ctrl-D
   - `sudo chmod 600 /root/.ssh/authorized_keys`
4. On the VM, pull as root with numeric IDs:
   ```
   sudo rsync -aAX --numeric-ids -e 'ssh -i /root/.ssh/id_restore' \
     root@10.0.20.X:/mnt/backups/mirror-laptop/latest/ /home/ian/
   ```

Warning: Do not restore over a running production system. Restore into the
fresh VM only. A wrong destination path can overwrite good data.

## Extend the backup (for full machine rebuild)

The current backup holds `/home/ian` only. To rebuild a whole machine,
capture `/etc` and an apps list too. Add these to the backup source.

Run these on the LAPTOP before a backup, as root, to write the apps list
into your home directory so the snapshot picks it up:

1. Save the manual apt packages:
   - `apt-mark showmanual > /home/ian/apps-apt.txt`
2. Save the dpkg selections:
   - `dpkg --get-selections > /home/ian/apps-dpkg.txt`
3. Save the flatpak list:
   - `flatpak list --app --columns=application > /home/ian/apps-flatpak.txt`

To include `/etc`, add `/etc` as a second source in the backup script.
This changes the snapshot layout, so tell your helper before you do it.

## Reinstall apps (only if the lists were captured)

Run these on the VM after the home restore.

1. Reinstall apt packages:
   - `sudo apt-get update`
   - `sudo apt-get install -y $(cat /home/ian/apps-apt.txt)`
2. Or restore exact dpkg selections:
   - `sudo dpkg --set-selections < /home/ian/apps-dpkg.txt`
   - `sudo apt-get dselect-upgrade`
3. Reinstall flatpaks:
   - `xargs -n1 flatpak install -y flathub < /home/ian/apps-flatpak.txt`

## Clean up

1. Remove any temporary key files you made on the VM or the N100.
2. If this was a drill, you can delete VM 201 when you finish.
3. Record the result. Note the snapshot date you restored and the outcome.

## Notes

- LAN vs mesh: This playbook uses the N100 LAN IP `10.0.20.X`.
  Use it when the VM is on VLAN 20. The mesh IP is for off-network use only.
- One snapshot is one point in time. Older snapshots stay under the
  timestamped folders until the backup prunes them.
- Ownership: A pull as `ian` gives files owned by `ian`. This is correct for
  a home restore. Use Model B only for system files that need root ownership.
