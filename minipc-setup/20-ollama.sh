#!/usr/bin/env bash
# 20-ollama.sh : install Ollama, make it listen on the LAN so the Zorin PC
# (and anything else at home) can send it work, and pull one small model.
#
# Realistic expectations on this i3-1215U with no GPU:
#   8 GB RAM, single channel : one 7-8B model, roughly 3 to 5 tokens/second
#   32 GB RAM, dual channel  : 7-8B at 5 to 8 tokens/second, 14B possible
# Good for summaries, tagging and private chat. Too slow for agentic coding.
set -euo pipefail

LAN_CIDR="<LAN_IP>/22"
MODEL="${1:-llama3.1:8b}"   # pass another tag as the first argument if you like

echo "== Install or update Ollama"
curl -4 -fsSL https://ollama.com/install.sh | sh

echo "== Listen on all interfaces (systemd override)"
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null <<'CONF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_KEEP_ALIVE=30m"
CONF
sudo systemctl daemon-reload
sudo systemctl enable --now ollama
sudo systemctl restart ollama

echo "== Firewall: allow Ollama from the LAN only"
sudo ufw allow from "$LAN_CIDR" to any port 11434 proto tcp comment 'ollama LAN'

echo "== Pull the first model: $MODEL  (several GB, be patient)"
ollama pull "$MODEL"

echo "== Quick test"
ollama run "$MODEL" "Reply with the single word READY." || true

echo
echo "Done. From the Zorin PC, point tools at:  http://minipc:11434"
echo "   e.g.  OLLAMA_HOST=http://minipc:11434 ollama run $MODEL"
