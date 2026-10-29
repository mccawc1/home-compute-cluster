#!/usr/bin/env bash
# Run ON the minipc:  ssh minipc 'bash -s' < setup-minipc-pxe.sh
# Sets it up as a network-boot server that installs Ubuntu onto pc3 automatically.
# Idempotent and self-contained. Only touches the minipc. Needs sudo (you have it there).
set -euo pipefail
LAN_IFACE=enp45s0
LAN_CIDR=<LAN_IP>/22

echo "== 1. PXE packages"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ipxe pxelinux syslinux-common dnsmasq >/dev/null

echo "== 2. TFTP boot binaries + iPXE install script"
mkdir -p ~/pxe/tftp ~/pxe/http
cp /usr/lib/ipxe/undionly.kpxe ~/pxe/tftp/
cp /usr/lib/ipxe/ipxe.efi ~/pxe/tftp/
cp ~/cluster-pc3/boot.ipxe ~/pxe/http/boot.ipxe

echo "== 3. dnsmasq proxy-DHCP config"
sudo cp ~/cluster-pc3/dnsmasq-pxe.conf /etc/dnsmasq.d/pxe-pc3.conf

echo "== 4. HTTP service on :8086 serving the installer"
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/pxe-http.service <<UNIT
[Unit]
Description=HTTP server for pc3 network install
After=network-online.target
[Service]
ExecStart=/usr/bin/python3 -m http.server 8086 --bind 0.0.0.0 --directory %h/pxe/http
Restart=on-failure
[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now pxe-http.service

echo "== 5. Firewall: allow boot ports (DHCP must be open to any source -"
echo "        a PXE client has no IP yet, so its request comes from 0.0.0.0)"
sudo ufw allow 67/udp   comment 'DHCP/PXE' >/dev/null
sudo ufw allow 68/udp   comment 'DHCP' >/dev/null
sudo ufw allow 69/udp   comment 'PXE TFTP' >/dev/null
sudo ufw allow 4011/udp comment 'PXE' >/dev/null
sudo ufw allow 8086/tcp comment 'PXE HTTP' >/dev/null

echo "== 6. Start dnsmasq"
sudo systemctl enable dnsmasq
sudo systemctl restart dnsmasq
sleep 2
systemctl is-active dnsmasq && echo "dnsmasq active"

echo
echo "Ready. Files served:"; ls -lh ~/pxe/http/ | awk '{print $5, $9}'
echo "Boot script check:"; curl -fsS http://<HEAD_IP>:8086/boot.ipxe >/dev/null && echo "  http OK"
echo
echo "To STOP serving after pc3 is installed:"
echo "  sudo systemctl disable --now dnsmasq; systemctl --user disable --now pxe-http"
