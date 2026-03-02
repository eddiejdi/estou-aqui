#!/bin/bash
# QUICKSTART: Deploy LLM-Optimizer v2.3
# Correção para: Cannot read properties of undefined (reading 'type')

echo "═══════════════════════════════════════════════════════════════════"
echo "LLM-Optimizer v2.3 — Deploy Quickstart"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "📋 Checklist pré-deploy:"
echo "  [1] Você tem acesso SSH ao homelab? (ssh homelab@192.168.15.2)"
echo "  [2] O serviço llm-optimizer está rodando? (sudo systemctl status llm-optimizer)"
echo "  [3] Quer fazer backup manual antes? (opcional)"
echo ""
read -p "Continuar com deploy? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deploy cancelado"
    exit 1
fi

echo ""
echo "🚀 Iniciando deploy..."
echo ""

# Validação local
echo "1️⃣ Validando arquivos locais..."
if [ ! -f "scripts/llm_optimizer_v2.3.py" ]; then
    echo "❌ Arquivo não encontrado: scripts/llm_optimizer_v2.3.py"
    exit 1
fi
echo "   ✓ llm_optimizer_v2.3.py"

if [ ! -f "scripts/test_llm_optimizer_contract.py" ]; then
    echo "❌ Arquivo não encontrado: scripts/test_llm_optimizer_contract.py"
    exit 1
fi
echo "   ✓ test_llm_optimizer_contract.py"

if [ ! -f "scripts/deploy_llm_optimizer.sh" ]; then
    echo "❌ Arquivo não encontrado: scripts/deploy_llm_optimizer.sh"
    exit 1
fi
echo "   ✓ deploy_llm_optimizer.sh"

# Validação sintática
echo ""
echo "2️⃣ Validando sintaxe Python..."
python3 -m py_compile scripts/llm_optimizer_v2.3.py scripts/test_llm_optimizer_contract.py
if [ $? -ne 0 ]; then
    echo "❌ Erro de sintaxe nos scripts Python"
    exit 1
fi
echo "   ✓ Sintaxe válida"

# Conectividade SSH
echo ""
echo "3️⃣ Validando conectividade SSH..."
if ! ssh -o ConnectTimeout=10 homelab@192.168.15.2 "echo OK" >/dev/null 2>&1; then
    echo "❌ Falha ao conectar via SSH: homelab@192.168.15.2"
    echo "   Verifique: ssh homelab@192.168.15.2"
    exit 1
fi
echo "   ✓ SSH conectado"

# Deploy
echo ""
echo "4️⃣ Executando deploy..."
./scripts/deploy_llm_optimizer.sh
DEPLOY_EXIT=$?

if [ $DEPLOY_EXIT -eq 0 ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "✅ Deploy concluído com sucesso!"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "📋 Próximos passos:"
    echo "  1. Teste o CLINE com uma requisição multimodal"
    echo "  2. Monitore os logs:"
    echo "     ssh homelab@192.168.15.2 'sudo journalctl -u llm-optimizer -f'"
    echo "  3. Verifique métricas:"
    echo "     curl http://192.168.15.2:8512/metrics | grep schema_errors"
    echo ""
    echo "🔍 Validação rápida:"
    echo "  curl http://192.168.15.2:8512/health | jq '.version'"
    echo "  # Deve retornar: \"2.3.0\""
    echo ""
else
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "❌ Deploy falhou (exit code: $DEPLOY_EXIT)"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "📋 Troubleshooting:"
    echo "  1. Verifique os logs acima"
    echo "  2. Veja o status do serviço:"
    echo "     ssh homelab@192.168.15.2 'sudo systemctl status llm-optimizer'"
    echo "  3. Veja logs do systemd:"
    echo "     ssh homelab@192.168.15.2 'sudo journalctl -u llm-optimizer -n 50'"
    echo ""
    exit 1
fi
