# LLM-Optimizer v2.3 — OpenAI-compatible Proxy para Ollama

**Data:** 20 de fevereiro de 2026  
**Status:** ✅ Produção  
**Porta:** 8512  
**Versão:** 2.3.0  

## Visão Geral

O LLM-Optimizer é um proxy FastAPI que encaminha requisições OpenAI-compatible para o Ollama, aplicando estratégias inteligentes de otimização baseadas no tamanho do contexto. Especialmente desenvolvido para **suportar CLINE com tool-calling** via qwen3:4b.

```
CLINE → http://192.168.15.2:8512/v1 → LLM-Optimizer → Ollama :11434
                    ↓
    [Estratégia de Otimização]
    ├─ A: < 2000 tokens → qwen3:4b (direto)
    ├─ B: 2000-6000 tokens → qwen3:0.6b (modelo leve + mais rápido)
    └─ C: > 6000 tokens → Map-Reduce paralelo (qwen3:0.6b MAP + qwen3:4b REDUCE)
                    ↓
    [Smart Truncation para Tool-Calling]
    ├─ Preserva tool definitions (CLINE XML tags)
    ├─ Sanitiza content array → string (multimodal)
    └─ Converte roles inválidos → suportados pelo Ollama
```

## Histórico de Versões

### v2.3.0 (20 fev 2026 — Correção crítica)
**Problema resolvido:**
- 🐛 **Cannot read properties of undefined (reading 'type')** em mensagens multimodais

**Correções implementadas:**
- ✅ Guards defensivos em `safe_get_content_text()` — valida `item['type']` antes de acessar
- ✅ Validação de schema OpenAI em `validate_openai_response()` — garante campos obrigatórios
- ✅ Fallback robusto com `create_fallback_response()` — resposta válida mesmo em erro
- ✅ Logging estruturado de erros de schema (`schema_errors` metric)
- ✅ Tratamento de items nulos/inválidos em content arrays

**Testes de contrato:**
- ✅ Content string simples
- ✅ Content array multimodal (gatilho do bug original)
- ✅ Role tool/function (CLINE tool-calling)

**Deploy:**
```bash
./scripts/deploy_llm_optimizer.sh
```

**Arquivos:**
- `scripts/llm_optimizer_v2.3.py` — proxy completo
- `scripts/test_llm_optimizer_contract.py` — suite de testes
- `scripts/deploy_llm_optimizer.sh` — deploy automatizado

### v2.2.0 (Produção — 20 fev 2026)
**Melhorias:**
- ✅ Timeouts aumentados: `600s → 1200s` (20 min max)
- ✅ `timeout_keep_alive` configurado no Uvicorn
- ✅ Suporte para requisições complex do CLINE (MAP-Reduce com 3+ chunks)
- ✅ Sincronizado com CLINE timeout: `1.200.000 ms`

**Testes:**
- ✅ Req 1: fallback direto (5 min) → resposta com tool-calling
- ✅ Req 2: Map-Reduce 1 chunk (15 min) → resposta com tool-calling
- ✅ Req 3: Map-Reduce 3 chunks (6.5 min) → resposta com tool-calling

**Métricas acumuladas:**
- 5 requisições bem-sucedidas
- 0 erros (400/500)
- 76.337 tokens salvos
- 5/5 tool-calling detectados
- 9 smart truncations executadas

### v2.1.0 (20 fev 2026 15:28)
**Melhorias:**
- ✅ Sanitização de mensagens CLINE
- ✅ Content array → string (multimodal support)
- ✅ Roles inválidos → user/assistant
- ✅ Error logging melhorado (body do erro 400)
- ✅ Strategy A streaming sanitizado
- ✅ Fix: 400 Bad Request resolvido

**Diagnóstico:**
- Problema: Ollama retornava 400 porque CLINE envia campos extras (tool_calls, roles=tool, content=array)
- Solução: sanitize_messages() limpa payload antes de enviar ao Ollama
- Resultado: 100% de sucesso nas 3 requisições teste

### v2.0.0 (20 fev 2026 14:56)
**Melhorias iniciais:**
- ✅ Smart truncation com preservação de tool definitions
- ✅ REDUCE usa qwen3:4b (foi 0.6b)
- ✅ Tool-calling detection automático
- ✅ Limites de truncamento aumentados (6k → 8k+ chars)
- ✅ Prometheus /metrics endpoint
- ✅ Contexto num_ctx aumentado: 4096 → 8192

## Configuração

### Instalação
```bash
# Já instalado em /home/homelab/llm-optimizer/
# Dependências:
pip install fastapi uvicorn httpx pydantic prometheus-client
```

### Systemd Service
```ini
[Unit]
Description=LLM Optimizer Proxy for Ollama
After=network.target

[Service]
Type=notify
User=homelab
WorkingDirectory=/home/homelab/llm-optimizer
ExecStart=/home/homelab/llm-optimizer/venv/bin/python llm_optimizer.py
Restart=always
RestartSec=5
SyslogIdentifier=llm-optimizer

[Install]
WantedBy=multi-user.target
```

### Endpoints
| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/v1/chat/completions` | POST | ChatCompletion OpenAI-compatible |
| `/v1/models` | GET | Lista modelos disponíveis |
| `/health` | GET | Health check + versão + stats |
| `/metrics` | GET | Prometheus metrics (text/plain) |

### CLINE Configuration
**Arquivo:** `~/.cline/data/globalState.json`

```json
{
  "openAiBaseUrl": "http://192.168.15.2:8512/v1",
  "actModeOpenAiModelId": "qwen3:4b",
  "planModeOpenAiModelId": "qwen3:4b",
  "actModeApiProvider": "openai",
  "ollamaApiOptionsCtxNum": 8192,
  "requestTimeoutMs": 1200000
}
```

## Estratégias de Otimização

### Strategy A: Direto (< 2000 tokens)
- Modelo: `qwen3:4b`
- Contexto: 8192 tokens
- Timeout: 10 min

**Exemplo:** Requisição simples do CLINE.

### Strategy B: Modelo Leve (2-6K tokens)
- Modelo: `qwen3:0.6b` (troca do 4b)
- Contexto: 8192 tokens
- Timeout: 10 min
- **Benefício:** CPU mais rápido, tokens salvos

**Exemplo:** 5000 tokens → usa 0.6b (mais rápido).

### Strategy C: Map-Reduce Paralelo (> 6K tokens)
1. **MAP** — Sumariza chunks em paralelo com `qwen3:0.6b`
   - Até 4 workers paralelos
   - ~30-60s por chunk (CPU-only)

2. **REDUCE** — Sintetiza com `qwen3:4b` usando resumos
   - Contexto: 8192 tokens
   - Smart truncation preserva tool definitions
   - ~5-10 min

**Exemplo:** 17.5K tokens (4 mensagens) → MAP 3 chunks + REDUCE.

## Smart Truncation (v2.1+)

Problema: CLINE envia ~54K char system prompt → truncamento naive perde tool definitions → modelo não sabe gerar tool-calling válido.

Solução: Truncamento inteligente que:
1. **Preserva início** (identidade) — 40% do budget
2. **Preserva tool definitions** — 30% do budget
   - Detecta: `<tool_name>`, `execute_command`, `read_file`, etc.
   - Regex patterns para encontrar blocos `## Tools` ou `<tools>`
3. **Preserva fim** (instruções de saída) — 30% do budget

**Resultado:** 64.356 chars → 8.444 chars com 100% das definições de tool intactas.

## Sanitização de Mensagens (v2.1+)

CLINE envia mensagens em formato multimodal (não suportado pelo Ollama):
```json
{
  "role": "tool",  // Inválido para Ollama
  "content": [     // Array, não string
    {"type":"text", "text":"..."},
    {"type":"image_url", "url":"..."}
  ],
  "tool_call_id": "..."  // Campo extra
}
```

Sanitização aplica:
```python
def sanitize_messages(messages: list) -> list:
    # 1. Converte roles inválidos: tool → user, function → user
    # 2. Converte content array → string
    # 3. Remove campos extras: só mantém role + content
    # 4. Resultado: formato Ollama-compatible
```

**Benefício:** 0 erros 400 Bad Request ✅

## Prometheus Metrics

Scrape config (adicionar a `/etc/prometheus/prometheus.yml`):
```yaml
- job_name: "llm-optimizer"
  static_configs:
    - targets: ["localhost:8512"]
  scrape_interval: 15s
  scrape_timeout: 10s
  metrics_path: "/metrics"
```

### Métricas expostas
| Métrica | Tipo | Descrição |
|---------|------|-----------|
| `llm_optimizer_requests_total{strategy}` | counter | Requests por strategy (A/B/C/all) |
| `llm_optimizer_errors_total` | counter | Total de erros |
| `llm_optimizer_tokens_saved_total` | counter | Tokens salvos via otimização |
| `llm_optimizer_dedup_hits_total` | counter | In-flight dedup cache hits |
| `llm_optimizer_tool_call_detected_total` | counter | Tool-calling requests detectados |
| `llm_optimizer_smart_truncations_total` | counter | Smart truncations executadas |
| `llm_optimizer_duration_seconds{strategy}` | gauge | Duração média por strategy |
| `llm_optimizer_up` | gauge | Service status (1=up, 0=down) |

### Exemplo de query Prometheus
```promql
# Total de requisições por strategy nos últimos 5min
rate(llm_optimizer_requests_total[5m]) by (strategy)

# Tokens economizados
llm_optimizer_tokens_saved_total

# Taxa de erro (deve ser 0)
rate(llm_optimizer_errors_total[5m])

# Duração média de requisições
llm_optimizer_duration_seconds
```

## Grafana Dashboard

**UID:** `homelab-session-monitor`  
**Versão:** 2 (atualizado com painéis v2)  
**Seções:**
1. 🤖 Status do LLM-Optimizer (4 stat panels)
2. 📊 Requests Timeline (Strategy A/B/C)
3. ⏱️ Duração por Strategy
4. 💾 Memória (cAdvisor)
5. 📝 Logs (Loki)

**Acesso:** http://192.168.15.2:3002 (admin:Eddie@2026)

## Troubleshooting

### Request timed out
**Cenário:** CLINE retorna "Request timed out" após 5-10 min.

**Causa:** Requisição grande (Map-Reduce) demorou mais que timeout CLINE + LLM-Optimizer.

**Solução:**
```bash
# CLINE timeout
sed -i 's/"requestTimeoutMs": [0-9]*/"requestTimeoutMs": 1200000/' ~/.cline/data/globalState.json

# LLM-Optimizer timeout (v2.2)
grep "TIMEOUT_EACH" /home/homelab/llm-optimizer/llm_optimizer.py
# Deve ser 1200 (segundos)

# Reiniciar
sudo systemctl restart llm-optimizer
```

### 400 Bad Request

**Cenário:** `[openai] 400 status code (no body)`

**Causa:** Mensagens CLINE com campos inválidos.

**Solução:** Usar v2.1+ que sanitiza automaticamente.

**Verificar:**
```bash
journalctl -u llm-optimizer -f | grep -E "400|sanitize|ERROR"
curl http://192.168.15.2:8512/health | jq '.version'
# Deve ser "2.1.0" ou superior
```

### Ollama crash

**Cenário:** Processo Ollama desaparece após requisição.

**Solução:**
```bash
# Reiniciar Ollama
sudo systemctl restart ollama

# Carregar modelo novamente
ssh homelab@192.168.15.2 'ollama pull qwen3:4b'
```

## Performance Esperada

| Estratégia | Tokens | Tempo | Modelo |
|-----------|--------|-------|--------|
| A | < 2K | 2-3 min | qwen3:4b |
| B | 2-6K | 2-4 min | qwen3:0.6b |
| C | > 6K | 10-15 min | MAP(0.6b) + REDUCE(4b) |

**Nota:** CPU-only no homelab. GPU aceleraria 3-5x.

## Desenvolvimento

### Build local
```bash
cd /home/homelab/llm-optimizer
python3 -m venv venv
source venv/bin/activate
pip install fastapi uvicorn httpx pydantic prometheus-client
python llm_optimizer.py
# Acesso: http://localhost:8512/health
```

### Backup de versões
```bash
ls -lh /home/homelab/llm-optimizer/llm_optimizer.py*
# llm_optimizer.py           (current)
# llm_optimizer.py.bak.v2    (v2.0 backup)
# llm_optimizer.py.bak.v2.1  (v2.1 backup)
```

### Rollback
```bash
cp /home/homelab/llm-optimizer/llm_optimizer.py.bak.v2.1 \
   /home/homelab/llm-optimizer/llm_optimizer.py
sudo systemctl restart llm-optimizer
```

## Próximas Melhorias

- [ ] GPU acceleration (CUDA/ROCm) para 3-5x speedup

### Configuração de Núcleos

O deploy script agora aceita a variável `THREADS` (padrão 2) que é usada
para exportar `OMP_NUM_THREADS` no serviço systemd e também atualizar o
`~/.cline/data/globalState.json` remoto com o campo
`ollamaApiOptionsThreads`. Isso permite ao LLM‑Optimizer / Ollama usar mais
de um núcleo CPU sem intervenção manual.

Exemplo de uso:

```bash
THREADS=4 ./scripts/deploy_llm_optimizer.sh    # configura para 4 threads
```

A variável `THREADS` também pode ser definida no ambiente do servidor
antes do deploy si quiser aplicar a configuração de forma permanente.
- [ ] Cache de resposts (Redis/memcached)
- [ ] Circuit breaker para Ollama offline
- [ ] Dynamic worker scaling baseado em CPU
- [ ] Suport para streaming de resposta (SSE)
- [ ] Rate limiting por cliente
- [ ] Authentication (API key)

## Referências

- **LLM-Optimizer Code:** `/home/homelab/llm-optimizer/llm_optimizer.py`
- **Systemd Service:** `/etc/systemd/system/llm-optimizer.service`
- **Prometheus:** http://192.168.15.2:9090/targets?search=llm-optimizer
- **Grafana Dashboard:** http://192.168.15.2:3002/d/homelab-session-monitor
