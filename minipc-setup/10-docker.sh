#!/usr/bin/env bash
# 10-docker.sh : install Docker Engine and the Compose plugin from Docker's
# own repository (the Ubuntu-packaged docker.io lags behind).
set -euo pipefail

if command -v docker >/dev/null 2>&1; then
  echo "Docker is already installed: $(docker --version)"
else
  echo "== Docker apt repository"
  sudo apt-get update -o Acquire::ForceIPv4=true
  sudo apt-get install -y -o Acquire::ForceIPv4=true ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -4 -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  # VERIFY: if Docker has no repo for this Ubuntu codename yet, the next apt
  # update fails. Then set CODENAME=noble below and run the script again.
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update -o Acquire::ForceIPv4=true
  sudo apt-get install -y -o Acquire::ForceIPv4=true \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

echo "== Let chris run docker without sudo"
sudo usermod -aG docker "$USER"

echo "== Test"
sudo docker run --rm hello-world | head -5 || true   # head may cut docker off (SIGPIPE); not an error

echo
echo "Done. Log out and back in once so the docker group applies to your shell."
