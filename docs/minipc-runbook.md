# Mini PC server runbook (minipc)

The guide for finishing Chris's mini PC server, plus a short record of how the box was built so a reinstall is not a research project.

**Verified 2026-10-16.** Checked against: the state of minipc that evening, the setup kit in `stick-kit/` (a copy lives at `~/setup` on minipc), packages.ubuntu.com for Ubuntu 26.04 "resolute" (zfsutils-linux 2.4.1, samba 4.23, cockpit 360, restic 0.18, all present), download.docker.com and pkgs.tailscale.com (both already carry a resolute repository), docs.frigate.video, restic.readthedocs.io, cockpit-project.org and memtest.org (Memtest86+ 9.00 came out 2026-10-15). If you pick this up months later, re-check anything version-specific before trusting it.

## How to read this

- Two machines. **chris-SER8** is the Zorin desktop at <DESKTOP_IP>. **minipc** is the server at <HEAD_IP>. The text before each command block says which machine it is for.
- "On minipc" commands are typed after you connect with the block below. Anything that needs sudo will ask for your minipc password. From chris-SER8 you can also wrap a single command as `ssh -t minipc 'COMMAND'`; the `-t` lets sudo ask for the password.
- One command per block. The line after each block says what you should see.
- Words in CAPS are placeholders. Replace them before running.
- A line starting with **WARNING** marks a command that destroys data or can lock you out. Read the whole step before running it.
- `curl` and `wget` always get `-4`. IPv6 is advertised on this LAN but does not route, and without `-4` downloads hang for minutes. Since 2026-10-16 the mini PC ignores IPv6 on its LAN port (step 0b), so there `-4` is belt and braces; on chris-SER8 it still matters.
- No kit script formats a drive. Step 6 here does, and so do the stick commands in Part B; each says so.

Connect to the server (on chris-SER8):

```bash
ssh minipc
```
You should see: a prompt reading `chris@minipc:~$` with no password asked.

## Where things stand (updated 2026-10-17, 00:00)

| Done | Not done yet |
| --- | --- |
| Ubuntu Server 26.04.1 installed, hostname minipc, user chris | BIOS: confirm Restore after AC Power Loss and the pull-the-plug test (step 2) |
| Frigate running at /srv/frigate, UI at https://<HEAD_IP>:8971, no cameras yet (step 8, 23:56) | Frigate admin password: change it at first login, then move Frigate to tank/frigate after step 6 |
| Cockpit at https://<HEAD_IP>:9090, LAN only (step 9a, 23:51) | Tailscale (step 9b) |
| Passwordless sudo for chris on minipc (`/etc/sudoers.d/90-chris-nopasswd`), so Claude can run setup unattended | |
| Boots unattended, efibootmgr shows only the Ubuntu entry | Claude Code sign-in on minipc (end of step 3c), planned for tomorrow with Austin |
| Kit scripts 00, 05, 10, 20, 30 have run and were verified | SSH connection saved in the Claude desktop app (step 4) |
| SSH is keys only (step 0 fixed the password-login gap at 23:11) | RAM upgrade and Memtest86+ (step 5) |
| IPv6 off on the LAN port (step 0b, 23:28); downloads no longer stall | ZFS mirror, Samba, backups (steps 6, 7, 10) |
| Docker 29.9.1 and Compose v5.6.0 working without sudo | 40-frigate and the move to the pool (step 8) |
| Ollama serving llama3.2:3b on the LAN at port 11434 | |
| Claude Code 2.1.302, OpenCode and the `agent` tmux helper installed | Cameras, Ventoy stick rebuild (step 11, Part B) |
| Kit bugs fixed in both copies: 05 writes 00-kit.conf; 40 and 10 survive a cut-off pipe | TV as third monitor: buy the USB-C dummy plug, then the chris-SER8 side of step 12 |
| Moonlight kiosk live on the TV (mini PC tty1); LG TV network control paired and verified from minipc | Reserve the TV's address <LAN_IP> on the router; turn on the TV's wake-over-network setting |
| TV Remote desktop widget installed on chris-SER8 (both monitors, autostart), paired with the TV | Build `TVRemote.exe` for Austin: GitHub Actions does it on every push to `mccawc1/tv-remote` (or `tv-remote/desktop-qt/build-windows.bat` on a Windows PC); send it with `AUSTIN.md` |
| Cross-platform Qt edition written and running from source here (`tv-remote/desktop-qt/`) | Everything in `tv-remote/PLAN.md`: phones, other brands, several TVs, selling |
| GitHub repository `mccawc1/tv-remote` (private) created 2026-10-17 02:10 and pushed; the Actions workflow builds TVRemote.exe and tv-remote on every push | Fetch `TVRemote.exe` from the latest green run's Artifacts and send it to Austin with `AUSTIN.md` |
| 2026-10-17 03:25: LG reconnect stall fixed in the drivers (the LG library deadlocked when the TV said Power Off), simulation suite `tests/run_sim.py` passes here (fake LG, Roku, Samsung, both apps, every skin), 34 skins plus Match my desktop in `skins/` for every app, drag-anywhere placement, Back above Left, + buttons, live opacity; pushed as commits 836b345 and 6557ce2; `tests.yml` runs the suite on Linux, Windows and macOS | Read the three runner results in the Actions tab; then send Austin the new `TVRemote.exe` |
| 03:00: driver layer (LG, Roku, Samsung), TV drop-down, Privacy tab, self-reconnect after a TV power cycle, in both editions; pushed, builds running | Reconnect confirmed by Chris 03:35. Austin to test on Windows and a real Samsung whenever one is near |
| Router reservation for .50 confirmed by Chris in the Deco app | |
| ufw on: 22 from anywhere; 11434, 8971, 8554, 8555, 9090 from the LAN only | |

Pick up at: step 3c sign-in (`ssh minipc`, `agent`, `claude`, choose the Claude account login, open the address in a browser, paste the code). Do this only when Austin is on over TeamViewer and has given his permission, since the sign-in uses his Claude account. Then step 4, then step 2 when the TV and keyboard are on the mini PC.

## Part A: What's next

Do the steps in this order. Each one is independent enough to stop after, and the checklist in step 13 tells you how to confirm a stage before moving on.

### 0. Fix found 2026-10-16: password login was still on (done 2026-10-16 23:11)

The kit's `05-lock-down-ssh.sh` wrote `/etc/ssh/sshd_config.d/60-kit.conf` with `PasswordAuthentication no`, but Ubuntu's installer left `/etc/ssh/sshd_config.d/50-cloud-init.conf` with `PasswordAuthentication yes`. The SSH server reads these drop-in files in name order and keeps the first value it sees for each setting, so `50-` beats `60-` and the lockdown never took effect. Checked from chris-SER8 with a key-less probe: the server still offers `publickey,password`.

Fix: rename the kit's file so it sorts first. One line, from chris-SER8 (asks for your minipc password):

```bash
ssh -t minipc 'sudo mv /etc/ssh/sshd_config.d/60-kit.conf /etc/ssh/sshd_config.d/00-kit.conf && sudo sshd -t && sudo systemctl reload ssh && echo FIXED'
```
You should see: `FIXED` on its own line. The current SSH sessions stay up; only new logins are affected.

Check it, from chris-SER8:

```bash
ssh -o BatchMode=yes -o PubkeyAuthentication=no -v minipc true 2>&1 | grep 'can continue'
```
You should see: `Authentications that can continue: publickey` and nothing else after `publickey`. If `password` still appears, run `ssh -t minipc 'sudo sshd -T | grep -i passwordauthentication'` and read which file sets it.

The kit was fixed the same night: `05-lock-down-ssh.sh` now writes `00-kit.conf` (and removes any old `60-kit.conf`), both in the workspace copy and in `~/setup` on minipc, so a reinstall will not repeat this.

### 0b. IPv6 turned off on the mini PC's LAN port (done 2026-10-16 23:28)

Found while running `20-ollama.sh`: the model download sat on `pulling manifest` for ten minutes. The Ollama service log showed every piece of the file stalling against a Cloudflare host that has IPv6 addresses. The router gives the mini PC an IPv6 address and a default IPv6 route, but IPv6 traffic never gets out, so programs that cannot be told `-4` (Ollama, and potentially Docker image pulls and the Claude Code installer) hang on it. Fix: a netplan drop-in that makes the LAN port IPv4-only. Only IPv6 is affected; <HEAD_IP> and SSH stay as they are.

The file is `/etc/netplan/60-ipv4-only.yaml` on minipc, mode 600, with this content:

```yaml
network:
  version: 2
  ethernets:
    enp45s0:
      dhcp6: false
      accept-ra: false
      link-local: []
```

It was written and applied with one `ssh -t minipc` line that did `sudo tee` of the file, `sudo chmod 600`, `sudo netplan apply`. Check it any time, on minipc:

```bash
ip -6 addr show enp45s0
```
You should see: nothing at all, no `inet6` lines.

```bash
curl -6 -sS -m 5 https://registry.ollama.ai/v2/
```
You should see: `Failed to connect` within a few milliseconds (that is the point: fail fast, fall to IPv4), not a timeout.

To undo it, if the router's IPv6 is ever fixed: `sudo rm /etc/netplan/60-ipv4-only.yaml && sudo netplan apply`. Netplan merges files by interface name, so this drop-in only adds three settings on top of the installer's `00-installer-config.yaml`.

### 1. Router: reserve <HEAD_IP> for the mini PC

The mini PC gets its address from the router by DHCP. Without a reservation the router may hand it a different address after a long power-off, and then `ssh minipc`, the file share and Frigate all stop answering at .50.

The LAN is a TP-Link Deco style mesh on <LAN_IP>/22, so the router app is where this lives. The exact menu names change between app versions, so look for these words:

1. Open the router app on your phone and sign in.
2. Find the advanced network settings. In Deco style apps this is under **More** (or the network name), then **Advanced**.
3. Look for **Address Reservation** (older apps call it **DHCP Server**, then a reservation list).
4. Add a reservation. Either pick the device named `minipc` from the client list, or enter it by hand:
   - MAC address: `<MAC_ADDRESS>` (that is the 1 GbE port, `enp45s0`)
   - IP address: `<HEAD_IP>`
5. Save. Some apps also let you name the device; call it `minipc`.

The reservation takes effect at the next lease renewal. Ask for one now instead of waiting.

On minipc:

```bash
sudo networkctl renew enp45s0
```
You should see: nothing printed. If the SSH session freezes for a few seconds, that is the lease being redone. If it drops, wait a minute and run `ssh minipc` again.

```bash
ip -br -4 addr show enp45s0
```
You should see: `enp45s0 UP <HEAD_IP>/22`. If the address is anything else, the reservation did not take; check the MAC in the router app matches exactly.

### 2. BIOS check

You need the TV (HDMI) and a USB keyboard plugged into the mini PC for this. Nothing here destroys data.

Windows Fast Startup used to skip the keyboard prompt at boot. Windows is gone, so **Del** (BIOS) and **F11** (boot menu) now work on a normal cold boot. If you ever miss the window, hold the power button to shut off, then try again while tapping Del from the moment the MSI logo appears.

1. Power on and tap **Del** at the logo until the BIOS appears. BIOS version is 8.60.
2. Go to **Settings**, then **Advanced**, then **Power Management Setup**.
   - **Restore after AC Power Loss**: set to **Power On**. This is the setting that makes a headless server come back by itself after an outage. MSI's own FAQ lists this path for the Cubi 5 12M.
   - **ErP Ready** (sometimes shown as ErP or deep power saving): set to **Disabled**. When it is enabled the box cannot wake by itself.
   - Any sleep or suspend option on this page: **Disabled**.
3. Go to **Settings**, then **Boot**.
   - **Fast Boot**: **Disabled**. Fast Boot skips USB and keyboard setup, which is what makes the Del and F11 prompts hard to catch.
   - **Boot Option #1**: should read **ubuntu**. If it does not, pick it.
4. Press **F10**, confirm **Yes** to save and exit. The box reboots into Ubuntu.

Then test the one thing that matters. Let the box boot fully, then pull the power cord, wait ten seconds, and plug it back in. The box should start on its own with no button press. About two minutes later, on chris-SER8:

```bash
ssh minipc uptime
```
You should see: a line ending in `up 1 min` or `up 2 min`. If the box stayed off, the Restore setting did not save; go back into the BIOS and check it again.

### 3. Run the remaining kit scripts

The kit is at `~/setup` on minipc. Run each script from chris-SER8's terminal with the `ssh -t` form below so sudo can prompt for your password. Each script prints what it did at the end and stops at the first error. If one stops, read the last few lines, fix the cause, and run the same command again; the scripts are safe to repeat.

#### 3a. Docker (10-docker.sh)

What it does: adds Docker's own apt repository, installs Docker Engine and the Compose plugin, adds you to the docker group, and runs the hello-world container once. Docker's repository already has a directory for Ubuntu 26.04 (resolute), so the CODENAME fallback note inside the script should not be needed.

```bash
ssh -t minipc 'bash ~/setup/10-docker.sh'
```
You should see: apt output, then five lines of the hello-world message starting with `Hello from Docker!`, then `Done. Log out and back in once so the docker group applies to your shell.` The ssh session ends by itself, which is the log-out it asked for.

Verify (a fresh ssh login picks up the docker group):

```bash
ssh minipc 'docker ps'
```
You should see: an empty table with the header `CONTAINER ID   IMAGE   COMMAND ...` and no `permission denied`.

```bash
ssh minipc 'docker compose version'
```
You should see: `Docker Compose version v2.x.x`.

#### 3b. Ollama (20-ollama.sh)

What it does: installs Ollama, makes it listen on all interfaces so chris-SER8 can send it work, opens port 11434 to the LAN only, pulls one model, and asks it to say READY.

**Model choice.** The script's default model is `llama3.1:8b`, which needs about 4.9 GB of memory to run. On today's 8 GB single stick that leaves very little for Ubuntu, Docker and ZFS later, so start with a 3B model and pull the 8B after the RAM upgrade. The script takes the model name as its first argument.

**Realistic speed.** Running a model on a CPU is limited by memory bandwidth, not by the CPU itself. One DDR4-3200 stick moves about 25 GB/s, so an 8B model at the usual 4-bit size reads its whole 4.9 GB for every token and tops out near 5 tokens per second in theory, 3 to 4 in practice. Two sticks in dual channel double the bandwidth: 5 to 8 tokens per second for 8B, and a 14B model becomes usable at 3 to 4. A 3B model runs roughly twice as fast as 8B in both cases. That is fine for summaries, tagging, private questions and small scripts. It is too slow for agentic coding, which is why Claude does that work and this box only hosts the harness (step 3c).

IPv6 must already be off on the LAN port (step 0b) before this script runs, or the model download stalls on `pulling manifest`; the Ollama service fetches the model itself, so the kit's `-4` cannot help it.

```bash
ssh -t minipc 'bash ~/setup/20-ollama.sh llama3.2:3b'
```
You should see: the Ollama installer, `Listen on all interfaces`, a ufw `Rule added` line, a download progress bar for a couple of GB, then a reply containing `READY`, then `Done. From the Zorin PC, point tools at: http://minipc:11434`.

Verify from chris-SER8 that the LAN can reach it:

```bash
curl -4 -s http://<HEAD_IP>:11434/api/tags
```
You should see: a line of JSON that includes `"name":"llama3.2:3b"`. If it hangs, you forgot `-4`. If it says connection refused, run `ssh minipc 'systemctl status ollama'` and read the last lines.

After the RAM upgrade (step 5), pull the bigger model:

```bash
ssh minipc 'ollama pull llama3.1:8b'
```
You should see: a progress bar ending in `success`. Newer small models appear often; `ollama.com/library` is the catalogue, and anything there works with the same `ollama pull` command.

#### 3c. Agent harnesses (30-agents.sh)

What it does: installs Claude Code with its native installer (no Node needed), tries to install OpenCode (optional, keeps going if it fails), and creates the `agent` helper, which opens or re-attaches a tmux session so an agent keeps running after you disconnect.

```bash
ssh -t minipc 'bash ~/setup/30-agents.sh'
```
You should see: the Claude Code installer finish, an OpenCode line (either success or `OpenCode install failed, skipping`, both fine), then `Done. Log out and back in, then: agent ...`.

Sign in to Claude Code once. There is no browser on the mini PC, so the sign-in gives you a web address to open on chris-SER8 and a code to paste back. On chris-SER8:

```bash
ssh minipc
```
You should see: the minipc prompt.

On minipc:

```bash
agent
```
You should see: the screen clears and a green tmux status bar appears along the bottom with `[main]` at the left. You are now inside a session that survives disconnects.

```bash
claude
```
You should see: Claude Code's first-run screen asking you to log in. Pick the subscription (Claude account) option. It prints a long `https://claude.ai/...` address. Select it with the mouse and open it in your browser on chris-SER8, approve, then copy the code it shows and paste it back into the terminal and press Enter. If the paste is rejected, run `claude` again and get a fresh code; codes expire after a few minutes. When it says you are logged in, type `/exit`.

Detach from tmux with **Ctrl-b** then **d**. The prompt comes back; anything running in `agent` keeps going. Type `agent` again later to return to it, and `exit` to leave minipc.

Verify from chris-SER8:

```bash
ssh minipc '~/.local/bin/claude --version'
```
You should see: a version number. (The plain `claude` name works after the next login, once `.bashrc` has added `~/.local/bin` to the PATH.)

### 4. Save the SSH connection in the Claude desktop app

With this saved, a Claude Code session can run on the mini PC itself: reading its files, running its commands, watching its logs, with nothing else to install by hand. The app signs Claude Code in on the mini PC with the account the desktop app is logged into, so like the step 3c sign-in this waits for Austin to be present and to say yes. The desktop app puts Claude Code on the remote machine automatically the first time it connects (it lives under `~/.claude/remote/` on minipc) and it reads the `Host minipc` entry from `~/.ssh/config` on chris-SER8, so the key and user are already known.

1. In the Claude desktop app, open the **Code** tab and start a new session.
2. In the environment picker (where you choose Local or Cloud), choose **SSH**.
3. Choose **Add SSH connection**. Fill in:
   - Name: `minipc`
   - Host: `minipc` (the alias from `~/.ssh/config`; the app resolves it to <HEAD_IP>, user chris, key `~/.ssh/minipc`). If the form insists on separate fields: address `<HEAD_IP>`, port `22`, user `chris`, identity file `/home/chris/.ssh/minipc`.
   - Folder: `/home/chris`
4. Save and connect. The first connection installs Claude Code on minipc, which takes a minute. If it sits for several minutes with no progress, the IPv6 quirk is the likely cause; let it time out and try again, it falls back to IPv4.

Verify: ask the new session to run `hostname`. It should answer `minipc`. From then on, any new session can be started on minipc from the same picker.

### 5. RAM upgrade

Buy one matched kit of **2 x 16 GB DDR4-3200 SO-DIMM** (260 pin, 1.2 V, non-ECC, the laptop size). The Cubi 5 12M has two slots and accepts up to 64 GB. Remove the existing 8 GB stick; mixing it with the new pair would break dual channel and lose the speed gain from step 3b.

Order of work:

1. Power off cleanly. On chris-SER8:

```bash
ssh -t minipc 'sudo poweroff'
```
You should see: `Connection to <HEAD_IP> closed by remote host.` and the box's light goes off within half a minute.

2. **Unplug the power cord.** Then hold the power button for ten seconds to drain the board. Touch the metal case before handling the sticks.
3. Open the bottom cover. The screws are under the rubber feet, or on the bottom plate; the MSI Cubi 5 manual shows which.
4. Remove the 8 GB stick: push the two metal clips at its ends outward at the same time, the stick pops up at an angle, pull it straight out. Keep it in an anti-static bag as a spare.
5. Insert the two new sticks, one per slot: line up the notch, push in at about a 30 degree angle until the gold contacts disappear, then press flat until both clips click.
6. Close the cover, plug in, power on. The first boot after a memory change takes longer (the BIOS retrains memory) and may show the BIOS once; if so, pick the ubuntu entry and press F10 to continue.

Verify. On chris-SER8, about two minutes after power-on:

```bash
ssh minipc 'free -h'
```
You should see: the `Mem:` line with a total near `31Gi`.

```bash
ssh -t minipc 'sudo dmidecode -t memory | grep -E "Size|Configured Memory Speed|Locator|Channel"'
```
You should see: two populated entries each reading `Size: 16 GB` and `Configured Memory Speed: 3200 MT/s`, in different channels.

**Memtest86+, one full pass.** New memory should be tested once before you trust ZFS to it. Memtest86+ 9.00 is on the Ventoy stick, but that stick is currently a plain Ubuntu installer; rebuild it first (Part B, "Rebuilding the Ventoy stick"). Then:

1. Plug the Ventoy stick into the mini PC, with TV and keyboard attached. Power on and tap **F11** at the logo.
2. Pick the USB stick, then in Ventoy's menu pick `mt86plus_9.00_x86_64.iso`, then "Boot in normal mode" if asked.
3. Let it run until the screen shows **Pass 1** complete with **0 errors**. For 32 GB this takes roughly one to three hours. The test loops forever; after the first clean pass press **Esc** to reboot, pull the stick.
4. If Memtest86+ refuses to start with a Secure Boot message, turn Secure Boot off in the BIOS for the test and back on afterwards. Memtest86+ 9.00 is signed, but not by Microsoft.

Any error at all means a bad stick or a bad seat. Reseat both sticks and test again; if it repeats, return the kit.

### 6. Storage: ZFS mirror

**The plan.** Two drives of the same size, mirrored, so either one can die without losing data: one 2.5" SATA drive in the mini PC's empty bay, and one drive in an external enclosure on a USB 3.2 Gen 2 (10 Gbps) port or on the Thunderbolt 4 port. The pool is called `tank`. ZFS checksums every block and repairs from the good copy when a scrub finds damage, which is the point of the mirror.

**Drive notes.**
- 2.5" bay: a 7 mm thick drive fits for sure; a 9.5 mm drive may not, check the Cubi 5 manual. A 2 TB or 4 TB SATA SSD is the quiet choice; 2.5" hard drives above 2 TB are usually SMR, which ZFS dislikes during resilvers.
- External: a single-drive enclosure that supports **UASP**, used as a plain disk (JBOD), never a RAID or "backup" mode enclosure. If it holds a 3.5" drive it needs its own power supply. Plug it straight into the mini PC, not through a hub. USB drives are the weak link in any pool: if one drops out, step 13 says what to do.
- Both drives must be empty or expendable. The pool creation below erases them.

Install ZFS. On minipc:

```bash
sudo apt install -y zfsutils-linux
```
You should see: apt install `zfsutils-linux` (2.4.x) and a few libraries; no errors.

```bash
zfs version
```
You should see: two lines, `zfs-2.4.x` and `zfs-kmod-2.4.x`.

**Identify the drives.** Never use `/dev/sda` style names in a pool; they can swap between boots. Use the stable `/dev/disk/by-id` names, which contain the model and serial number.

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN,TYPE
```
You should see: `nvme0n1` (the 466G Kingston system SSD, leave it alone), plus `sda` and `sdb` with your two new drives, one showing `TRAN sata` and one `usb`. Note each one's SERIAL.

```bash
ls -l /dev/disk/by-id/ | grep -v -- -part
```
You should see: names like `ata-MODEL_SERIAL -> ../../sda` and `usb-VENDOR_MODEL_SERIAL-0:0 -> ../../sdb`. Match the serials to the previous output. Those two names are DRIVE_A and DRIVE_B below. Ignore the `wwn-` and `nvme-` entries.

Check both drives are healthy before trusting them:

```bash
sudo smartctl -H /dev/disk/by-id/DRIVE_A
```
You should see: `SMART overall-health self-assessment test result: PASSED`. Repeat for DRIVE_B. (Some USB enclosures hide SMART; if so the command says it cannot read it, which is annoying but not fatal.)

Confirm the drives hold nothing you want:

```bash
lsblk -f /dev/disk/by-id/DRIVE_A /dev/disk/by-id/DRIVE_B
```
You should see: no `FSTYPE` and no partitions under either drive. If there is an old filesystem on a drive you have decided to reuse, `zpool create` will refuse without `-f`; add `-f` only once you are sure which drive it is.

**Create the pool.**

**WARNING: this erases both drives named in the command. Check DRIVE_A and DRIVE_B twice. The system SSD is nvme0n1 and must not appear here.**

```bash
sudo zpool create -o ashift=12 -O compression=lz4 -O atime=off -O xattr=sa -O acltype=posixacl -m /tank tank mirror /dev/disk/by-id/DRIVE_A /dev/disk/by-id/DRIVE_B
```
You should see: nothing printed. What the options mean: `ashift=12` aligns to 4 KB sectors, right for every modern drive; `compression=lz4` is free speed; `atime=off` stops a write on every read; `xattr=sa` and `acltype=posixacl` store the extended attributes Samba and Docker use efficiently.

```bash
sudo zpool status
```
You should see: `pool: tank`, `state: ONLINE`, a `mirror-0` with both drives `ONLINE`, and `errors: No known data errors`.

**Cap the memory ZFS uses.** ZFS keeps a read cache (ARC) that will happily take half of the RAM. With 8 GB today and 32 GB later, and Docker, Ollama and Frigate wanting memory too, cap it at 4 GB. The setting is in bytes.

```bash
echo 'options zfs zfs_arc_max=4294967296' | sudo tee /etc/modprobe.d/zfs.conf
```
You should see: the same line echoed back.

```bash
sudo update-initramfs -u -k all
```
You should see: `update-initramfs: Generating /boot/initrd.img-...` for each installed kernel. This bakes the setting into early boot so it applies before the pool imports.

Apply it now without rebooting:

```bash
echo 4294967296 | sudo tee /sys/module/zfs/parameters/zfs_arc_max
```
You should see: `4294967296` echoed back.

```bash
grep -E '^c_max' /proc/spl/kstat/zfs/arcstats
```
You should see: `c_max 4 4294967296`. After the next reboot check it once more; it should still read the same.

**Datasets.** One per job, so each can have its own settings, snapshots and quotas later.

```bash
sudo zfs create tank/shares
```
You should see: nothing printed. Same for the next three.

```bash
sudo zfs create tank/backups
```
You should see: nothing printed.

```bash
sudo zfs create -o recordsize=1M tank/frigate
```
You should see: nothing printed. (1 MB records suit large video files.)

```bash
sudo zfs create tank/docker
```
You should see: nothing printed.

```bash
sudo chown -R chris:chris /tank/shares /tank/backups /tank/frigate /tank/docker
```
You should see: nothing printed.

```bash
zfs list
```
You should see: `tank`, `tank/backups`, `tank/docker`, `tank/frigate`, `tank/shares`, each mounted at `/tank/...`, with `AVAIL` near the size of one drive.

About `tank/docker`: keep Docker's own data (images, layers) on the fast system SSD where it is. Use `/tank/docker` for the folders of your Compose projects and the data they bind-mount, so the big and precious bits live on the mirror. Moving Docker's data-root onto ZFS is possible but adds a storage-driver decision that is easy to get wrong; skip it unless the SSD fills up.

**Monthly scrub.** A scrub reads every block and fixes anything that fails its checksum. Ubuntu ships two ways to schedule it: a cron job in `/etc/cron.d/zfsutils-linux` that scrubs on the second Sunday of each month, and per-pool systemd timers. Use the timer, which shows up in `systemctl list-timers`, and tell the cron job to leave this pool alone so it does not scrub twice.

```bash
sudo systemctl enable --now zfs-scrub-monthly@tank.timer
```
You should see: `Created symlink ...zfs-scrub-monthly@tank.timer ...`.

```bash
sudo zfs set org.debian:periodic-scrub=disable tank
```
You should see: nothing printed.

```bash
systemctl list-timers --all | grep zfs
```
You should see: a line for `zfs-scrub-monthly@tank.timer` with a NEXT date in the coming month.

Run the first scrub now so you know what a healthy one looks like (fast on an empty pool):

```bash
sudo zpool scrub tank
```
You should see: nothing printed.

```bash
sudo zpool status
```
You should see: in the `scan:` line, `scrub repaired 0B in ... with 0 errors on DATE`. After every monthly scrub this line is the thing to look at.

Finally, reboot once and confirm the pool comes back by itself:

```bash
sudo reboot
```
You should see: the connection drop. Two minutes later `ssh minipc 'zfs list'` shows the five datasets mounted and `ssh minipc 'sudo zpool status'` shows ONLINE.

### 7. Samba: the file share

Samba makes `/tank/shares` appear as a network folder on Zorin, Windows and phones. The user is `chris` with a separate Samba password (it can match your login password, but Samba keeps its own copy).

On minipc:

```bash
sudo apt install -y samba
```
You should see: apt install `samba` (4.23.x) and helpers, and the `smbd` service start.

Add the share. Open the config:

```bash
sudo nano /etc/samba/smb.conf
```
You should see: the stock config. Use Ctrl-End to jump to the bottom and paste this block, then Ctrl-O, Enter, Ctrl-X to save:

```ini
[shares]
   comment = Mini PC shared storage
   path = /tank/shares
   valid users = chris
   read only = no
   browseable = yes
   create mask = 0664
   directory mask = 0775
```

Key by key: `path` is the ZFS dataset; `valid users` means only chris may connect (add more names separated by spaces later); `read only = no` allows writing; `browseable = yes` lists it when someone browses the server; the two masks give new files group read access.

```bash
testparm -s
```
You should see: `Loaded services file OK.` followed by a dump of the config including your `[shares]` block. Any `Unknown parameter` line means a typo.

```bash
sudo smbpasswd -a chris
```
You should see: `New SMB password:` and `Retype new SMB password:` prompts, then `Added user chris.`

```bash
sudo systemctl restart smbd
```
You should see: nothing printed.

```bash
sudo ufw allow from <LAN_IP>/22 to any app Samba
```
You should see: `Rule added`. The `Samba` app profile opens 445/tcp plus the older 137 to 139 ports, and the `from` part limits all of them to the home LAN.

```bash
sudo ufw status
```
You should see: a `Samba` line with `ALLOW IN` from `<LAN_IP>/22` among the rules, and still no rule open to `Anywhere` except 22.

**Mount from Zorin, the easy way.** On chris-SER8 open **Files**, click **Other Locations** at the bottom of the sidebar, and in the **Connect to Server** box at the bottom type `smb://<HEAD_IP>/shares` and press Connect. Log in as Registered User, username `chris`, domain can stay `WORKGROUP`, the Samba password, and tick **Remember forever**. The share appears in the sidebar; right-click it for Add Bookmark. (The name `minipc` works too if the router resolves it, the address always works.)

**Mount from Zorin at boot (optional, for scripts and apps that need a real path).** On chris-SER8:

```bash
sudo apt install -y cifs-utils
```
You should see: apt install `cifs-utils`.

```bash
nano ~/.smbcredentials
```
Put two lines in it, then save:

```text
username=chris
password=YOUR_SAMBA_PASSWORD
```

```bash
chmod 600 ~/.smbcredentials
```
You should see: nothing printed. Only you can read the file now.

```bash
sudo mkdir -p /mnt/minipc
```
You should see: nothing printed.

```bash
sudo nano /etc/fstab
```
Add this single line at the bottom (it is one line, even if it wraps here):

```text
//<HEAD_IP>/shares  /mnt/minipc  cifs  credentials=/home/chris/.smbcredentials,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount  0  0
```

`nofail` and `_netdev` stop Zorin from hanging at boot when the mini PC is off, and `x-systemd.automount` mounts the share the first time something looks at the folder.

```bash
sudo systemctl daemon-reload
```
You should see: nothing printed.

```bash
sudo mount /mnt/minipc
```
You should see: nothing printed.

```bash
ls /mnt/minipc
```
You should see: the contents of `/tank/shares` (empty at first). Create a test file from one side and look for it from the other.

**Windows.** In File Explorer's address bar type `\\<HEAD_IP>\shares` and press Enter; log in as `chris`. To make it a drive letter, right-click **This PC**, **Map network drive**, same path, tick **Reconnect at sign-in**.

**Phone.** iPhone: the **Files** app, the three dots, **Connect to Server**, `smb://<HEAD_IP>`, user `chris`. Android: a file manager with SMB support (Cx File Explorer, Solid Explorer and Material Files all have it): add a network location, type SMB, host `<HEAD_IP>`, share `shares`, user `chris`. Phones only reach it at home, or over Tailscale (step 9) when away.

### 8. Frigate, then move it onto the pool

The kit's `40-frigate.sh` sets Frigate up at `/srv/frigate` on the system SSD, because the pool did not exist when the kit was written. Run it as written, confirm it works, then move the folder to `/tank/frigate` so recordings go to the mirror.

What the script does: makes the folders, copies the Compose file and config (with one example camera that is disabled), writes `.env` with a random camera password, exports the YOLOv9-t detection model with Docker (one time, a few minutes of downloads), opens the Frigate ports to the LAN only, and starts the container. It refuses to run if Docker is missing and warns if `/dev/dri/renderD128` (the Intel iGPU) is missing.

Note from 2026-10-16: the first run stopped right after `Config files` with exit code 141. The random-password line was cut off by `head` and the kit's strict mode treated that as a failure. The kit was fixed the same night (both copies). If an old copy ever stops there, delete `/srv/frigate/.env` (it holds a placeholder password at that point) and run the script again.

On chris-SER8:

```bash
ssh -t minipc 'bash ~/setup/40-frigate.sh'
```
You should see: `Folders at /srv/frigate`, `Config files`, a long Docker build for the model ending in `Model ready.`, three ufw `Rule added` lines, `docker compose pull` and `up -d` output, 40 lines of Frigate log, and finally `Frigate UI: https://<HEAD_IP>:8971`.

Open `https://<HEAD_IP>:8971` in a browser on chris-SER8 and accept the self-signed certificate warning once. Frigate is a web page, so it can be watched from any monitor, including the TV once it is a third monitor (step 12): drag the browser window there, or in Chrome or Brave use Install as app so Frigate opens in its own window that remembers which monitor it was on. The first login is user `admin` and a one-time password printed in the log. Get it with:

```bash
ssh minipc 'docker compose -f /srv/frigate/docker-compose.yml logs frigate | grep -i password'
```
You should see: a line with `Password:` followed by the generated password. Log in, then change it under the user menu. The UI shows no cameras yet, which is expected.

**Move it to the pool.** Only after the UI has opened once.

On minipc:

```bash
cd /srv/frigate && docker compose down
```
You should see: `Container frigate  Stopped` and `Removed`.

```bash
rsync -aHAX --info=progress2 /srv/frigate/ /tank/frigate/
```
You should see: a progress line ending at 100%. The trailing slashes matter: they copy the contents, not the folder itself. The model file in `config/model_cache` is the biggest piece. If the reply is `rsync: command not found`, run `sudo apt install -y rsync` first.

```bash
sed -i 's|^FRIGATE_DIR=.*|FRIGATE_DIR=/tank/frigate|' /tank/frigate/.env
```
You should see: nothing printed.

```bash
grep FRIGATE_DIR /tank/frigate/.env
```
You should see: `FRIGATE_DIR=/tank/frigate`.

```bash
cd /tank/frigate && docker compose up -d
```
You should see: `Container frigate  Started`.

```bash
cd /tank/frigate && docker compose logs --tail 40 frigate
```
You should see: the normal start-up log with no `Permission denied` lines and the detector reporting it loaded the model.

Verify in the UI at `https://<HEAD_IP>:8971`: log in, open **Settings**, then **System metrics** (or the storage section), and confirm the recordings storage shows the pool's free space (terabytes, not the 400-odd GB of the SSD). From now on Compose commands for Frigate run from `/tank/frigate`.

Keep `/srv/frigate` for a week in case something looks off. Then:

**WARNING: this deletes the old copy. Only after the UI has worked from /tank/frigate.**

```bash
sudo rm -rf /srv/frigate
```
You should see: nothing printed.

### 9. Cockpit and Tailscale

**Cockpit** is a web page for the server: CPU, memory, disks, services, logs, a terminal, all in a browser. Handy when something is wrong and you do not want to remember commands. It uses your normal minipc password (not SSH keys), so keep it LAN-only.

On minipc:

```bash
sudo apt install -y cockpit
```
You should see: apt install `cockpit` (360) with its `cockpit-system`, `cockpit-storaged`, `cockpit-packagekit` companions. The Cockpit project recommends the backports version where one exists (`sudo apt install -t resolute-backports cockpit`); on a fresh 26.04 the plain install is current enough.

```bash
sudo systemctl enable --now cockpit.socket
```
You should see: nothing, or `Created symlink` if it was not already enabled. Cockpit only starts when someone connects.

```bash
sudo ufw allow from <LAN_IP>/22 to any port 9090 proto tcp comment 'cockpit LAN'
```
You should see: `Rule added`.

Open `https://<HEAD_IP>:9090` on chris-SER8, accept the certificate warning, and log in as `chris` with the minipc password. The Overview page shows load, memory and disks. A **Limited access** button at the top right switches to administrative access when you need to change something. The Networking page shows little because Ubuntu Server manages the network with networkd rather than NetworkManager; that is normal.

**Tailscale** gives the mini PC a private address that works from anywhere (phone on mobile data, a laptop away from home) without opening any port on the router. Both ends need Tailscale, signed into the same account.

On minipc:

```bash
curl -4 -fsSL https://tailscale.com/install.sh | sh
```
You should see: the script detect `ubuntu resolute`, add Tailscale's repository and install the `tailscale` package, ending with `Installation complete! Log in to start using Tailscale by running: sudo tailscale up`. (The script checks pkgs.tailscale.com for the codename; resolute is listed there as of 2026-10-16.)

```bash
sudo tailscale up
```
You should see: `To authenticate, visit: https://login.tailscale.com/a/...`. Open that address on chris-SER8, sign in (Google, Apple, Microsoft or GitHub account; pick one and stick with it), approve the machine. The terminal then prints `Success.`

```bash
tailscale ip -4
```
You should see: an address starting with `100.`.

Then two things in the Tailscale admin console at `login.tailscale.com/admin`:
- **DNS**: turn on **MagicDNS** if it is not already. The mini PC's name becomes `minipc.TAILNET-NAME.ts.net` (the tailnet name is shown on the same page).
- **Machines**: on the minipc row, open the menu and choose **Disable key expiry**. Servers should not need a re-login every few months.

Let SSH in over Tailscale. ufw blocks the Tailscale interface like any other, so allow port 22 on it:

```bash
sudo ufw allow in on tailscale0 to any port 22 proto tcp comment 'ssh over tailscale'
```
You should see: `Rule added`.

Install Tailscale on chris-SER8 the same way (`curl -4 -fsSL https://tailscale.com/install.sh | sh`, then `sudo tailscale up`) and on your phone from its app store. Then from anywhere, on chris-SER8:

```bash
ssh -i ~/.ssh/minipc chris@minipc.TAILNET-NAME.ts.net
```
You should see: the minipc prompt, even when chris-SER8 is on another network. To make `ssh minipc` itself work from away, change `HostName` in the `Host minipc` block of `~/.ssh/config` to the ts.net name; Tailscale routes it over the LAN when you are home anyway.

Cockpit over Tailscale works too if you add `sudo ufw allow in on tailscale0 to any port 9090 proto tcp`. Frigate's UI likewise with port 8971.

### 10. Backups

**A mirror is not a backup.** The ZFS mirror protects against one drive dying. It does nothing against deleting the wrong folder (the deletion is mirrored instantly), ransomware, a power supply that fries both drives, fire, or theft. A backup is a separate copy, somewhere else, with history. The tool here is **restic**: it encrypts, deduplicates, keeps snapshots you can browse, and restores single files.

Two targets, pick one or do both:
- **A second drive** that is not part of the mirror. A USB drive left plugged in gives automatic nightly backups but burns in the same fire. A drive you plug in weekly and keep in a drawer is safer and the timer below simply skips the nights it is absent.
- **Backblaze B2**, cloud storage priced per GB per month, through its S3-compatible interface (the way restic recommends). Good for what you cannot replace: documents, photos, configs. Not for Frigate recordings, which are large and replaceable.

What to back up: `/tank/shares` (your files), `/home/chris` and `/etc` on the system SSD (your settings and the kit copy), and Frigate's settings: the `config` folder, `.env` (it holds the camera password) and `docker-compose.yml` under `/tank/frigate`. Not `/tank/frigate/media`, which is the video.

On minipc:

```bash
sudo apt install -y restic
```
You should see: apt install `restic` (0.18.x).

```bash
sudo mkdir -p /etc/restic && sudo chmod 700 /etc/restic
```
You should see: nothing printed.

Create the password file. This password encrypts the backups; without it they are unreadable, so store it in your password manager too.

```bash
sudo nano /etc/restic/password
```
Type one long passphrase on a single line, save.

```bash
sudo chmod 600 /etc/restic/password
```
You should see: nothing printed.

Now the settings file, which tells restic where the repository is.

```bash
sudo nano /etc/restic/env
```

For a **second drive** mounted at `/mnt/backupdrive` (mount it first; a plain ext4 drive is fine):

```text
RESTIC_REPOSITORY=/mnt/backupdrive/restic
RESTIC_PASSWORD_FILE=/etc/restic/password
```

For **Backblaze B2**: in the B2 web console create a private bucket (say `minipc-backup`), then create an Application Key limited to that bucket. The bucket's details page shows its **Endpoint**, something like `s3.us-west-004.backblazeb2.com`; the region part differs per account. The key ID and key become the two AWS variables (restic speaks S3 to B2):

```text
RESTIC_REPOSITORY=s3:s3.REGION.backblazeb2.com/BUCKET_NAME
RESTIC_PASSWORD_FILE=/etc/restic/password
AWS_ACCESS_KEY_ID=YOUR_KEY_ID
AWS_SECRET_ACCESS_KEY=YOUR_APPLICATION_KEY
```

```bash
sudo chmod 600 /etc/restic/env
```
You should see: nothing printed.

Initialise the repository (once per target):

```bash
sudo bash -c 'set -a && . /etc/restic/env && restic init'
```
You should see: `created restic repository XXXXXXXX at ...` and a reminder that losing the password means losing the data.

The backup script:

```bash
sudo nano /usr/local/bin/restic-backup
```
Paste:

```text
#!/usr/bin/env bash
set -euo pipefail
set -a; . /etc/restic/env; set +a
restic backup --one-file-system \
  /tank/shares /home/chris /etc \
  /tank/frigate/config /tank/frigate/.env /tank/frigate/docker-compose.yml
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
```

`forget --prune` keeps 7 daily, 4 weekly and 6 monthly snapshots and frees what is older. Save, then:

```bash
sudo chmod 755 /usr/local/bin/restic-backup
```
You should see: nothing printed.

Run it once by hand so the first (slow, full) backup happens while you watch:

```bash
sudo /usr/local/bin/restic-backup
```
You should see: a file count, `Added to the repository: N GiB`, `snapshot XXXXXXXX saved`, then the forget output. The first run takes as long as your data is big; later runs send only changes.

Make it nightly. The service:

```bash
sudo nano /etc/systemd/system/restic-backup.service
```

```ini
[Unit]
Description=restic backup
After=network-online.target zfs.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/restic-backup
Nice=10
IOSchedulingClass=idle
```

The timer:

```bash
sudo nano /etc/systemd/system/restic-backup.timer
```

```ini
[Unit]
Description=nightly restic backup

[Timer]
OnCalendar=*-*-* 03:30:00
RandomizedDelaySec=15m
Persistent=true

[Install]
WantedBy=timers.target
```

`Persistent=true` runs a missed backup at the next boot if the box was off at 03:30.

```bash
sudo systemctl daemon-reload
```
You should see: nothing printed.

```bash
sudo systemctl enable --now restic-backup.timer
```
You should see: `Created symlink ...restic-backup.timer ...`.

```bash
systemctl list-timers | grep restic
```
You should see: `restic-backup.timer` with NEXT at the coming 03:30 (plus up to 15 minutes).

After the first night, check it ran:

```bash
journalctl -u restic-backup.service -n 20 --no-pager
```
You should see: `snapshot ... saved` and `Finished restic backup`.

**Restore test.** A backup that has never been restored is a hope, not a backup. Put a file in the share, back it up, then pull it back out somewhere else:

```bash
echo "restore test $(date)" > /tank/shares/restore-test.txt
```
You should see: nothing printed.

```bash
sudo /usr/local/bin/restic-backup
```
You should see: `snapshot ... saved`.

```bash
sudo bash -c 'set -a && . /etc/restic/env && restic restore latest --target /tmp/restore-test --include /tank/shares/restore-test.txt'
```
You should see: `restoring snapshot ... to /tmp/restore-test` and `Summary: Restored 1 files`.

```bash
cat /tmp/restore-test/tank/shares/restore-test.txt
```
You should see: the `restore test` line with the date you wrote. That is a working backup. Repeat this test twice a year, and after any change to the script.

To find and restore something later: `restic snapshots` lists what exists, `restic ls latest /tank/shares` browses one, and `restic restore SNAPSHOT_ID --target /tmp/x --include /path/to/file` brings a file back (always run them with the same `sudo bash -c 'set -a && . /etc/restic/env && ...'` wrapper so restic finds the repository and password).

### 11. Cameras, when they arrive

**The layout.** PoE cameras plug into a PoE switch. The switch's uplink goes to the mini PC's 2.5 GbE port `enp46s0` (MAC `<MAC_ADDRESS>`) and to nothing else. That makes the cameras their own little network: Frigate on the mini PC can see them, nothing else on the LAN can, and the cameras have no path to the internet, so whatever phone-home habits they have go nowhere. The mini PC does not forward traffic between its two ports, which is the default, and ufw's default is to deny what comes in.

**11a. Give enp46s0 a fixed address.** Pick a range that is not the home LAN; `10.10.10.0/24` is used here.

On minipc:

```bash
sudo nano /etc/netplan/60-cameras.yaml
```

```yaml
network:
  version: 2
  ethernets:
    enp46s0:
      dhcp4: false
      dhcp6: false
      optional: true
      addresses: [10.10.10.1/24]
```

No `gateway` or `routes` line on purpose. `optional: true` means boot does not wait for this port to come up.

```bash
sudo chmod 600 /etc/netplan/60-cameras.yaml
```
You should see: nothing printed (netplan complains about world-readable files otherwise).

```bash
sudo netplan apply
```
You should see: nothing, or a harmless warning about the file. Your SSH session on enp45s0 is unaffected.

```bash
ip -br -4 addr show enp46s0
```
You should see: `enp46s0 UP 10.10.10.1/24` once the switch is connected (`DOWN` with the address until a cable is in).

```bash
sysctl net.ipv4.ip_forward
```
You should see: `net.ipv4.ip_forward = 0`. That zero is what keeps the camera network isolated. Do not change it.

**11b. Hand out addresses to the cameras.** Cameras expect a DHCP server. Run a tiny one on this port only, with no gateway and no DNS in the lease, so the cameras get an address and nothing more.

```bash
sudo apt install -y dnsmasq
```
You should see: apt install `dnsmasq`. It may fail to start right away because systemd-resolved owns port 53; the config below turns dnsmasq's DNS off so that goes away.

```bash
sudo nano /etc/dnsmasq.d/cameras.conf
```

```text
interface=enp46s0
bind-interfaces
port=0
dhcp-range=10.10.10.100,10.10.10.199,12h
dhcp-option=3
dhcp-option=6
# Fixed addresses once you know each camera's MAC (see the leases file):
# dhcp-host=<MAC_ADDRESS>,10.10.10.11,front_door
```

`port=0` disables DNS entirely (it is only here for DHCP); `dhcp-option=3` and `=6` with no value tell dnsmasq to send no router and no DNS server, so the cameras have no route out.

```bash
sudo systemctl restart dnsmasq
```
You should see: nothing printed.

```bash
sudo ufw allow in on enp46s0 to any port 67 proto udp comment 'camera dhcp'
```
You should see: `Rule added`. DHCP requests are the one thing cameras need to send to the server.

Plug the PoE switch into enp46s0 and the first camera into the switch. After a minute:

```bash
cat /var/lib/misc/dnsmasq.leases
```
You should see: one line per camera: a timestamp, the MAC, the address it got (10.10.10.1xx) and a name. Copy each MAC into a `dhcp-host` line in `cameras.conf` with a fixed address (10.10.10.11, .12, ...) and restart dnsmasq, so the addresses never move.

**11c. Set up each camera.** The camera's own web page is at its 10.10.10.x address, which chris-SER8 cannot reach directly (different network, by design). Tunnel to it through the mini PC instead. On chris-SER8, with the camera at 10.10.10.11:

```bash
ssh -L 8080:10.10.10.11:80 minipc
```
You should see: the minipc prompt. While this stays open, `http://localhost:8080` in a browser on chris-SER8 is that camera's page. (Some cameras use https on 443; change the 80.)

In the camera's page: set a strong admin password, turn off cloud/P2P features and UPnP, set the time zone, and create a second user called `viewer` with the camera password Frigate already generated:

```bash
grep FRIGATE_RTSP_PASSWORD /tank/frigate/.env
```
You should see: `FRIGATE_RTSP_PASSWORD=` followed by 20 letters and digits. Use exactly that as the `viewer` password on every camera. Frigate substitutes it into the stream addresses, so the config file never holds the password in clear.

Note the camera's RTSP paths. The kit's `config.yml` lists the common ones at the bottom (Reolink, Amcrest/Dahua, Hikvision); otherwise the camera manual or its web page has them. You want two streams: the full-resolution main stream for recording, and a low-resolution sub stream (1280x720 or smaller) for detection, which saves most of the CPU.

**11d. Add the camera to Frigate.** Edit the config on minipc:

```bash
nano /tank/frigate/config/config.yml
```

Find the `cameras:` section with the example `front_door`. Copy the whole block once per camera, give each a name (letters and underscores), set `enabled: true`, replace `CAMERA_IP` with the fixed address and `MAIN_STREAM_PATH` and `SUB_STREAM_PATH` with the real paths. Keep the `detect` width and height matching the sub stream, and `fps: 5` is plenty. Save.

```bash
cd /tank/frigate && docker compose restart
```
You should see: `Container frigate  Started`.

```bash
cd /tank/frigate && docker compose logs --tail 60 frigate
```
You should see: the camera's name followed by stream information and no repeating `Unable to read frames` or `authentication failed` errors. The UI at `https://<HEAD_IP>:8971` now shows a live tile for the camera; walk in front of it and a `person` box should appear within a second or two.

**11e. Shared memory.** Frigate keeps the detection frames in the container's shared memory (`shm_size` in `docker-compose.yml`, set to 512 MB by the kit). Frigate's own sizing rule is, per camera, `(width x height x 1.5 + 270480) / 1048576 x 25` MB, plus about 50 MB for logs. A 1280x720 detect stream comes to about 40 MB, so 512 MB covers ten such cameras with room to spare. If the log ever says shm is low or Frigate exits with `Bus error`, raise `shm_size` in the Compose file and run `docker compose up -d`.

**11f. Coral USB, the detector upgrade.** The iGPU with OpenVINO handles a few cameras well. If you add many cameras or the UI's System page shows detector inference times above 50 ms, a Google Coral USB Accelerator (when you can find one at a sane price) brings that to about 10 ms and frees the iGPU for decoding. Plug it into one of the mini PC's blue USB 3.2 ports, then on minipc:

1. In `/tank/frigate/docker-compose.yml`, under `devices:`, add the line `- /dev/bus/usb:/dev/bus/usb`.
2. In `/tank/frigate/config/config.yml`, replace the `detectors:` block with:

```yaml
detectors:
  coral:
    type: edgetpu
    device: usb
```

3. Remove or comment out the whole `model:` block. The Coral uses Frigate's built-in model; the YOLOv9 ONNX file is for OpenVINO only.
4. `cd /tank/frigate && docker compose up -d`, then check the log for `TPU found` and the System page for the new inference time.

### 12. The wall TV: third monitor through the mini PC, volume, inputs, remote

What Chris wants (said 2026-10-16): open any window on chris-SER8, a browser or anything else, and move it onto the big TV as if the TV were a third monitor, with the TV plugged into the mini PC. Also control the TV's volume and inputs from this computer, and keep the TV remote useful.

Facts checked on chris-SER8 the same night: Zorin OS 18.1 (Ubuntu 24.04 base), GNOME 46 running on X11 (not Wayland), AMD Radeon 780M graphics with a hardware video encoder, Flatpak 1.14 installed. The two monitors are both 1920x1080, one on the HDMI port and one on the DisplayPort. The USB4 (USB-C) ports are free, and they carry video.

**Two ways to get the third monitor.**

*Option A: a cable.* A USB-C to HDMI cable from a free USB4 port on chris-SER8 straight to the TV. A true third monitor with zero lag and nothing to install. In Zorin: Settings, Displays, drag the TV to where it sits, Join Displays. Chris wants the mouse to treat the TV as sitting above the second monitor: in that Displays screen drag the TV's rectangle so it sits on top of monitor 2's rectangle, then Apply, and the pointer leaves the top edge of monitor 2 onto the TV. The same arrangement step applies to Option B, where the dummy-plug display is the TV's stand-in. This is the better answer whenever the cable can reach (HDMI is fine to about 5 m, longer with an active cable).

*Option B: through the mini PC.* The TV stays on the mini PC. Three pieces, all open source:

1. **A third display on chris-SER8 that nothing is plugged into.** The GPU only draws a monitor it believes exists. The dependable way is a USB-C display emulator (a "dummy plug", about 10 dollars) in a USB4 port; GNOME then shows a third 1920x1080 monitor you can arrange like any other. Software-only tricks exist (forcing a connector on with a fake EDID through kernel parameters) but they are fiddly and break on updates.
2. **Sunshine on chris-SER8** streams that display, and optionally the sound, over the LAN, using the 780M's hardware encoder. Install with Flatpak (`dev.lizardbyte.app.Sunshine`), set a username and password in its web page at `https://localhost:47990`, and point it at the dummy display's name (the `xrandr` name, something like `DisplayPort-1`) so it streams only that screen. 1080p at 60 frames per second needs about 20 Mbit/s; the 1 GbE link has fifty times that.
3. **Moonlight on the mini PC**, full screen on the TV, decoding with the Intel iGPU. The mini PC has no desktop, so Moonlight runs inside `cage`, a one-window Wayland kiosk that starts straight from the console: `sudo apt install flatpak cage`, add Flathub, `flatpak install flathub com.moonlight_stream.Moonlight`, then an autologin for chris on tty1 whose `.bash_profile` runs `cage -- flatpak run com.moonlight_stream.Moonlight` on that console only. Pair once (Moonlight shows a PIN, you type it into Sunshine's web page), pick chris-SER8, pick Desktop, set 1080p 60 fps and hardware decoding. Recovery stays possible: tty2 (Ctrl-Alt-F2 on the mini PC's keyboard) is still a normal login.

What it feels like: a monitor with one or two frames of delay (20 to 40 ms on the wired LAN). Fine for browsers, documents, video, dashboards and music. Slightly soft for fast mouse work and not for games. Whatever you type on the mini PC's keyboard, or send through the TV remote (below), goes back to chris-SER8 through Moonlight, so the window on the TV can be driven from the couch.

Why not other tools: GNOME's own "Network Displays" casting needs a Wayland session and a Miracast TV, and chris-SER8 runs X11. Deskreen streams to a browser with more delay and still needs the dummy plug. VNC and RDP show a whole desktop, not a third monitor.

*Option C, for later: the mini PC runs its own programs on the TV.* Chris raised this on 2026-10-17: let the mini PC use its own processing power instead of this PC's. That means a desktop installed on the mini PC, shown on the TV, with the mouse and keyboard shared from chris-SER8 by a software KVM (Input Leap, the open-source Synergy: the pointer slides off monitor 2 onto the TV and now drives the mini PC; clipboard is shared). A browser opened there uses the mini PC's CPU and memory. The trade: those windows live on the mini PC, so they cannot be dragged to and from this PC's monitors. Not a good fit on 8 GB with Frigate and Ollama running; sensible after the 32 GB upgrade. Options B and C can coexist, switching what the TV shows. Decision 2026-10-17: build Option B now, revisit C after the RAM arrives.

Decision 2026-10-17 (Chris): a cable cannot reach, so Option B it is. The TV stays plugged into the mini PC, which acts as a passthrough.

**Update 2026-10-23 (Chris: do it without the mini PC). Option D, casting, tested and working.** The TV is an LG C1 with Screen Share (Miracast), and chris-SER8's Intel AX200 Wi-Fi card does Wi-Fi Direct. GNOME Network Displays (already installed as a Flatpak) streams one of this PC's monitors to the TV over a direct Wi-Fi link, with no cable, no mini PC and nothing to buy. Verified 2026-10-23 at 19:17: the Samsung monitor mirrored to the TV and stayed up.

*How to cast (two minutes):*

1. Start the app, one copy only:

```bash
flatpak run org.gnome.NetworkDisplays
```
You should see: a "Share Screen" box from GNOME. Click the **Entire Screen** tab, then the tile of the monitor to send (BenQ or Samsung), then **Share**. Do NOT pick **Virtual Monitor** on this PC: on the X11 desktop it produces an empty stream that dies at once and the TV says "screen sharing has stopped".

2. The Network Displays window lists **[LG] webOS TV OLED48C1PUB** (the TV is always discoverable; Screen Share does not have to be open). Click it. The TV asks to allow the connection the first time: press Accept on the TV remote.
3. The TV shows the chosen monitor about a quarter of a second behind. If the TV jumps to HDMI 1 instead, press Home on the TV remote and open **Screen Share**; the picture is waiting there.
4. To stop: close the Network Displays window, or:

```bash
flatpak kill org.gnome.NetworkDisplays
```
You should see: nothing printed; the TV returns to its home screen. Never stop it with a process sweep by name (`pkill -f`), which can kill the terminal running the sweep.

*What it is and is not:* a mirror of one existing monitor, good for video, dashboards and showing someone a window; not a third desktop yet.

*Three ways to a true third screen, cheapest first:*

- **Log in to Wayland** (free, reversible). At the login screen click the gear and pick "Zorin on Wayland". GNOME on Wayland can create the Virtual Monitor the picker offers, and casting that gives a real third screen. Test the TV Remote widget there once: it places itself on the desktop layer with X11 hints and may need the "normal window" layer setting on Wayland.
- **Force an output on in the kernel** (free, needs sudo and a reboot). Add `video=DP-2:1920x1080@60e` to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`, `sudo update-grub`, reboot. The graphics driver then drives an invisible monitor on that connector that Settings, Displays can arrange and the cast can send. Careful with names: the desktop calls the connector DisplayPort-1 but the kernel calls the same socket DP-2 (the kernel counts from 1, the desktop from 0); `ls /sys/class/drm/` lists the kernel names. THIS IS THE ROUTE THAT WORKED, see "Option D2" below.
- **A USB-C display emulator** (about 10 dollars), as in the Option B shopping list, in the free USB4 port.

*Firewall:* ufw is on and the cast worked. The TV joins a small network the PC creates (10.42.0.0/24) and connects back to the PC; if a future cast dies right after Accept, these two rules are the fix:

```bash
sudo ufw allow in proto udp to any port 67 comment 'wifi direct: TV asks for an address'
```

```bash
sudo ufw allow from 10.42.0.0/24 comment 'wifi direct: the TV on the cast link'
```

**Option D2, done 2026-10-23 at 19:49: a real third screen with nothing plugged in.** The TV screen is a GNOME monitor sitting above the left BenQ; the mouse rolls up off the BenQ onto it, windows drag there, and the cast sends that screen to the TV. Four steps; the first needs your password and lasts until the next reboot (the kernel line above makes it permanent).

1. Tell the graphics driver the empty DisplayPort socket has a monitor on it:

```bash
echo on | sudo tee /sys/class/drm/card1-DP-2/status
```
You should see: `on`. GNOME notices within a second and adds a 640x480 monitor called DisplayPort-1 (it has no identity data, so the picker later calls it "Unknown Display").

2. Give it a proper 1920x1080 mode (the kernel only offers 640x480 to a monitor it cannot read):

```bash
xrandr --newmode 1920x1080_60.00 173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync
```
You should see: nothing printed.

```bash
xrandr --addmode DisplayPort-1 1920x1080_60.00
```
You should see: nothing printed.

3. Arrange the three screens: TV top left, BenQ under it, Samsung to the right with the same offset as before:

```bash
xrandr --fb 3840x2384 --output DisplayPort-1 --mode 1920x1080_60.00 --pos 0x0 --output DisplayPort-0 --mode 1920x1080 --pos 0x1080 --output HDMI-A-0 --primary --mode 1920x1080 --pos 1920x1304
```
You should see: nothing printed; the desktop may blink once.

```bash
xrandr --listmonitors
```
You should see: `Monitors: 3` with DisplayPort-1 at `+0+0`, DisplayPort-0 at `+0+1080` and HDMI-A-0 at `+1920+1304`. Settings, Displays shows the same three and can rearrange them.

4. Cast that screen. Start Network Displays with the software video encoder (found 2026-10-23 at 20:00: with the AMD hardware encoder the TV got one frame and then froze; with x264 the picture is live):

```bash
NETWORK_DISPLAYS_H264_ENC=x264enc flatpak run org.gnome.NetworkDisplays
```
You should see: the Share Screen box. Choose **Entire Screen**, then the **Unknown Display** tile, then Share, then click the TV. The TV shows the third desktop; drag a window up there.

5. A cursor on the TV. On the X11 desktop the capture leaves the mouse pointer out, so the pointer is on the TV but invisible. The helper `Mini PC Server/tv-cursor/tv-cursor.py` draws one that follows the pointer while it is on that screen:

```bash
python3 "/home/chris/Desktop/Chris's Greatness/Mini PC Server/tv-cursor/tv-cursor.py" 0 0 1920 1080
```
You should see: nothing printed; it keeps running (`--stop` ends it). The four numbers are the cast screen's position and size.

*Is the mini PC route better?* Yes, for a daily third monitor. Sunshine on this PC to Moonlight on the mini PC runs over the wired LAN at 20 to 40 ms of delay, 60 frames, with the cursor and sound handled by Sunshine, and the hardware encoder works there. The Wi-Fi Direct cast is about a quarter second behind, uses one CPU core for x264, and shares the Wi-Fi card with the home network: fine for video, dashboards and reading, tiring for mouse work. Both need the same third screen from steps 1 to 3 above. Keep the cast as the fallback for when the mini PC is off.

After any layout change the TV Remote widget may jump onto the new screen; start TV Remote again from the app menu and it returns to the Samsung. To undo everything until the reboot: `xrandr --output DisplayPort-1 --off` and `echo detect | sudo tee /sys/class/drm/card1-DP-2/status`.

**Option B, done 2026-10-23 at 20:25: the third screen through the mini PC (the daily route).** Sunshine on this PC captures the TV screen (the forced DisplayPort-1 from Option D2) with the AMD hardware encoder and sends it over the wired LAN; Moonlight on the mini PC decodes it in hardware and shows it full screen on HDMI 1. What was done, so it can be redone:

1. Sunshine as a per-user Flatpak (no password needed; the per-user Flathub source had to be added first):

```bash
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && flatpak install -y --user flathub dev.lizardbyte.app.Sunshine
```
You should see: the install finish. Its login for the web page `https://localhost:47990` is in `~/.var/app/dev.lizardbyte.app.Sunshine/config/sunshine/web-login.txt` (set with `--creds`). Its config file next to it, `sunshine.conf`, holds three lines: `output_name = 2` (the TV screen; Sunshine numbers displays in its start-up log), `capture = x11` (its default "portal" capture pops up a consent box and waits forever), `min_log_level = 1`.

2. Firewall, mini PC only (done by Chris; both said Rule added):

```bash
sudo ufw allow from <HEAD_IP> to any port 47984,47989,47990,48010 proto tcp comment 'sunshine from minipc'
```

```bash
sudo ufw allow from <HEAD_IP> to any port 47998:48000,48002,48010 proto udp comment 'sunshine from minipc'
```

3. Pairing, once. Moonlight's command line on the mini PC asks with a chosen PIN, and Sunshine's web API accepts it; the API needs the id of the pending request, which `GET /api/pin` lists. From chris-SER8, with `PIN` a four-digit number and `IP` this PC's wired address:

```bash
ssh minipc "QT_QPA_PLATFORM=offscreen timeout 120 flatpak run com.moonlight_stream.Moonlight pair IP --pin PIN" &
```

```bash
curl -k -s -u chris:PASSWORD https://localhost:47990/api/pin
```
You should see: `{"pairings":[{"address":"<HEAD_IP>","id":"...","name":"..."}]}`. Then post the PIN with that id:

```bash
curl -k -s -u chris:PASSWORD -X POST https://localhost:47990/api/pin -H 'Content-Type: application/json' -d '{"pairing_id":"ID","pin":"PIN","name":"minipc"}'
```
You should see: `{"status":true}`, and `https://localhost:47990/api/clients/list` names minipc.

4. The stream. On the mini PC, `~/tv-stream.sh [HOST]` runs Moonlight inside the kiosk's display session (`WAYLAND_DISPLAY=wayland-0`) with `stream HOST Desktop --1080 --fps 60 --display-mode fullscreen`, and `~/tv-kiosk.sh` loops it every 8 seconds so the TV picks the screen up whenever this PC and Sunshine are on; `~/.profile`'s tty1 block now runs `cage -- ~/tv-kiosk.sh` (backup `~/.profile.bak-2026-10-23`). On this PC, `~/.config/autostart/sunshine.desktop` starts Sunshine at login.

5. The TV input: HDMI 1 (the TV Remote widget's "1 PC" button, or Settings on the TV).

*Why it did not work on 2026-10-23 night, and the fix.* Every Moonlight session got sound within half a second but no video, and gave up after 10 seconds. Sunshine runs a full display probe at the start of each session, and on this PC that probe takes 8 seconds (`time xrandr --query` shows it; `xrandr --current` is instant) because the graphics driver interrogates the four empty DisplayPort sockets every time. So Sunshine starts sending video at about 9 seconds, after Moonlight has quit. The fix is the kernel boot line that also makes the third screen permanent, with the unused sockets switched off so there is nothing to probe (kernel names: DP-1 is the BenQ, HDMI-A-1 the Samsung, DP-2 the TV screen, DP-3 to DP-6 empty):

```bash
sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 video=DP-2:1920x1080@60e video=DP-3:d video=DP-4:d video=DP-5:d video=DP-6:d"/' /etc/default/grub
```
You should see: nothing printed. Check with `grep CMDLINE_LINUX_DEFAULT /etc/default/grub`: the line now ends with the five `video=` entries inside the quotes.

```bash
sudo update-grub
```
You should see: `Generating grub configuration file ...` and `done`.

Reboot. After it: the TV screen exists from boot at 1920x1080 (Settings, Displays can arrange it; the xrandr steps of Option D2 are no longer needed), `xrandr --query` returns at once, Sunshine starts video within a second, and the mini PC's kiosk picks the screen up by itself. To undo, remove the five entries from the same line and run `sudo update-grub` again.

*Caveats.* This PC's wired address moves too (it was .83, then .85 the same evening); the stream script carries the address it had at the time, so reserve this PC's wired port on the Deco as well (its MAC is `<MAC_ADDRESS>`; pick a fixed address such as <DESKTOP_IP> and put that address in `~/tv-stream.sh` on the mini PC). Sound is not sent (the mini PC has no sound device in the kiosk; the TV's own speakers play HDMI sound only if the mini PC were to output it). Sunshine's "portal" capture must stay off on this X11 desktop. The third screen itself still comes from Option D2 and still needs the GRUB line to survive a reboot.

*Lesson from the same evening:* the Deco gave the TV's old address (.79) to Chris's phone and the TV moved to <LAN_IP>, so the desktop widget showed "connection refused" all day. Reserve the TV in the Deco app too (MAC `<MAC_ADDRESS>`), the same way as step 1 for the mini PC. The widget now looks the TV up again by its hardware address when that happens (see the kit's drivers).

**Shopping list for Option B**

1. One **USB-C display emulator** ("USB-C dummy plug"). It must say DisplayPort Alt Mode and 4K at 60 Hz; 10 to 15 dollars. It goes in the USB4 port on chris-SER8 (this PC has one USB4 port; the other USB-C port is plain USB 3.2 and carries no video). An HDMI dummy plug on a USB-C to HDMI adapter also works, but that is two parts to fail.
2. Optional, for volume, inputs and the remote: a **Pulse-Eight USB-CEC adapter**, about 50 dollars, for the mini PC. Decide after the TV's model is known; a smart TV may be controllable over the network for free.
3. Nothing else. The HDMI cable from the mini PC to the TV stays. A spare USB keyboard on the mini PC is handy but optional, since Moonlight forwards whatever is typed on it to chris-SER8.

**Build steps, Option B**

*On the mini PC (Claude can do all of this remotely; started 2026-10-17 00:10):* install `flatpak`, `cage`, `pipewire`, `pipewire-pulse` and `wireplumber`; add Flathub; `flatpak install flathub com.moonlight_stream.Moonlight`; let `chris` log in automatically on the console tty1 (a `systemctl edit getty@tty1` override with `agetty --autologin chris`); a `~/.bash_profile` snippet that, on tty1 only, runs `cage -- flatpak run com.moonlight_stream.Moonlight` and pauses a few seconds between retries so a failure cannot spin. The TV then shows Moonlight's start screen instead of the text console. tty2 (Ctrl-Alt-F2 on the mini PC's keyboard) stays a normal login for recovery. PipeWire is there so the stream's sound can come out of the TV over HDMI.

*On chris-SER8 (needs Chris at the keyboard, about 20 minutes):*

1. Plug the dummy plug into the USB4 port. Settings, Displays shows a third monitor. Drag it so it sits above monitor 2, pick 1920x1080 (4K later if the TV is 4K and the stream keeps up), Apply, Keep.
2. Find its name, which Sunshine needs:

```bash
xrandr | grep ' connected'
```
You should see: the two existing monitors plus a new `DisplayPort-N connected 1920x1080+...` line. That `DisplayPort-N` is OUTPUT_NAME below.

3. Firewall rules on this PC, so only the mini PC may connect to Sunshine (ufw is active here):

```bash
sudo ufw allow from <HEAD_IP> to any port 47984,47989,47990,48010 proto tcp comment 'sunshine from minipc'
```
You should see: `Rule added`.

```bash
sudo ufw allow from <HEAD_IP> to any port 47998:48000,48002,48010 proto udp comment 'sunshine from minipc'
```
You should see: `Rule added`.

4. Install Sunshine:

```bash
flatpak install -y --system flathub dev.lizardbyte.app.Sunshine
```
You should see: the download finish with no error.

```bash
flatpak run --command=additional-install.sh dev.lizardbyte.app.Sunshine
```
You should see: an administrator password prompt, then the udev rules installed. The Sunshine docs call this step required.

```bash
flatpak run dev.lizardbyte.app.Sunshine
```
You should see: log lines including `Detected display: DisplayPort-N (id: ...)` for each screen, then the web page is reachable. Leave it running (or start it from the app menu).

5. In a browser on this PC open `https://localhost:47990`, accept the certificate warning, create a Sunshine username and password (write them in your password manager). Then Configuration, Audio/Video: set **Output Name** to OUTPUT_NAME, leave the encoder on automatic (it picks VA-API on the 780M). Save, then Apply.

*Pairing and first stream:* on the TV, Moonlight shows chris-SER8 if it finds it; if not, press Add host and type `<DESKTOP_IP>`. Select it; Moonlight shows a four-digit PIN. In Sunshine's web page open the PIN tab, type it, submit. Back on the TV, choose **Desktop**. The third screen appears on the TV. In Moonlight's settings pick 1920x1080, 60 fps, about 20 Mbps, hardware decoding on, and "Optimize mouse for remote desktop" on.

*Sound:* by default Sunshine sends a copy of whatever this PC is playing to the TV, which doubles the Bluetooth speaker. To have only chosen apps play on the TV, make a dummy output on this PC (`pactl load-module module-null-sink sink_name=tv sink_properties=device.description=TV`), set Sunshine's Audio Sink to `tv.monitor`, and move individual apps to "TV" in Zorin's Sound settings. Making that permanent is a one-line PipeWire config; do it once the basics work.

*Autostart:* Sunshine needs to be running for the TV to connect. Easiest is Settings, Startup Applications in Zorin (Tweaks) with the command `flatpak run dev.lizardbyte.app.Sunshine`, or a user systemd service doing the same.

Why Flatpak and not the .deb: Flatpak is one command on Zorin and already installed here. It captures the screen through X11, which costs a bit more CPU than the kernel (KMS) capture the .deb offers; on this Ryzen that is a few percent of one core for 1080p60 and not worth the extra setup. If CPU use ever bothers, the .deb from Sunshine's Cloudsmith repository is the upgrade.

Build order: the mini PC side first (no purchase needed, shows Moonlight's start screen on the TV); buy the dummy plug; then the chris-SER8 steps above with Chris at the keyboard; pair; tune.

**Volume, inputs and the TV remote.**

The protocol TVs use for volume, input switching, power and remote keys over HDMI is called HDMI-CEC. Computer HDMI ports almost never speak it, and the mini PC's was checked on 2026-10-17: no `/dev/cec` device exists, so neither computer can tell the TV anything through its cable without the adapter below.

- *The universal fix:* a Pulse-Eight USB-CEC adapter (about 50 dollars) on the mini PC, sitting in line with the HDMI cable to the TV. Linux has a built-in driver for it. From the mini PC, and so from chris-SER8 over `ssh minipc`, you can then switch the TV on and off, change volume and mute, and switch inputs (`cec-ctl` from the `v4l-utils` package). In the other direction the TV remote's arrows, OK, back, play and pause arrive on the mini PC as key presses, and Moonlight forwards them to chris-SER8, so the remote drives whatever is on the TV window.
- *If the TV is a smart TV:* most brands can also be controlled over the LAN, no adapter needed. LG (webOS), Samsung (Tizen), Sony (Bravia), Roku TVs, Android and Google TVs, Vizio and Hisense all have command-line tools and Home Assistant integrations for power, volume, input and apps. The TV is an **LG OLED48C1PUB** (LG C1 series, 48 inch 4K OLED, 120 Hz, HDMI 2.1, webOS, made 06/2021; label photographed 2026-10-17). LG webOS TVs accept commands over the LAN, so power, volume, mute, input switching and launching apps work from either computer with no adapter. The CEC adapter is then only needed if the TV remote should drive the window on the TV; decide later.

Found on the LAN 2026-10-17: the TV is at **<LAN_IP>**, MAC `<MAC_ADDRESS>` (needed for switching it on over the network). Reserve that address on the router too, the same way as step 1, so the commands below never chase it. The control tool `bscpylgtv` is installed on the mini PC in its own Python environment at `~/.venvs/lgtv`; the TV's pairing key is kept in `~/.venvs/lgtv/lgtv-key.txt`; the one-time pairing was done 2026-10-17 00:05 and control was verified (volume read 7, nudged to 8 and back; the TV reports the mini PC on input `HDMI_1`, labelled PC). From chris-SER8 the shape of every command is:

```bash
ssh minipc '~/.venvs/lgtv/bin/bscpylgtvcommand --log WARNING -p ~/.venvs/lgtv/lgtv-key.txt <LAN_IP> COMMAND'
```
You should see: the TV's answer as a line of text, or nothing for commands that only do something. Useful COMMAND values: `get_volume`, `set_volume 15`, `volume_up`, `volume_down`, `set_mute true`, `set_mute false`, `get_inputs` (lists the HDMI inputs with their ids), `set_input HDMI_1`, `get_current_app`, `launch_app netflix`, `power_off`. Switching the TV on is a Wake-on-LAN packet instead: `wakeonlan <MAC_ADDRESS>` (package `wakeonlan`), which needs the TV's "Turn on via Wi-Fi" or "Mobile TV On" setting enabled under its General settings; "Quick Start+" makes it wake faster.

OLED note: the TV is an OLED, so a static third monitor (panels, taskbars, a window left in one place for hours) risks burn-in. Keep the TV's own pixel-care settings on, prefer dark themes on that screen, hide the top panel there, and switch the TV off when the screen is not in use; the `power_off` command above makes that a one-liner.
- *Sound:* Sunshine can carry chris-SER8's audio to the TV with the picture, or leave it on the desk speakers; that is one setting. TV volume itself is the CEC or network path above. The TV's own remote keeps working for everything regardless.

**The TV Remote desktop widget on chris-SER8 (built and installed 2026-10-17).** The whole TV Remote project (the apps for Windows, Linux, Android and iPhone, the files for Austin, the sharing guide) moved on 2026-10-23 to its own workspace folder, `TV Remote/`, which has its own README; this paragraph stays as the record of how it started. A panel on the desktop layer of both monitors, under your windows, with the TV's power, volume, mute, inputs, apps, a YouTube link box that plays on the TV, a navigation pad, and add-on buttons for this computer (Frigate cameras and Cockpit by default). Settings behind the gear: Look, TV (including Find LG TVs, sound output such as Bluetooth, screen off), and Buttons (TV apps and computer apps, each with a picker). It is standalone: GTK 3 plus the bscpylgtv library, no Claude involved. Source: `TV Remote/tv-remote/desktop-linux-gtk/` (`tv_remote.py`, `install.sh`, `README.md`); the whole `tv-remote/` folder is a git repository pushed to GitHub as `mccawc1/tv-remote` (private). Installed copy: `~/.local/share/tv-remote/`, environment `~/.venvs/tvremote`, settings `~/.config/tv-remote/config.json`, pairing key `~/.config/tv-remote/tv-key.db`. Starts at login (`~/.config/autostart/tv-remote.desktop`) and is in the app menu as TV Remote. Measured: 87 MB of memory for two screens, 16 MB on disk plus the system GTK, no CPU while idle. Verified that night: volume, mute, input switching, YouTube by link, pairing from this PC. After editing the source, run `bash install.sh` again. Since 2026-10-17 03:22 the installed copy has the skins (Settings, Look, Skin: 34 skins plus Match my desktop, each with its own button look and readable text), is placed by dragging it like a desktop icon (each screen remembers its spot; Look has a button to send it back to the corner), keeps Back above Left in the navigation pad (top row when collapsed), adds app buttons with the round + next to each Buttons heading, and previews the Widget opacity slider live. The shared skin files `skinlib.py` and `skins.json` are copied next to `tvdrivers.py` by `install.sh`.

Note on this PC's Python: `python3-venv` and pip were not installed and pip hangs on this PC because of the IPv6 quirk. The environment was made with `python3 -m venv --without-pip --system-site-packages`, pip's folder copied from the mini PC's venv, and the three wheels downloaded on the mini PC (which has IPv6 off) and installed offline. `install.sh` explains this if it ever has to rebuild the environment.

**A keyboard and screen for the rare BIOS visit.** Steps 2 and 5 need a keyboard and screen on the mini PC, and so does any lock-out recovery. Leave a spare USB keyboard plugged into the mini PC permanently (any old one). The TV is already its screen. If the TV ends up on chris-SER8 instead (Option A), keep an HDMI cable from the mini PC to a second TV input and switch inputs for a BIOS visit. A 2-port USB switch (one button moves a keyboard and mouse between two computers) is the other option; the spare keyboard costs less and never has a stuck button.

### 13. Checklists and what to do when

**Verification checklist, per stage.** Tick each line before moving on.

Stage: network and firmware (steps 1 and 2)
- [ ] Router shows a reservation for `<MAC_ADDRESS>` at <HEAD_IP>
- [ ] `ssh minipc 'ip -br -4 addr show enp45s0'` reports <HEAD_IP>/22
- [ ] Power-cord test: box comes back by itself, `ssh minipc uptime` answers
- [ ] BIOS: Restore after AC Power Loss = Power On, ErP off, Fast Boot off, Boot Option #1 = ubuntu

Stage: kit scripts (step 3)
- [ ] `ssh minipc 'docker ps'` prints a header, no permission error
- [ ] `curl -4 -s http://<HEAD_IP>:11434/api/tags` from chris-SER8 lists a model
- [ ] `ssh minipc` then `agent` opens tmux; `claude` is signed in; Ctrl-b d detaches

Stage: desktop app (step 4)
- [ ] A Claude session started on the `minipc` SSH connection answers `minipc` to `hostname`

Stage: RAM (step 5)
- [ ] `free -h` shows about 31Gi
- [ ] dmidecode shows two 16 GB sticks at 3200 MT/s
- [ ] Memtest86+ 9.00: one full pass, 0 errors

Stage: storage (step 6)
- [ ] `sudo zpool status`: ONLINE, mirror-0, both drives by-id, 0 errors
- [ ] `grep c_max /proc/spl/kstat/zfs/arcstats` reads 4294967296 (also after a reboot)
- [ ] `zfs list` shows tank/shares, tank/backups, tank/frigate, tank/docker, all mounted
- [ ] `systemctl list-timers --all | grep zfs` shows zfs-scrub-monthly@tank.timer
- [ ] First scrub finished with 0 errors
- [ ] Pool imports by itself after `sudo reboot`

Stage: Samba (step 7)
- [ ] `testparm -s` says Loaded services file OK
- [ ] ufw shows Samba allowed from <LAN_IP>/22 only
- [ ] Zorin Files opens smb://<HEAD_IP>/shares and can create a file
- [ ] (optional) `/mnt/minipc` mounts from fstab after a Zorin reboot

Stage: Frigate (step 8)
- [ ] UI at https://<HEAD_IP>:8971 logs in
- [ ] `grep FRIGATE_DIR /tank/frigate/.env` reads /tank/frigate
- [ ] UI storage shows the pool's free space
- [ ] `/srv/frigate` removed after a week

Stage: Cockpit and Tailscale (step 9)
- [ ] https://<HEAD_IP>:9090 logs in, ufw rule limited to the LAN
- [ ] `tailscale ip -4` prints a 100.x address; MagicDNS name resolves; key expiry disabled
- [ ] `ssh` to the ts.net name works from a phone hotspot

Stage: backups (step 10)
- [ ] `restic init` done, password stored in the password manager too
- [ ] `systemctl list-timers | grep restic` shows the nightly timer
- [ ] `journalctl -u restic-backup.service` shows a saved snapshot after the first night
- [ ] Restore test: a file came back and matched

Stage: cameras (step 11)
- [ ] `enp46s0` has 10.10.10.1/24, `ip_forward = 0`
- [ ] Each camera has a fixed `dhcp-host` line and a `viewer` user with the .env password
- [ ] Frigate UI shows live video and draws boxes on people
- [ ] Cameras cannot reach the internet (their own page shows no cloud connection)

**What to do when.**

*SSH says "Connection refused" or times out.*
1. On chris-SER8: `ping -c 3 <HEAD_IP>`. No reply means the box is off, unplugged, or on another address; check the router's client list for `minipc` and its address. If the address changed, step 1 was skipped or lost.
2. Reply but no SSH: wait two minutes, the box may still be booting.
3. Still nothing: plug the TV and keyboard in (step 12). Log in locally and run `systemctl status ssh` and `sudo ufw status`. Port 22 must be allowed.
4. "Permission denied (publickey)" means the key is the problem, not the network. Locally, check `~/.ssh/authorized_keys` on minipc contains the line from `stick-kit/ssh/authorized_keys`. If you are locked out by password login being off, delete `/etc/ssh/sshd_config.d/00-kit.conf` (or `60-kit.conf` if step 0 was never done) and `sudo systemctl reload ssh`, fix the key, then re-apply step 0.
5. To confirm password login is really off, run the key-less probe from step 0; the answer must list `publickey` only.

*zpool status says DEGRADED.*
1. Do not panic and do not run any destructive command. The data is still there on the other drive. Run `sudo zpool status -v` and read which drive is `UNAVAIL`, `FAULTED` or `REMOVED`.
2. USB drive that dropped out (common after a power blip or cable nudge): unplug and replug it, wait ten seconds, then `sudo zpool online tank DRIVE_ID` (the by-id name from the status output) and `sudo zpool clear tank`. It resilvers (copies the changes) and returns to ONLINE.
3. Drive that keeps faulting or shows read errors in `sudo smartctl -a`: it is dying. Buy a replacement of at least the same size, connect it, find its by-id name, then `sudo zpool replace tank OLD_DRIVE_ID /dev/disk/by-id/NEW_DRIVE_ID`. Watch `sudo zpool status` until the resilver finishes. Only then remove the old drive.
4. Check the backup from step 10 is current while this is going on. Two failures in a row would need it.

*Frigate says it cannot find the iGPU, or hardware decoding fails.*
1. On minipc: `ls -l /dev/dri`. You should see `renderD128`. If it is missing, the kernel did not load the Intel graphics driver; `sudo dmesg | grep -i i915` and a reboot usually sort it.
2. `sudo intel_gpu_top` while a camera is streaming should show the Video engine busy. If it shows nothing, Frigate is decoding on the CPU; check `hwaccel_args: preset-vaapi` is still in `config.yml`.
3. The Compose file must still pass `/dev/dri/renderD128` under `devices:`. Run `cd /tank/frigate && docker compose up -d` after any edit.
4. Fallback that always works: remove the `hwaccel_args` line; Frigate decodes on the CPU, slower but functional.

*The box boots into the BIOS instead of Ubuntu.*
1. In the BIOS, go to **Boot**, set **Boot Option #1** to the `ubuntu` entry, F10 to save. It happened once already, right after the install.
2. Back in Ubuntu: `sudo efibootmgr`. You should see `BootCurrent` pointing at the Ubuntu entry and `BootOrder` starting with it. If the Ubuntu entry is missing entirely, run `sudo grub-install` and check again.
3. If this repeats after each power loss, the BIOS battery may be flat (the Cubi has a small coin cell); the BIOS date resetting to 2023 is the giveaway.

*A download sits on "pulling manifest", or any install hangs for minutes with no progress.*
1. It is almost always IPv6. On minipc, `ip -6 addr show enp45s0` must print nothing; if a `2605:` address is back, the drop-in from step 0b is missing or was not applied. On chris-SER8, add `-4` to curl and wget.
2. For Ollama specifically: `journalctl -u ollama -n 30 --no-pager` shows `stalled; retrying` lines while it is stuck. After fixing the network the running pull resumes by itself; if it does not within two minutes, Ctrl-C and run the same command again, it continues from where it stopped.

*The USB stick is not detected at boot.*
1. Use a USB-A port on the back, not the front, and no hub. Tap F11 at the logo for the one-time boot menu; the stick should be listed by its brand name or as `UEFI: ...`.
2. Fast Boot (step 2) must be off, or USB is not initialised in time.
3. Secure Boot: Ventoy needs its key enrolled once (it was, on 2026-10-16); a blue MOK screen means enrol again from the VTOYEFI partition's `ENROLL_THIS_KEY_IN_MOKMANAGER.cer`. Memtest86+ may need Secure Boot off (step 5).
4. If the stick is seen on chris-SER8 but never on the mini PC, rewrite it (Part B). Lexar sticks have been fussy before; a different stick is a fair test.
5. Remember the eject quirk: after `udisksctl power-off` the stick is invisible until it is physically replugged.

## Part B: How this box was built

Short, for a future reinstall. Dates are 2026-10-16 unless noted.

**Hardware.** Altex-branded MSI PRO ADL-U Cubi 5 12M (board MS-B0A8), BIOS 8.60 dated 2023-02-16. Intel i3-1215U (2 performance + 4 efficiency cores, 8 threads) with Intel UHD graphics (`/dev/dri/renderD128`, used by Frigate for decode and OpenVINO detection). 8 GB DDR4 in one of two SO-DIMM slots at install time (64 GB max). 512 GB Kingston SNV2S500G M.2 NVMe system drive. One empty 2.5" bay. Two Ethernet ports: 1 GbE Realtek RTL8111H (`enp45s0`, MAC `<MAC_ADDRESS>`, the LAN port) and 2.5 GbE Realtek RTL8125BG (`enp46s0`, MAC `<MAC_ADDRESS>`, reserved for cameras). Wi-Fi `wlo1` (unused). Thunderbolt 4, four USB 3.2 Gen 2 ports. 65 W power brick. BIOS key Del, boot menu F11. It shipped with Windows 11 Home (machine name "TheCoolComputer"), now gone.

**Operating system.** Ubuntu Server 26.04.1 LTS ("resolute"), released 2026-08-27, kernel 7.0. Chosen over Omarchy (an Arch desktop with full-disk encryption by default, wrong for an unattended server) and over TrueNAS (fine for storage, awkward for Docker and agent tooling). Headless on purpose: everything is done over SSH, Cockpit and the Claude desktop app.

**The install stick, and the bug.** The plan was one Ventoy 1.1.18 multiboot stick (Chris's 64 GB Lexar) holding four ISOs plus the kit. Booting the Ubuntu Server ISO through Ventoy 1.1.18 fails at the storage step with "Sorry, there was a problem examining the storage devices", and the installer log shows `Invalid dep_id (disk-dm-1) not in storage config`. Cause: Ventoy 1.1.11 and newer presents the ISO as two device-mapper devices (`ventoy` and `VentoyPart`), and the installer's storage probe only knows to ignore one named exactly `ventoy`. Renaming the dm devices from the installer shell (`dmsetup rename`) made the names right but did not make the probe pass, so **skip the dmsetup detour entirely** next time. Tracked as Launchpad #2012722 and #2149811 and Ventoy issue #3567. What works: a plain dd of the Ubuntu ISO, or Ventoy 1.1.10 or older.

The stick was rewritten as a plain Ubuntu installer on chris-SER8:

**WARNING: dd overwrites the whole target device. Confirm with `lsblk` that /dev/sdX is the stick and not the internal drive.**

```bash
sudo dd if=~/ISOs/ubuntu-26.04.1-live-server-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
```
You should see: a byte count climbing to about 2.9 GB, then `records in/out` lines and the prompt back.

**Installer choices.** F11 at the logo, picked the stick. English, default keyboard. Network: the 1 GbE port took DHCP. Storage: **Use an entire disk** on the Kingston NVMe, **no LVM**, no encryption. Profile: name Chris, server name `minipc`, user `chris`. **Install OpenSSH server** ticked, no imported keys. **No snaps** selected on the featured-snaps page. The install finished, the stick came out, and the box rebooted into the BIOS because no boot entry had been picked; choosing the ubuntu entry as Boot Option #1 fixed it for good (`sudo efibootmgr` now shows only Boot0002 "Ubuntu").

**First login and the kit.** Logged in once at the mini PC's own keyboard. The kit (`stick-kit/` in the workspace) never came from the stick in the end; it was copied from chris-SER8 with `scp -r` to `~/setup` on minipc after SSH worked. Key pair `~/.ssh/minipc` on chris-SER8, public key installed with `ssh-copy-id`, `Host minipc` entry in `~/.ssh/config`. Then `00-first-login.sh` (updates, tmux, htop, ufw, smartmontools, intel-gpu-tools, time zone America/Chicago, unattended-upgrades, SSH key, firewall with only 22/tcp) and, after a key login worked, `05-lock-down-ssh.sh` (meant to turn password login off; it did not, because the installer's `50-cloud-init.conf` sorts before the kit's `60-kit.conf`; see Part A step 0). Root is ext4 on nvme0n1p2 (464.7 GB), the EFI partition is nvme0n1p1. A reboot test passed the same evening.

**Rebuilding the Ventoy stick.** The Lexar stick is still a plain Ubuntu installer. Rebuild the multiboot layout once the installer is not needed, so Memtest86+, SystemRescue and the Zorin installer are one stick again. On chris-SER8, where `~/ISOs/` holds all four ISOs with checksums and `~/ventoy/ventoy-1.1.18/` holds the tool:

1. Plug the stick in and find its device name with `lsblk` (64 GB, Lexar). Unmount anything mounted from it.

**WARNING: Ventoy2Disk erases the stick.**

```bash
sudo ~/ventoy/ventoy-1.1.18/Ventoy2Disk.sh -i -g -s /dev/sdX
```
You should see: a summary of the disk, a `Double-check` prompt (answer `y` twice), then `Ventoy Install Done`. `-g` makes a GPT layout, `-s` turns on Secure Boot support; the MOK key was already enrolled in the mini PC's firmware, so it should boot without the blue screen.

2. Unplug and replug the stick (the Ventoy partition mounts as `Ventoy`). Copy the four ISOs and the kit:

```bash
cp ~/ISOs/ubuntu-26.04.1-live-server-amd64.iso ~/ISOs/zorin-os-18-pro-64bit.iso ~/ISOs/systemrescue-13.02-amd64.iso ~/ISOs/mt86plus_9.00_x86_64.iso /media/chris/Ventoy/
```
You should see: nothing for a long time. The stick writes at 14 to 17 MB/s, so about 12 GB takes 12 to 15 minutes, and the copy only truly finishes when the next command returns.

```bash
sync
```
You should see: nothing, after a wait of a few minutes while the cache flushes.

```bash
cp -r "/home/chris/Desktop/Chris's Greatness/Mini PC Server/stick-kit" /media/chris/Ventoy/setup
```
You should see: nothing printed. The folder must be called `setup`; the kit README's instructions expect that name.

3. Verify the ISOs after a remount (unmount, replug, mount again) so you read from the stick and not from the cache:

```bash
cd /media/chris/Ventoy && sha256sum -c ~/ISOs/SHA256SUMS --ignore-missing
```
You should see: `ubuntu-26.04.1-live-server-amd64.iso: OK`. Check the Zorin one against `~/ISOs/zorin-sha256.txt` and SystemRescue against `~/ISOs/systemrescue-13.02-amd64.iso.sha256` the same way. Memtest86+ has no published sum in `~/ISOs`; a successful boot is its test.

4. Eject with the Files app's eject button rather than `udisksctl power-off`, which cuts the port's power and makes the stick vanish until replugged.

**Reinstall rule.** As long as Ventoy 1.1.18 (or the installer) has this bug, Ubuntu Server cannot be installed from the Ventoy stick. For any reinstall: dd the Ubuntu ISO to a second stick (any 4 GB or larger stick), install from it, then put the Ventoy stick back in for the kit. Check Ventoy's release notes first; a fixed version would make the second stick unnecessary. The Zorin, SystemRescue and Memtest86+ ISOs boot fine through Ventoy.

**Network note.** IPv6 is advertised on the LAN but does not route. apt and curl are forced to IPv4 by the kit; services that fetch on their own (Ollama, Docker) stall instead. Part A step 0b turns IPv6 off on `enp45s0` with `/etc/netplan/60-ipv4-only.yaml`; if the router's IPv6 is ever fixed, delete that file and `sudo netplan apply` to get it back.

**Where things are.**
- Workspace: `/home/chris/Desktop/Chris's Greatness/Mini PC Server/` (this file, `stick-kit/`)
- On minipc: `~/setup` (kit copy), `/tank` (pool, after step 6), `/tank/frigate` (after step 8)
- On chris-SER8: `~/ISOs/` (four ISOs, `SHA256SUMS`, `zorin-sha256.txt`, the only local copy of the paid Zorin Pro installer), `~/ventoy/ventoy-1.1.18/`, `~/.ssh/minipc` (private key, no passphrase), `~/.ssh/config` (Host minipc)
- Claude's memory for this project: `/home/chris/.claude/projects/-home-chris-Desktop-Chris-s-Greatness/memory/project-mini-pc-server.md` records the decisions and current state. Update it when a step here is done, so the next session starts from the truth.
