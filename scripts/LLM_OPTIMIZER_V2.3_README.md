# LLM-Optimizer v2.3 — Correção do erro "Cannot read properties of undefined (reading 'type')"

## Problema

CLINE retornava erro `Cannot read properties of undefined (reading 'type')` ao enviar mensagens multimodais (content array) para o proxy LLM-Optimizer.

## Solução

A v2.3 implementa **guards defensivos** e **validação de schema** em 3 camadas:

### 1. Sanitização robusta (`safe_get_content_text`)
```python
# ✅ ANTES: acessava item['type'] sem validar
for item in content:
    if item['type'] == 'text':  # ❌ ERRO se item não é dict ou não tem 'type'
        parts.append(item['text'])

# ✅ DEPOIS: valida antes de acessar
for item in content:
    if not isinstance(item, dict):
        logger.warning(f"Item não é dict: {type(item)}")
        continue
    
    if "type" not in item:
        logger.warning(f"Item sem 'type': {item.keys()}")
        continue
    
    # Agora sim é seguro acessar item['type']
    if item["type"] == "text" and "text" in item:
        parts.append(item["text"])
```

### 2. Validação de schema OpenAI (`validate_openai_response`)
Garante que toda resposta tenha:
- `choices` (list, len > 0)
- `choices[0].message.role` (str)
- `choices[0].message.content` (str ou null)
- `model`, `created`, `object`

Se faltar algum campo → cria resposta fallback válida.

### 3. Fallback para erros (`create_fallback_response`)
Em caso de exceção, retorna resposta válida:
```json
{
  "choices": [{
    "message": {
      "role": "assistant",
      "content": "[LLM-Optimizer Error] ..."
    }
  }]
}
```

## Arquivos

| Arquivo | Descrição |
|---------|-----------|
| `scripts/llm_optimizer_v2.3.py` | Proxy completo com correções |
| `scripts/test_llm_optimizer_contract.py` | Suite de testes (3 casos críticos) |
| `scripts/deploy_llm_optimizer.sh` | Deploy automatizado com backup |

## Deploy

### 1. Rodar testes localmente (opcional)
```bash
# Iniciar proxy local para testes
cd /home/edenilson/eddie-auto-dev/estou-aqui
python3 scripts/llm_optimizer_v2.3.py &
PROXY_PID=$!

# Executar testes
python3 scripts/test_llm_optimizer_contract.py

# Parar proxy
kill $PROXY_PID
```

### 2. Deploy no homelab
```bash
# Deploy completo (com testes)
./scripts/deploy_llm_optimizer.sh

# Dry-run (simula sem executar)
DRY_RUN=1 ./scripts/deploy_llm_optimizer.sh

# Skip testes pós-deploy
SKIP_TESTS=1 ./scripts/deploy_llm_optimizer.sh
```

O script de deploy:
1. ✅ Valida conectividade SSH
2. ✅ Cria backup da versão atual
3. ✅ Faz upload da v2.3
4. ✅ Valida sintaxe Python
5. ✅ Reinicia serviço systemd
6. ✅ Aguarda estabilização (5s)
7. ✅ Executa health check
8. ✅ Roda testes de contrato
9. ✅ Mostra instruções de rollback

### 3. Validar no CLINE

Após deploy, testar no CLINE com uma requisição real:
1. Abrir VS Code com CLINE
2. Enviar prompt que gere tool-calling
3. Verificar que não há erro de `type`

Monitorar logs:
```bash
ssh homelab@192.168.15.2 'sudo journalctl -u llm-optimizer -f'
```

## Rollback (se necessário)

```bash
ssh homelab@192.168.15.2
cd /home/homelab/llm-optimizer
ls -lt llm_optimizer.py.bak.*  # listar backups
cp llm_optimizer.py.bak.v2.2.YYYYMMDD_HHMMSS llm_optimizer.py
sudo systemctl restart llm-optimizer
```

## Testes de Contrato

A suite `test_llm_optimizer_contract.py` valida 3 casos críticos:

### Teste 1: Content string simples
✓ Baseline — deve sempre funcionar

### Teste 2: Content array multimodal
✓ **Gatilho do bug original**  
Envia:
```json
{
  "content": [
    {"type": "text", "text": "Descreva a imagem"},
    {"type": "image_url", "image_url": {"url": "..."}}
  ]
}
```

### Teste 3: Role 'tool' (CLINE tool-calling)
✓ Normalização de roles inválidos  
Envia:
```json
{
  "role": "tool",
  "tool_call_id": "call_123",
  "content": "resultado..."
}
```

## Métricas Prometheus

Novas métricas v2.3:
```promql
# Erros de schema por tipo
llm_optimizer_schema_errors_total{error_type="missing_choices"}
llm_optimizer_schema_errors_total{error_type="missing_content"}
llm_optimizer_schema_errors_total{error_type="not_dict"}
```

## Documentação

- [docs/LLM_OPTIMIZER.md](../docs/LLM_OPTIMIZER.md) — documentação completa atualizada para v2.3
- [.github/copilot-instructions.md](../.github/copilot-instructions.md) — configuração CLINE

## Checklist de Validação

- [ ] Deploy executado com sucesso
- [ ] Health check retorna `"version": "2.3.0"`
- [ ] 3/3 testes de contrato passaram
- [ ] CLINE executa requisição real sem erro
- [ ] Métricas acessíveis em http://192.168.15.2:8512/metrics
- [ ] Logs não mostram erros de schema

## Próximos Passos

1. Monitorar logs por 24h para validar estabilidade
2. Registrar métricas `schema_errors_total` — deve ficar em 0
3. Se tudo OK, considerar merge para `main`
4. Documentar lições aprendidas

## Lições Aprendidas

1. **Nunca acesse propriedades sem validar existência** — `item['type']` precisa de guard
2. **Validação de schema é obrigatória** — payloads podem vir incompletos
3. **Fallback > crash** — sempre retornar resposta válida, mesmo em erro
4. **Testes de contrato são essenciais** — cobrir casos extremos (multimodal, roles inválidos)
5. **Deploy deve ser idempotente** — backup automático + rollback fácil
