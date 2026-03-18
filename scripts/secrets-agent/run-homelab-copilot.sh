#!/usr/bin/env bash
set -euo pipefail

# Wrapper to start homelab-copilot-agent container with DATABASE_URL populated
# Preferred flow: read secret from Secrets Agent (SECRETS_AGENT_URL + SECRETS_AGENT_API_KEY)
# Fallback: use existing env DATABASE_URL or DB_* env vars.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
IMAGE_NAME=${HOMELAB_COPILOT_IMAGE:-homelab-copilot-agent:latest}
DOCKER_NETWORK=${HOMELAB_DOCKER_NETWORK:-homelab_monitoring}
EDDIE_AUTO_DEV_PATH=${EDDIE_AUTO_DEV_PATH:-/home/homelab/eddie-auto-dev}

SECRETS_AGENT_URL=${SECRETS_AGENT_URL:-}
SECRETS_AGENT_API_KEY=${SECRETS_AGENT_API_KEY:-}

# If DATABASE_URL is already provided, use it
if [ -n "${DATABASE_URL:-}" ]; then
  echo "Using DATABASE_URL from environment"
else
  if [ -n "$SECRETS_AGENT_URL" ] && [ -n "$SECRETS_AGENT_API_KEY" ]; then
    echo "Fetching DATABASE_URL from Secrets Agent: $SECRETS_AGENT_URL"
    payload=$(curl -sf -H "X-API-KEY: $SECRETS_AGENT_API_KEY" "$SECRETS_AGENT_URL/secrets" || true)
    if [ -n "$payload" ]; then
      # try common candidate names
      dburl=$(echo "$payload" | jq -r '.[] | select(.name=="homelab-copilot-agent" or .name=="homelab_copilot_agent" or .name=="local/homelab") | .data.DATABASE_URL' | sed -n '1p' || true)
      if [ -n "$dburl" ] && [ "$dburl" != "null" ]; then
        export DATABASE_URL="$dburl"
        echo "DATABASE_URL populated from Secrets Agent (field DATABASE_URL)"
      else
        # attempt to construct from DB_* fields inside the secret
        host=$(echo "$payload" | jq -r '.[] | select(.name=="homelab-copilot-agent" or .name=="local/homelab") | .data.DB_HOST' | sed -n '1p' || true)
        user=$(echo "$payload" | jq -r '.[] | select(.name=="homelab-copilot-agent" or .name=="local/homelab") | .data.DB_USER' | sed -n '1p' || true)
        pass=$(echo "$payload" | jq -r '.[] | select(.name=="homelab-copilot-agent" or .name=="local/homelab") | .data.DB_PASSWORD' | sed -n '1p' || true)
        name=$(echo "$payload" | jq -r '.[] | select(.name=="homelab-copilot-agent" or .name=="local/homelab") | .data.DB_NAME' | sed -n '1p' || true)
        port=$(echo "$payload" | jq -r '.[] | select(.name=="homelab-copilot-agent" or .name=="local/homelab") | .data.DB_PORT' | sed -n '1p' || true)
        if [ -n "$host" ] && [ -n "$user" ] && [ -n "$pass" ] && [ -n "$name" ]; then
          port=${port:-5432}
          export DATABASE_URL="postgresql://${user}:${pass}@${host}:${port}/${name}"
          echo "DATABASE_URL constructed from DB_* fields in Secrets Agent"
        fi
      fi
    fi
  fi
fi

# Final fallback: use DB_* env vars if provided
if [ -z "${DATABASE_URL:-}" ]; then
  if [ -n "${DB_HOST:-}" ] && [ -n "${DB_USER:-}" ] && [ -n "${DB_PASSWORD:-}" ] && [ -n "${DB_NAME:-}" ]; then
    DB_PORT=${DB_PORT:-5432}
    export DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
    echo "DATABASE_URL built from DB_* env vars"
  fi
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "WARNING: DATABASE_URL not set (Secrets Agent and env fallback failed). Starting container without DB config."
fi

if ! /usr/bin/docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "Building $IMAGE_NAME from $PROJECT_ROOT/Dockerfile.homelab-copilot-agent"
  /usr/bin/docker build \
    -t "$IMAGE_NAME" \
    -f "$PROJECT_ROOT/Dockerfile.homelab-copilot-agent" \
    "$PROJECT_ROOT"
fi

# Exec the docker run so PID 1 is docker within this unit
exec /usr/bin/docker run --rm --name homelab-copilot-agent --network "$DOCKER_NETWORK" -p 8085:8085 \
  -v "$EDDIE_AUTO_DEV_PATH:/opt/eddie-auto-dev:ro" \
  -e API_BASE_URL="${API_BASE_URL:-http://172.17.0.1:8503}" \
  -e DATABASE_URL="${DATABASE_URL:-}" \
  -e OLLAMA_HOST="${OLLAMA_HOST:-http://192.168.15.2:11434}" \
  -e OLLAMA_MODEL="${OLLAMA_MODEL:-eddie-assistant:latest}" \
  -e OLLAMA_HOSTS="${OLLAMA_HOSTS:-}" \
  -e PORT="${PORT:-8085}" \
  -e PYTHONPATH="/opt/eddie-auto-dev:/app" \
  "$IMAGE_NAME"
