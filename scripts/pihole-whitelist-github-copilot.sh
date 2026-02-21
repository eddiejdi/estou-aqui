#!/bin/bash
###############################################################################
# Pi-hole Whitelist - GitHub Copilot
# Adiciona domínios essenciais do GitHub Copilot à whitelist do Pi-hole
###############################################################################
set -euo pipefail

HOMELAB_HOST="${HOMELAB_HOST:-192.168.15.2}"
HOMELAB_USER="${HOMELAB_USER:-homelab}"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Pi-hole Whitelist - GitHub Copilot                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Domínios essenciais do GitHub Copilot
DOMAINS=(
  "default.exp-tas.com"           # Telemetria/Analytics (CRÍTICO)
  "api.githubcopilot.com"         # API principal
  "copilot-proxy.githubusercontent.com"  # Proxy
  "vscode-auth.github.com"        # Autenticação
  "github.com"                    # GitHub principal
  "api.github.com"                # API GitHub
  "*.github.io"                   # GitHub Pages
)

echo -e "${YELLOW}🔍 Verificando conectividade com Pi-hole...${NC}"
if ! ssh -o ConnectTimeout=5 "${HOMELAB_USER}@${HOMELAB_HOST}" 'exit' 2>/dev/null; then
  echo -e "❌ Erro: Não foi possível conectar ao homelab ($HOMELAB_HOST)"
  exit 1
fi
echo -e "${GREEN}✓ Conectado ao homelab${NC}"
echo ""

echo -e "${YELLOW}🔧 Adicionando domínios à whitelist do Pi-hole...${NC}"
for domain in "${DOMAINS[@]}"; do
  echo -n "   - $domain ... "
  
  if ssh "${HOMELAB_USER}@${HOMELAB_HOST}" \
    "docker exec pihole pihole allow '$domain'" &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${YELLOW}⚠${NC} (já existe ou erro)"
  fi
done
echo ""

echo -e "${YELLOW}🧪 Testando resolução DNS...${NC}"
echo ""

# Função para testar DNS
test_dns() {
  local domain="$1"
  local result
  
  result=$(dig "@${HOMELAB_HOST}" "$domain" +short 2>/dev/null | head -1)
  
  if [[ -n "$result" && "$result" != "0.0.0.0" ]]; then
    echo -e "   ${GREEN}✓${NC} $domain → $result"
    return 0
  else
    echo -e "   ${YELLOW}⚠${NC} $domain → bloqueado ou não existe"
    return 1
  fi
}

# Testar domínios críticos
CRITICAL_DOMAINS=(
  "github.com"
  "api.github.com"
  "default.exp-tas.com"
  "api.githubcopilot.com"
)

echo -e "${BLUE}Domínios críticos:${NC}"
for domain in "${CRITICAL_DOMAINS[@]}"; do
  test_dns "$domain"
done
echo ""

echo -e "${GREEN}✨ Concluído!${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Agora teste o GitHub Copilot no VS Code:"
echo -e "  1. Remova o DNS secundário da configuração de rede (opcional)"
echo -e "  2. Verifique o status do Copilot no VS Code"
echo -e "  3. Teste autocompletar código em um arquivo Python/JS"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Exibir comando útil para debug
echo -e "${YELLOW}💡 Debug DNS:${NC}"
echo -e "   dig @${HOMELAB_HOST} default.exp-tas.com +short"
echo ""
