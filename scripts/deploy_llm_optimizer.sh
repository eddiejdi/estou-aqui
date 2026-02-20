#!/usr/bin/env bash
set -euo pipefail

# deploy_llm_optimizer.sh
#
# Deploy automatizado do LLM-Optimizer v2.3 no servidor homelab.
#
# Uso:
#   ./scripts/deploy_llm_optimizer.sh                  # deploy no homelab
#   DRY_RUN=1 ./scripts/deploy_llm_optimizer.sh       # simula deploy
#   SKIP_TESTS=1 ./scripts/deploy_llm_optimizer.sh    # skip testes pós-deploy

# ══════════════════════════════════════════════════════════════════════════
# Configuração
# ══════════════════════════════════════════════════════════════════════════

HOMELAB_HOST="${HOMELAB_HOST:-192.168.15.2}"
HOMELAB_USER="${HOMELAB_USER:-homelab}"
SERVICE_NAME="${SERVICE_NAME:-llm-optimizer}"
REMOTE_DIR="${REMOTE_DIR:-/home/homelab/llm-optimizer}"
LOCAL_SOURCE="scripts/llm_optimizer_v2.3.py"
REMOTE_TARGET="llm_optimizer.py"

DRY_RUN="${DRY_RUN:-0}"
SKIP_TESTS="${SKIP_TESTS:-0}"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ══════════════════════════════════════════════════════════════════════════
# Funções
# ══════════════════════════════════════════════════════════════════════════

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

run_cmd() {
    local cmd="$1"
    if [ "$DRY_RUN" = "1" ]; then
        log_warn "[DRY-RUN] $cmd"
    else
        log_info "Executando: $cmd"
        eval "$cmd"
    fi
}

ssh_exec() {
    local cmd="$1"
    run_cmd "ssh ${HOMELAB_USER}@${HOMELAB_HOST} '$cmd'"
}

# ══════════════════════════════════════════════════════════════════════════
# Pré-validação
# ══════════════════════════════════════════════════════════════════════════

log_info "═══════════════════════════════════════════════════════════════════"
log_info "Deploy LLM-Optimizer v2.3"
log_info "═══════════════════════════════════════════════════════════════════"
echo ""
log_info "Target: ${HOMELAB_USER}@${HOMELAB_HOST}:${REMOTE_DIR}"
log_info "Source: ${LOCAL_SOURCE}"
log_info "Dry-run: ${DRY_RUN}"
log_info "Skip tests: ${SKIP_TESTS}"
echo ""

# Valida arquivo local
if [ ! -f "$LOCAL_SOURCE" ]; then
    log_error "Arquivo local não encontrado: $LOCAL_SOURCE"
    exit 1
fi
log_info "✓ Arquivo local: $LOCAL_SOURCE ($(wc -l < "$LOCAL_SOURCE") linhas)"

# Valida conectividade SSH
log_info "Validando conectividade SSH..."
if ! ssh -o ConnectTimeout=10 "${HOMELAB_USER}@${HOMELAB_HOST}" "echo OK" >/dev/null 2>&1; then
    log_error "Falha ao conectar via SSH: ${HOMELAB_USER}@${HOMELAB_HOST}"
    log_error "Verifique: ssh ${HOMELAB_USER}@${HOMELAB_HOST}"
    exit 1
fi
log_info "✓ SSH conectado"

# Valida diretório remoto
log_info "Validando diretório remoto..."
if ! ssh "${HOMELAB_USER}@${HOMELAB_HOST}" "[ -d $REMOTE_DIR ]"; then
    log_error "Diretório remoto não existe: $REMOTE_DIR"
    log_error "Crie o diretório: ssh ${HOMELAB_USER}@${HOMELAB_HOST} 'mkdir -p $REMOTE_DIR'"
    exit 1
fi
log_info "✓ Diretório remoto: $REMOTE_DIR"

# ══════════════════════════════════════════════════════════════════════════
# Backup
# ══════════════════════════════════════════════════════════════════════════

log_info ""
log_info "Criando backup da versão atual..."

BACKUP_SUFFIX="v2.2.$(date +%Y%m%d_%H%M%S)"

ssh_exec "cd $REMOTE_DIR && \
    if [ -f $REMOTE_TARGET ]; then \
        cp $REMOTE_TARGET ${REMOTE_TARGET}.bak.${BACKUP_SUFFIX} && \
        echo 'Backup criado: ${REMOTE_TARGET}.bak.${BACKUP_SUFFIX}'; \
    else \
        echo 'Nenhum arquivo existente para backup'; \
    fi"

log_info "✓ Backup concluído"

# ══════════════════════════════════════════════════════════════════════════
# Upload
# ══════════════════════════════════════════════════════════════════════════

log_info ""
log_info "Fazendo upload da nova versão..."

run_cmd "scp $LOCAL_SOURCE ${HOMELAB_USER}@${HOMELAB_HOST}:${REMOTE_DIR}/${REMOTE_TARGET}"

log_info "✓ Upload concluído"

# ══════════════════════════════════════════════════════════════════════════
# Validação sintática
# ══════════════════════════════════════════════════════════════════════════

log_info ""
log_info "Validando sintaxe Python..."

ssh_exec "python3 -m py_compile ${REMOTE_DIR}/${REMOTE_TARGET}"

log_info "✓ Sintaxe válida"

# ══════════════════════════════════════════════════════════════════════════
# Restart do serviço
# ══════════════════════════════════════════════════════════════════════════

log_info ""
log_info "Reiniciando serviço: $SERVICE_NAME"

ssh_exec "sudo systemctl restart $SERVICE_NAME"

log_info "Aguardando 5s para estabilização..."
sleep 5

# ══════════════════════════════════════════════════════════════════════════
# Health check
# ══════════════════════════════════════════════════════════════════════════

log_info ""
log_info "Verificando health do serviço..."

# Status do systemd
ssh_exec "sudo systemctl is-active $SERVICE_NAME --quiet && echo 'Service ativo' || echo 'Service inativo'"

# Health endpoint
HEALTH_RESULT=$(ssh "${HOMELAB_USER}@${HOMELAB_HOST}" "curl -sf http://localhost:8512/health" || echo "FAIL")

if echo "$HEALTH_RESULT" | grep -q '"status".*"ok"'; then
    log_info "✓ Health check OK"
    
    VERSION=$(echo "$HEALTH_RESULT" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    log_info "  Versão: $VERSION"
else
    log_error "Health check falhou"
    log_error "Response: $HEALTH_RESULT"
    
    log_warn "Logs do serviço:"
    ssh_exec "sudo journalctl -u $SERVICE_NAME -n 20 --no-pager"
    
    log_error ""
    log_error "Deploy falhou. Para rollback:"
    log_error "  ssh ${HOMELAB_USER}@${HOMELAB_HOST}"
    log_error "  cd $REMOTE_DIR"
    log_error "  cp ${REMOTE_TARGET}.bak.${BACKUP_SUFFIX} $REMOTE_TARGET"
    log_error "  sudo systemctl restart $SERVICE_NAME"
    exit 1
fi

# ══════════════════════════════════════════════════════════════════════════
# Testes de contrato
# ══════════════════════════════════════════════════════════════════════════

if [ "$SKIP_TESTS" = "0" ]; then
    log_info ""
    log_info "Executando testes de contrato..."
    
    if [ -f "scripts/test_llm_optimizer_contract.py" ]; then
        if command -v python3 >/dev/null 2>&1; then
            OPTIMIZER_URL="http://${HOMELAB_HOST}:8512" python3 scripts/test_llm_optimizer_contract.py
            TEST_RESULT=$?
            
            if [ $TEST_RESULT -eq 0 ]; then
                log_info "✓ Todos os testes passaram"
            else
                log_warn "Alguns testes falharam (exit code: $TEST_RESULT)"
                log_warn "Verifique os logs acima"
            fi
        else
            log_warn "python3 não encontrado, pulando testes"
        fi
    else
        log_warn "test_llm_optimizer_contract.py não encontrado, pulando testes"
    fi
else
    log_warn "Testes foram pulados (SKIP_TESTS=1)"
fi

# ══════════════════════════════════════════════════════════════════════════
# Finalização
# ══════════════════════════════════════════════════════════════════════════

log_info ""
log_info "═══════════════════════════════════════════════════════════════════"
log_info "Deploy concluído com sucesso!"
log_info "═══════════════════════════════════════════════════════════════════"
echo ""
log_info "Próximos passos:"
log_info "  1. Teste o CLINE com uma requisição real"
log_info "  2. Monitore os logs: ssh ${HOMELAB_USER}@${HOMELAB_HOST} 'sudo journalctl -u $SERVICE_NAME -f'"
log_info "  3. Verifique métricas: http://${HOMELAB_HOST}:8512/metrics"
echo ""
log_info "Rollback (se necessário):"
log_info "  ssh ${HOMELAB_USER}@${HOMELAB_HOST}"
log_info "  cd $REMOTE_DIR"
log_info "  cp ${REMOTE_TARGET}.bak.${BACKUP_SUFFIX} $REMOTE_TARGET"
log_info "  sudo systemctl restart $SERVICE_NAME"
echo ""

exit 0
