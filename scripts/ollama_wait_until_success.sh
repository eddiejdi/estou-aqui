#!/usr/bin/env bash
# scripts/ollama_wait_until_success.sh
# Ejecuta repetidas requisições ao endpoint Ollama (chat/completions)
# a cada INTERVAL segundos até detectar uma resposta de "sucesso".
# Saída: exit 0 somente quando o padrão de sucesso for encontrado.
# Uso básico:
#   ./scripts/ollama_wait_until_success.sh                # roda com defaults
#   HOST=http://192.168.15.2:11434 MODEL=eddie-assistant:latest ./scripts/ollama_wait_until_success.sh
# Parâmetros (via variáveis de ambiente):
#   HOST            - URL do Ollama API (default: http://192.168.15.2:11434)
#   MODEL           - modelo a testar (default: qwen2.5-coder:1.5b)
#   PROMPT          - prompt de teste (default: "Responda apenas: pong")
#   SUCCESS_PATTERN - regex que confirma sucesso na resposta (default: pong)
#   INTERVAL        - intervalo entre tentativas em segundos (default: 120)
#   REQ_TIMEOUT     - timeout por requisição curl em segundos (default: 60)
# Comportamento: loop infinito (até sucesso). Use systemd/timer se quiser limite/gerenciamento.

set -u

HOST="${HOST:-http://192.168.15.2:11434}"
MODEL="${MODEL:-qwen2.5-coder:1.5b}"
PROMPT="${PROMPT:-Responda apenas: pong}"
SUCCESS_PATTERN="${SUCCESS_PATTERN:-pong}"
INTERVAL="${INTERVAL:-120}"
REQ_TIMEOUT="${REQ_TIMEOUT:-60}"
MAX_TOKENS="${MAX_TOKENS:-16}"
QUIET="${QUIET:-0}"
# DB write options
DB_WRITE="${DB_WRITE:-0}"                    # se 1, tenta gravar resultados em Postgres (DATABASE_URL)
DATABASE_URL="${DATABASE_URL:-}"             # p.ex. postgresql://user:pass@host:5432/dbname
SERVICE_NAME="${SERVICE_NAME:-ollama_health_check}"

log(){
  printf "%s %s\n" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

psql_write(){
  # psql aceita a connection string como primeiro argumento
  local sql="$1"
  if [ "$DB_WRITE" != "1" ]; then
    return 0
  fi
  if [ -z "${DATABASE_URL}" ]; then
    log "DB_WRITE habilitado mas DATABASE_URL não informado; ignorando gravação em DB."
    return 1
  fi
  if ! command -v psql >/dev/null 2>&1; then
    log "psql não encontrado; não foi possível gravar em DB."
    return 1
  fi
  PGPASSWORD="" psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "$sql" 2>/dev/null || {
    log "Falha ao executar SQL no banco de dados (verifique DATABASE_URL e permissões)."
    return 1
  }
  return 0
}

write_check(){
  # write_check <status:true|false> <http_code> <message_snippet>
  local status="$1"; shift
  local http_code="$1"; shift
  local snippet="$*"
  # criar tabela se necessário
  local create_sql="CREATE TABLE IF NOT EXISTS service_checks (id SERIAL PRIMARY KEY, service_name TEXT NOT NULL, status BOOLEAN NOT NULL, checked_at TIMESTAMPTZ DEFAULT now(), http_code TEXT, details JSONB);"
  psql_write "$create_sql" >/dev/null 2>&1 || true
  # inserir
  local details
  details=$(printf '{"snippet":"%s"}' "${snippet//"/\"}")
  local insert_sql="INSERT INTO service_checks(service_name,status,http_code,details) VALUES('"$SERVICE_NAME"', $status, '"$http_code"', '$details'::jsonb);"
  psql_write "$insert_sql" >/dev/null 2>&1 || true
}

cleanup(){
  [ -n "${TMP_RESPONSE:-}" ] && rm -f "$TMP_RESPONSE" || true
}
trap cleanup EXIT

log "Iniciando monitoramento: host=$HOST model=$MODEL interval=${INTERVAL}s timeout=${REQ_TIMEOUT}s DB_WRITE=${DB_WRITE} service=${SERVICE_NAME}"

while true; do
  TMP_RESPONSE=$(mktemp)
  log "Enviando teste -> model=$MODEL"

  http_code=$(curl -sS -m "$REQ_TIMEOUT" -X POST "$HOST/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":$MAX_TOKENS,\"temperature\":0.0}" \
    -w "%{http_code}" -o "$TMP_RESPONSE" 2>/dev/null) || http_code=000

  if [ "$http_code" = "200" ] && [ -s "$TMP_RESPONSE" ]; then
    if grep -i -E "$SUCCESS_PATTERN" "$TMP_RESPONSE" >/dev/null 2>&1; then
      log "SUCESSO: padrão '$SUCCESS_PATTERN' detectado no response (HTTP 200)."
      [ "$QUIET" != "1" ] && head -c 1024 "$TMP_RESPONSE" | sed -n '1,40p'
      # gravar sucesso no DB (opcional)
      write_check true "$http_code" "$(head -c 200 "$TMP_RESPONSE" | tr -d '\n' | sed 's/\'/\'"'"'"/g')"
      cleanup
      exit 0
    else
      log "HTTP 200 mas padrão '$SUCCESS_PATTERN' NÃO encontrado. Conteúdo truncado:"; head -c 512 "$TMP_RESPONSE" | sed -n '1,20p'
      write_check false "$http_code" "pattern-not-found: $(head -c 200 "$TMP_RESPONSE" | tr -d '\n')"
    fi
  else
    log "Falha na requisição (HTTP=$http_code) — aguardar ${INTERVAL}s antes da próxima tentativa."
    [ -s "$TMP_RESPONSE" ] && { log "Resposta (trunc):"; head -c 512 "$TMP_RESPONSE" | sed -n '1,20p'; }
    write_check false "$http_code" "request-failed"
  fi

  cleanup
  sleep "$INTERVAL"
done
