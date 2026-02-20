#!/bin/bash

# 🤖 MULTI-AGENT DASHBOARD — LINKS DE ACESSO
# ============================================

echo "🎯 PAINEL MULTI-AGENTE — ESTOU AQUI"
echo "===================================="
echo ""
echo "✅ SERVIÇO INICIADO COM SUCESSO"
echo ""

echo "📊 DASHBOARD LINKS:"
echo "  🎯 Principal  → http://192.168.15.2:8505/"
echo "  📈 API Health → http://192.168.15.2:8505/api/health"
echo "  📚 Docs       → http://192.168.15.2:8505/docs/integration"
echo ""

echo "🌐 SERVIÇOS RELACIONADOS:"
echo "  💬 Open WebUI    → http://192.168.15.2:8080"
echo "  🎛️  Coordinator  → http://192.168.15.2:8503"
echo "  🤖 Ollama        → http://192.168.15.2:11434"
echo "  📊 Streamlit     → http://192.168.15.2:8502"
echo ""

echo "🔌 INTEGRAÇÃO COM OPEN WEBUI:"
echo "  1. Acesse http://192.168.15.2:8080"
echo "  2. Settings → Functions → Create New"
echo "  3. Selecione: Web Interface / External Tool"
echo "  4. URL: http://192.168.15.2:8505/"
echo "  5. Salve e recarregue"
echo ""

echo "📋 FUNCIONALIDADES DO PAINEL:"
echo "  ✓ Status do Sistema (CPU, RAM, Timestamp)"
echo "  ✓ Communication Bus (Fila, Agentes Ativos)"
echo "  ✓ 8 Agentes Especializados (Python, JS, TS, Go, Rust, Java, C#, PHP)"
echo "  ✓ Tarefas em Execução (Com progresso em tempo real)"
echo "  ✓ Métricas da API (Requisições, Latência, Taxa de erro)"
echo ""

echo "🔄 ATUALIZAÇÃO AUTOMÁTICA:"
echo "  • Dashboard atualiza a cada 5 segundos"
echo "  • Clique em '🔄 Atualizar' para força imediata"
echo ""

echo "🛠️  GERENCIAR SERVIÇO:"
echo "  Reiniciar → ssh homelab@192.168.15.2 'pkill -f dashboard_server && sleep 2 && DASHBOARD_PORT=8505 nohup python3 /tmp/dashboard_server.py > /tmp/dashboard.log 2>&1 &'"
echo "  Status   → ssh homelab@192.168.15.2 'ps aux | grep dashboard_server'"
echo "  Logs     → ssh homelab@192.168.15.2 'tail -50 /tmp/dashboard_server_8505.log'"
echo ""

echo "📖 DOCUMENTAÇÃO COMPLETA:"
echo "  👉 /home/edenilson/eddie-auto-dev/estou-aqui/MULTI_AGENT_DASHBOARD_GUIDE.md"
echo ""

echo "⏰ TEMPO: $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo ""
echo "✨ Dashboard pronto para usar! 🚀"
