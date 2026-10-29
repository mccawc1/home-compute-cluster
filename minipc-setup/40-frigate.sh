#!/usr/bin/env bash
# 40-frigate.sh : set up Frigate NVR. Creates the folders, exports the object
# detection model (one-time, a few minutes), copies the config and starts the
# container. It starts with the example camera disabled, so it runs with no
# cameras and waits for you to add real ones.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRIGATE_DIR="${FRIGATE_DIR:-/srv/frigate}"   # move to the ZFS pool later
LAN_CIDR="<LAN_IP>/22"

command -v docker >/dev/null || { echo "Run 10-docker.sh first." >&2; exit 1; }
[ -e /dev/dri/renderD128 ] || echo "WARNING: /dev/dri/renderD128 missing, iGPU decode will not work"

echo "== Folders at $FRIGATE_DIR"
sudo mkdir -p "$FRIGATE_DIR/config/model_cache" "$FRIGATE_DIR/media"
sudo chown -R "$USER:$USER" "$FRIGATE_DIR"

echo "== Config files"
cp "$KIT_DIR/frigate/docker-compose.yml" "$FRIGATE_DIR/"
[ -f "$FRIGATE_DIR/config/config.yml" ] || cp "$KIT_DIR/frigate/config.yml" "$FRIGATE_DIR/config/config.yml"
if [ ! -f "$FRIGATE_DIR/.env" ]; then
  cp "$KIT_DIR/frigate/.env.example" "$FRIGATE_DIR/.env"
  sed -i "s|^FRIGATE_DIR=.*|FRIGATE_DIR=$FRIGATE_DIR|" "$FRIGATE_DIR/.env"
  # '|| true' matters: head closes the pipe early, tr gets SIGPIPE (exit 141)
  # and with pipefail that killed the whole script on 2026-10-16.
  RTSP_PW="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20 || true)"
  [ "${#RTSP_PW}" -eq 20 ] || { echo "password generation failed" >&2; exit 1; }
  sed -i "s|^FRIGATE_RTSP_PASSWORD=.*|FRIGATE_RTSP_PASSWORD=$RTSP_PW|" "$FRIGATE_DIR/.env"
  echo "   generated a camera password in $FRIGATE_DIR/.env (use it when you set up each camera's 'viewer' user)"
fi

echo "== Detection model (YOLOv9-t 320, exported with Docker, one time)"
if [ ! -f "$FRIGATE_DIR/config/model_cache/yolov9-t-320.onnx" ]; then
  bash "$KIT_DIR/frigate/export-yolov9.sh" "$FRIGATE_DIR/config/model_cache"
fi

echo "== Firewall: Frigate UI and streams from the LAN only"
sudo ufw allow from "$LAN_CIDR" to any port 8971 proto tcp comment 'frigate ui'
sudo ufw allow from "$LAN_CIDR" to any port 8554 proto tcp comment 'frigate rtsp'
sudo ufw allow from "$LAN_CIDR" to any port 8555 comment 'frigate webrtc'

echo "== Start"
cd "$FRIGATE_DIR"
docker compose pull
docker compose up -d
sleep 8
docker compose logs --tail 40 frigate

echo
IP="$(hostname -I | awk '{print $1}')"
echo "Frigate UI:  https://$IP:8971   (self-signed certificate, accept the warning)"
echo "First login: user 'admin'. The password is printed once in the log:"
echo "   docker compose -f $FRIGATE_DIR/docker-compose.yml logs frigate | grep -i password"
echo "Add cameras in the UI or in $FRIGATE_DIR/config/config.yml, then: docker compose restart"
