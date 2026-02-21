#!/bin/bash
###############################################################################
# Homelab Health Check - Teste de Ping e Conectividade
# Verifica todos os serviços essenciais do homelab
###############################################################################
set -euo pipefail

HOMELAB_HOST="${HOMELAB_HOST:-192.168.15.2}"
HOMELAB_USER="${HOMELAB_USER:-homelab}"
TIMEOUT=5

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Contadores
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Função de teste
check_service() {
  local name="$1"
  local test_cmd="$2"
  
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  echo -n "   ${name}... "
  if eval "$test_cmd" &>/dev/null; then
    echo -e "${GREEN}✅ OK${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  else
    echo -e "${RED}❌ FALHOU${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    return 1
  fi
}

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         HOMELAB HEALTH CHECK - PING & CONECTIVIDADE       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}⏱️  Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')${NC}"
echo -e "${CYAN}🖥️  Host: ${HOMELAB_HOST}${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}┌─────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}│ REDE                                                        │${NC}"
echo -e "${BOLD}└─────────────────────────────────────────────────────────────┘${NC}"

check_service "Ping ICMP" "ping -c 1 -W $TIMEOUT $HOMELAB_HOST"
check_service "SSH" "ssh -o ConnectTimeout=$TIMEOUT -o StrictHostKeyChecking=no ${HOMELAB_USER}@${HOMELAB_HOST} 'exit'"

echo ""

# ─────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}┌─────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}│ SERVIÇOS API                                                │${NC}"
echo -e "${BOLD}└─────────────────────────────────────────────────────────────┘${NC}"

check_service "Agent Bus (8503)" "curl -sf --connect-timeout $TIMEOUT http://${HOMELAB_HOST}:8503/health"
check_service "Secrets Agent (8088)" "curl -sf --connect-timeout $TIMEOUT http://${HOMELAB_HOST}:8088/secrets"
check_service "Ollama LLM (11434)" "curl -sf --connect-timeout $TIMEOUT http://${HOMELAB_HOST}:11434/api/tags"

echo ""

# ─────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}┌─────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}│ INFRAESTRUTURA                                              │${NC}"
echo -e "${BOLD}└─────────────────────────────────────────────────────────────┘${NC}"

check_service "Pi-hole DNS Container" "ssh -o ConnectTimeout=$TIMEOUT ${HOMELAB_USER}@${HOMELAB_HOST} 'docker ps --filter name=pihole --filter status=running -q'"
check_service "DNS Resolution (github.com)" "dig @${HOMELAB_HOST} github.com +short +timeout=2"
check_service "DNS Copilot (default.exp-tas.com)" "dig @${HOMELAB_HOST} default.exp-tas.com +short +timeout=2 | grep -v '^0.0.0.0$'"

echo ""

# ─────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}┌─────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}│ RESUMO                                                      │${NC}"
echo -e "${BOLD}└─────────────────────────────────────────────────────────────┘${NC}"

echo -e "   Total de verificações: ${BOLD}${TOTAL_CHECKS}${NC}"
echo -e "   ${GREEN}Sucesso: ${PASSED_CHECKS}${NC}"
echo -e "   ${RED}Falhas: ${FAILED_CHECKS}${NC}"
echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
  echo -e "${GREEN}${BOLD}🟢 TODOS OS SERVIÇOS OPERACIONAIS${NC}"
  echo ""
  exit 0
elif [ $FAILED_CHECKS -le 2 ]; then
  echo -e "${YELLOW}${BOLD}🟡 ALGUNS SERVIÇOS COM PROBLEMAS${NC}"
  echo ""
  exit 1
else
  echo -e "${RED}${BOLD}🔴 MÚLTIPLAS FALHAS DETECTADAS${NC}"
  echo ""
  exit 2
fi
