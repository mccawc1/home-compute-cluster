# Mini PC setup kit

This folder lives on the Ventoy stick next to the ISO files. Ventoy ignores it,
so it does not affect booting. After Ubuntu Server is installed on the mini PC,
these scripts turn it into the NAS, agent box and camera server we planned.

Written 2026-10-16 for the Altex/MSI Cubi 5 12M (i3-1215U). Verified against
the Frigate docs on that date. Re-check anything marked VERIFY if you run this
months later.

## Order of operations

1. Install Ubuntu Server 26.04.1 from the stick (F11 at the logo, pick the
   Ubuntu ISO, choose "Use an entire disk", user name `chris`, tick
   "Install OpenSSH server"). Reboot and pull the stick.
2. Log in at the mini PC's own keyboard once. Plug the stick back in and run:

       sudo mkdir -p /mnt/stick
       sudo mount /dev/disk/by-label/Ventoy /mnt/stick
       cp -r /mnt/stick/setup ~/setup
       cd ~/setup

3. Run the scripts in order. Each one explains what it did at the end.

       bash 00-first-login.sh      # updates, basics, your SSH key, firewall
       (now test key login from the Zorin PC, see zorin-side/README.md)
       bash 05-lock-down-ssh.sh    # turns off password login, only after the test
       bash 10-docker.sh           # Docker from Docker's own repo
       bash 20-ollama.sh           # local model server, reachable from the LAN
       bash 30-agents.sh           # Claude Code and OpenCode, tmux session helper
       bash 40-frigate.sh          # camera server, waits for cameras

4. Storage (ZFS mirror, Samba) is not scripted here on purpose: it formats
   drives, so it should be done step by step with the drive names in front of
   you. The RUNBOOK in the workspace covers it (`../RUNBOOK.md`, Part A steps 6 to 8). Frigate records to
   `/srv/frigate` until the ZFS pool exists; move it afterwards.

## Network plan (fill in)

| Item | Value |
| --- | --- |
| Zorin PC | chris-SER8, <DESKTOP_IP> |
| LAN | <LAN_IP>/22 |
| Mini PC hostname | minipc |
| Mini PC IP | <HEAD_IP> on enp45s0, MAC <MAC_ADDRESS> (reserve it on the router) |
| Mini PC 2.5 GbE port | enp46s0, MAC <MAC_ADDRESS> (for the camera network later) |
| Time zone | America/Chicago |

## What is in here

| Path | Purpose |
| --- | --- |
| `00-first-login.sh` | apt update, tmux htop curl git, time zone, your SSH key, ufw |
| `05-lock-down-ssh.sh` | password login off (run after a successful key login) |
| `10-docker.sh` | Docker Engine and Compose plugin |
| `20-ollama.sh` | Ollama listening on 0.0.0.0, first small model, firewall rule |
| `30-agents.sh` | Claude Code, OpenCode, `agent` tmux helper |
| `40-frigate.sh` | creates folders, exports the detection model, starts Frigate |
| `frigate/` | docker-compose.yml, config.yml, export-yolov9.sh, .env.example |
| `ssh/authorized_keys` | the Zorin PC's public key (private key stays on the Zorin PC) |
| `zorin-side/` | what to set up on the Zorin PC to use the mini PC |

## Known issue: Ubuntu Server will not install from Ventoy

Booting `ubuntu-26.04.1-live-server-amd64.iso` through Ventoy 1.1.18 fails at
the installer's storage step ("problem examining the storage devices", log
says `Invalid dep_id (disk-dm-1)`). Renaming Ventoy's device-mapper devices
does not help. For an Ubuntu reinstall, write the ISO straight to a stick:

    sudo dd if=~/ISOs/ubuntu-26.04.1-live-server-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync

then rebuild the Ventoy stick afterwards. The other three ISOs on this stick
(Zorin, SystemRescue, Memtest86+) boot fine from Ventoy. Tracked upstream as
Launchpad bug 2149811 and Ventoy issue 3567.

## Rules the scripts follow

- They stop on the first error (`set -euo pipefail`).
- They never format a drive.
- Anything that opens a port opens it to the LAN only, never the internet.
- Downloads use IPv4 (`-4`) because IPv6 does not route on this LAN.
