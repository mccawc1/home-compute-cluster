#!/usr/bin/env bash
# 05-lock-down-ssh.sh : turn off password login over SSH.
# ONLY run this after a key login from the Zorin PC has worked, or you can
# lock yourself out (recovery: log in at the mini PC's own keyboard and
# delete /etc/ssh/sshd_config.d/00-kit.conf).
# The file is named 00- on purpose: sshd keeps the FIRST value it reads for a
# setting, and the installer leaves 50-cloud-init.conf saying
# PasswordAuthentication yes. A 60- name lost to it (found 2026-10-16).
set -euo pipefail

if [ ! -s "$HOME/.ssh/authorized_keys" ]; then
  echo "No authorized_keys found. Run 00-first-login.sh first." >&2
  exit 1
fi

read -r -p "Did 'ssh -i ~/.ssh/minipc chris@minipc' work WITHOUT a password? (yes/no) " ok
[ "$ok" = "yes" ] || { echo "Stopping. Test key login first."; exit 1; }

sudo rm -f /etc/ssh/sshd_config.d/60-kit.conf   # name used before 2026-10-16
sudo tee /etc/ssh/sshd_config.d/00-kit.conf >/dev/null <<'CONF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
CONF

sudo sshd -t
sudo systemctl reload ssh
echo "Password login over SSH is now off. Keys only."
