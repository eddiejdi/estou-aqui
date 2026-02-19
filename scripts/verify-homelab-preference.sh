#!/usr/bin/env bash
set -euo pipefail

echo "Verificando padrões 'homelab-first'..."
errors=0

check() {
  local file="$1"; shift
  local expected="$1"; shift
  if ! grep -Fq "$expected" "$file"; then
    echo "ERROR: '$expected' not found in $file"
    errors=$((errors+1))
  else
    echo "OK: $file contains expected pattern"
  fi
}

# 1) Ollama default in advisor
check "advisor_agent_patch.py" "http://192.168.15.2:11434"

# 2) Copilot bridge default HOMELAB_URL
check "scripts/copilot_bus_bridge.py" "http://192.168.15.2:8503"

# 3) systemd sample uses eddie-postgres and homelab network
check "scripts/systemd/homelab_copilot_agent.service.sample" "eddie-postgres"
check "scripts/systemd/homelab_copilot_agent.service.sample" "--network homelab_monitoring"

# 4) docker-compose sets AGENT_BUS_URL to host gateway
check "docker-compose.yml" "AGENT_BUS_URL=http://172.17.0.1:8503"

# 5) advisor default API_BASE_URL should not be localhost in production-oriented code
if grep -Fq "API_BASE_URL=\"http://127.0.0.1:8503\"" advisor_agent_patch.py; then
  echo "WARN: advisor default API_BASE_URL is localhost (acceptable for unit tests only)"
fi

# 6) Tests/scripts should prefer HOMELAB_HOST default
if ! grep -R --line-number "HOMELAB_HOST" tests | grep -q "192.168.15.2"; then
  echo "WARN: tests do not reference HOMELAB_HOST default 192.168.15.2 (ok if intentional)"
fi

if [ "$errors" -ne 0 ]; then
  echo "\nFound $errors homelab-preference errors. Fix the files listed above."
  exit 2
fi

echo "All homelab preference checks passed." 
exit 0
