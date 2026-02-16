#!/bin/bash
#############################################################################
# Alert Integration Configuration
# Configura o AlertManager para enviar webhooks para o backend do estou-aqui
#############################################################################

set -e

HOMELAB_HOST="${HOMELAB_HOST:-192.168.15.2}"
ALERTMANAGER_CONFIG="/etc/alertmanager/alertmanager.yml"

echo "📋 === Alert Integration Setup === 📋"
echo ""

# 1. Backup da configuração atual
echo "1️⃣ Fazendo backup da configuração atual..."
sudo cp "$ALERTMANAGER_CONFIG" "$ALERTMANAGER_CONFIG.backup.$(date +%s)"
echo "   ✅ Backup criado"

# 2. Atualizar configuração do AlertManager
echo ""
echo "2️⃣ Atualizando configuração do AlertManager..."
echo "   Adicionando webhook para: http://localhost:3000/api/alerts/webhook"

sudo tee "$ALERTMANAGER_CONFIG" > /dev/null << 'EOFCONFIG'
global:
  resolve_timeout: 5m
  slack_api_url: ''
  pagerduty_url: 'https://events.pagerduty.com/v2/enqueue'
  opsgenie_api_url: 'https://api.opsgenie.com/'
  wechat_api_url: 'https://qyapi.weixin.qq.com/cgi-bin/'
  victorops_api_url: 'https://alert.victorops.com/integrations/generic/20131114/alert/'
  telegram_api_url: 'https://api.telegram.org'
  webex_api_url: 'https://webexapis.com/v1/messages'
  templates: []

templates: []

route:
  receiver: default
  group_by:
    - alertname
    - severity
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  routes: []

inhibit_rules: []

receivers:
  - name: default
    webhook_configs:
      # Webhook para o Agent API (Eddie)
      - url: http://127.0.0.1:8503/alerts
        send_resolved: true
        http_sd_configs: []
        oauth2_config:
          client_id: ''
          client_secret: ''
          endpoint_params: {}
          scopes: []
          token_url: ''
        proxy_url: ''
        tls_config:
          insecure_skip_verify: false
        bearer_token: ''
        bearer_token_file: ''
      # Webhook para o Estou Aqui Backend (Real-time alerts nos painéis)
      - url: http://localhost:3000/api/alerts/webhook
        send_resolved: true
        http_sd_configs: []
        oauth2_config:
          client_id: ''
          client_secret: ''
          endpoint_params: {}
          scopes: []
          token_url: ''
        proxy_url: ''
        tls_config:
          insecure_skip_verify: false
        bearer_token: ''
        bearer_token_file: ''
EOFCONFIG

echo "   ✅ Configuração atualizada"

# 3. Validar configuração YAML
echo ""
echo "3️⃣ Validando configuração..."
if command -v amtool &> /dev/null; then
  amtool config routes || echo "   ⚠️  amtool não disponível, mas continuando..."
else
  echo "   ℹ️  amtool não encontrado, pulando validação"
fi

# 4. Recarregar AlertManager
echo ""
echo "4️⃣ Recarregando AlertManager..."
sudo systemctl reload alertmanager
sleep 2
STATUS=$(sudo systemctl is-active alertmanager)

if [ "$STATUS" = "active" ]; then
  echo "   ✅ AlertManager recarregado com sucesso"
else
  echo "   ❌ AlertManager não está ativo!"
  echo "   Tentando reiniciar..."
  sudo systemctl restart alertmanager
  sleep 2
fi

# 5. Testar webhooks
echo ""
echo "5️⃣ Testando webhooks..."

echo "   • Testando Agent API (port 8503)..."
AGENT_API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8503/status || echo "000")
if [ "$AGENT_API_STATUS" = "200" ]; then
  echo "     ✅ Agent API respondendo"
else
  echo "     ⚠️  Agent API pode estar indisponível (status: $AGENT_API_STATUS)"
fi

echo "   • Testando Estou Aqui Backend (port 3000)..."
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health || echo "000")
if [ "$BACKEND_STATUS" = "200" ]; then
  echo "     ✅ Estou Aqui Backend respondendo"
else
  echo "     ⚠️  Estou Aqui Backend pode estar indisponível (status: $BACKEND_STATUS)"
fi

# 6. Exibir configuração final
echo ""
echo "6️⃣ Configuração final:"
echo "   Webhooks configurados:"
echo "   • http://127.0.0.1:8503/alerts (Agent API - Eddie)"
echo "   • http://localhost:3000/api/alerts/webhook (Estou Aqui Backend)"
echo ""
echo "   Endpoints disponíveis no Estou Aqui Backend:"
echo "   • GET  /api/alerts/active   - Alertas ativos no momento"
echo "   • GET  /api/alerts/history  - Histórico de alertas"
echo "   • GET  /api/alerts/stats    - Estatísticas de alertas"
echo "   • POST /api/alerts/webhook  - Recebe webhooks do AlertManager"
echo ""
echo "   Socket.io events (namespace /alerts):"
echo "   • alerts:update    - Atualização de alertas"
echo "   • alert:critical   - Alerta crítico disparado"
echo "   • alert:warning    - Alerta de aviso disparado"
echo ""
echo "✅ Alert Integration Setup CONCLUÍDO"
echo ""
echo "Próximas etapas:"
echo "1. Verificar logs: sudo journalctl -u alertmanager -f"
echo "2. Testar com: curl -X POST http://localhost:3000/api/alerts/webhook -H 'Content-Type: application/json' -d '{...}'"
echo "3. Adicionar painel no app para mostrar alertas via Socket.io"
