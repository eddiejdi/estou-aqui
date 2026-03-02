#!/usr/bin/env bash
# Template: register homelab runtime secrets into the local Secrets Agent (port 8088)
# Requires: SECRETS_AGENT_URL and SECRETS_AGENT_API_KEY in environment
set -euo pipefail
SECRETS_AGENT_URL=${SECRETS_AGENT_URL:-http://localhost:8088}
API_KEY=${SECRETS_AGENT_API_KEY:-}
if [ -z "$API_KEY" ]; then
  echo "ERROR: SECRETS_AGENT_API_KEY must be set in env"
  exit 1
fi

# Example: store HOMELAB_HOST and HOMELAB_USER
curl -s -X POST "$SECRETS_AGENT_URL/secrets" \
  -H "X-API-KEY: $API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"name":"local/homelab","data":{"HOMELAB_HOST":"192.168.15.2","HOMELAB_USER":"homelab"}}' \
  | jq -C .

echo "Secrets push requested — verify via: curl -sf $SECRETS_AGENT_URL/secrets | jq '. | map(select(.name=="local/homelab"))'" || true
