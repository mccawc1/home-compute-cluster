#!/usr/bin/env bash
# 00-first-login.sh : run once, as chris, right after the Ubuntu install.
# Updates the system, installs basics, sets the time zone, installs the
# Zorin PC's SSH key, and turns on the firewall with SSH allowed.
# Password login over SSH stays ON until you run 05-lock-down-ssh.sh.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TZ_NAME="America/Chicago"

echo "== 1/5 System update"
sudo apt-get update -o Acquire::ForceIPv4=true
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Acquire::ForceIPv4=true

echo "== 2/5 Basics"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -o Acquire::ForceIPv4=true \
  tmux htop curl git ufw unattended-upgrades smartmontools lm-sensors \
  intel-gpu-tools pciutils usbutils

echo "== 3/5 Time zone and automatic security updates"
sudo timedatectl set-timezone "$TZ_NAME"
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

echo "== 4/5 SSH key from the Zorin PC"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [ -f "$KIT_DIR/ssh/authorized_keys" ]; then
  touch "$HOME/.ssh/authorized_keys"
  while read -r key; do
    [ -z "$key" ] && continue
    grep -qxF "$key" "$HOME/.ssh/authorized_keys" || echo "$key" >> "$HOME/.ssh/authorized_keys"
  done < "$KIT_DIR/ssh/authorized_keys"
  chmod 600 "$HOME/.ssh/authorized_keys"
  echo "   installed $(wc -l < "$HOME/.ssh/authorized_keys") key(s)"
else
  echo "   WARNING: $KIT_DIR/ssh/authorized_keys not found, skipping"
fi

echo "== 5/5 Firewall: allow SSH, deny everything else inbound"
sudo ufw allow OpenSSH
sudo ufw --force enable
sudo ufw status verbose

echo
echo "Done. This machine's addresses:"
ip -br -4 addr | grep -v '^lo'
echo
echo "Next: from the Zorin PC run   ssh -i ~/.ssh/minipc chris@<that IP>"
echo "If that logs in WITHOUT asking for a password, run 05-lock-down-ssh.sh."
