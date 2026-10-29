#!/usr/bin/env bash
# READ-ONLY detection against the Windows server. Run it so prompts reach your keyboard:
#   ssh minipc 'mkdir -p ~/cluster-pc3'
#   scp ~/cluster-pc3/win-pc3-detect.sh minipc:~/cluster-pc3/
#   ssh -t minipc 'bash ~/cluster-pc3/win-pc3-detect.sh'
# impacket asks for the Windows password itself (keyboard only — not in the command
# line, not logged, never seen by Claude). It changes nothing on the server.
set -euo pipefail
TARGET=<PC3_IP>

if [ ! -t 0 ]; then
  echo "ERROR: run this ON the minipc with a terminal (ssh -t minipc 'bash ~/cluster-pc3/win-pc3-detect.sh')."
  echo "Do NOT pipe it in with '< file' — the password prompt needs the keyboard."; exit 1
fi

echo "Installing impacket (one time)…"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3-impacket >/dev/null 2>&1 || true
WMIEXEC=$(command -v impacket-wmiexec || command -v wmiexec.py || true)
[ -n "$WMIEXEC" ] || { echo "impacket-wmiexec not found; try: pipx install impacket"; exit 1; }

read -rp "Windows admin username [Administrator]: " WUSER
WUSER=${WUSER:-Administrator}

# One command, one password prompt (from impacket). '&' chains the checks inside cmd.exe.
CMD='bcdedit /enum {fwbootmgr} & echo ===DISKS=== & wmic diskdrive get Index,Model,Size,InterfaceType & echo ===GPTorMBR=== & wmic partition get DiskIndex,Type & echo ===SYSTEM=== & wmic computersystem get Manufacturer,Model & echo ===END==='

echo
echo "Password prompt is next (from impacket). Read-only checks on $TARGET …"
echo
"$WMIEXEC" "WORKGROUP/${WUSER}@${TARGET}" "$CMD"
echo
echo "If you saw STATUS_LOGON_FAILURE -> wrong user/pass (Win7 usually needs the built-in 'Administrator')."
echo "If you saw STATUS_ACCESS_DENIED  -> account isn't allowed remote admin; use 'Administrator' or boot with F12."
echo "Otherwise: paste the FIRMWARE (top) + DISKS + GPTorMBR sections back to Claude."
