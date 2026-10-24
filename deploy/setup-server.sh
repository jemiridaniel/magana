#!/usr/bin/env bash
# One-time setup of a fresh Ubuntu 24.04 EC2 instance for Magana (docs/DEPLOY_AWS.md).
# Run on the server as the ubuntu user:
#   curl -fsSL https://raw.githubusercontent.com/jemiridaniel/magana/main/deploy/setup-server.sh | bash
set -euo pipefail

# Docker Engine and the compose plugin, from Docker's own repository.
if ! command -v docker >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl git
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER"
fi

# 2 GB of swap: a t3.small has 2 GB of memory, and image builds need more.
if ! swapon --show | grep -q /swapfile; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
fi

# Both repositories, side by side (docker-compose.prod.yml builds Ibà from ../iba-natlas).
mkdir -p ~/srv && cd ~/srv
[ -d magana ] || git clone https://github.com/jemiridaniel/magana.git
[ -d iba-natlas ] || git clone https://github.com/jemiridaniel/iba-natlas.git

cd magana
if [ ! -f .env ]; then
  cp deploy/.env.example .env
  chmod 600 .env
  echo
  echo "Now edit ~/srv/magana/.env (MAGANA_DOMAIN, MAGANA_API_KEY, IBA_API_KEY), then run:"
  echo "  cd ~/srv/magana && sudo docker compose -f docker-compose.prod.yml up -d --build"
else
  sudo docker compose -f docker-compose.prod.yml up -d --build
fi
