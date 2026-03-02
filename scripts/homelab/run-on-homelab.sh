#!/usr/bin/env bash
# Conveniência: executar um comando no homelab via SSH (usa HOMELAB_HOST/HOMELAB_USER env)
set -euo pipefail
HOMELAB_HOST=${HOMELAB_HOST:-192.168.15.2}
HOMELAB_USER=${HOMELAB_USER:-homelab}
if [ "$#" -eq 0 ]; then
  echo "Usage: $0 '<remote-cmd>'"
  echo "Example: $0 'cd /home/homelab/estou-aqui && docker compose build && docker compose up -d'"
  exit 1
fi
REMOTE_CMD="$*"
ssh ${HOMELAB_USER}@${HOMELAB_HOST} -- "$REMOTE_CMD"
