# 🤖 Painel Multi-Agente - Integração com Open WebUI

## 🎯 Acesso Rápido

**URL do Painel**: `http://192.168.15.2:8505/`

**Status do Serviço**: ✅ Operacional

---

## 🔗 Links de Acesso

| Serviço | URL | Status |
|---------|-----|--------|
| **Dashboard** | http://192.168.15.2:8505 | ✅ Ativo |
| **API Health** | http://192.168.15.2:8505/api/health | ✅ OK |
| **Open WebUI** | http://192.168.15.2:8080 | ✅ Ativo |
| **Coordinator** | http://192.168.15.2:8503 | ✅ Ativo |
| **Ollama** | http://192.168.15.2:11434 | ✅ Ativo |

---

## 📊 Funcionalidades do Painel

### 1. **Status do Sistema** 📊
- CPU e Memória do Coordinator
- Timestamp de atualização
- Indicador de saúde em tempo real

### 2. **Communication Bus** 🚌
- Estado da fila de mensagens
- Agentes ativos
- Mensagens processadas

### 3. **Agentes Conectados** 🔌
- Lista completa de agentes especializados
- Status (online/idle)
- Tecnologias disponíveis
- Capabilities de cada agente

### 4. **Tarefas em Execução** ⚙️
- ID da tarefa
- Agente responsável
- Status atual
- Barra de progresso
- Tempo decorrido

### 5. **Métricas da API** 📈
- Total de requisições
- Tempo médio de resposta
- Taxa de erro
- Performance histórica

---

## 🔌 Integração com Open WebUI

### **Método 1: Via URL Externa (Recomendado)**

1. Acesse o **Open WebUI**: http://192.168.15.2:8080
2. Vá para **Settings** ⚙️ → **Functions** (ou **Admin** → **Functions**)
3. Clique em **Create New Function** / **Add Function**
4. Selecione **Web Interface** ou **External Tool**
5. Cole a URL:
   ```
   http://192.168.15.2:8505/
   ```
6. Configure:
   - **Nome**: `Multi-Agent Dashboard`
   - **URL**: `http://192.168.15.2:8505/`
   - **Tipo**: `Web Interface` / `iframe`
   - **Ícone**: `🤖`
7. Salve e recarregue

### **Método 2: Via Embedding em Chat**

Para usar o dashboard como ferrament dentro do chat:

```javascript
// Adicionar em Custom Functions do Open WebUI
{
  "name": "Dashboard",
  "type": "web",
  "url": "http://192.168.15.2:8505/",
  "icon": "🤖",
  "description": "Monitorar agentes e Communication Bus"
}
```

---

## 🎮 Como Usar

### **Acessar o Dashboard**
- Digite a URL: `http://192.168.15.2:8505/`
- Ou acesse via Open WebUI se integrado

### **Visualizar Status em Tempo Real**
- Dashboard atualiza **a cada 5 segundos** automaticamente
- Clique 🔄 **Atualizar** para força atualização imediata

### **Entender Status dos Agentes**
| Status | Cor | Significado |
|--------|-----|------------|
| 🟢 **online** | Verde | Pronto para receber tarefas |
| 🟡 **idle** | Amarelo | Aguardando tarefas |
| 🔴 **offline** | Vermelho | Desconectado |

### **Monitorar Tarefas**
- Veja progresso em tempo real
- Tempo decorrido atualiza a cada segundo
- Taxa de sucesso/erro da API

---

## 🔌 Endpoints da API

Você pode integrar o dashboard programaticamente:

### **Health Check**
```bash
curl http://192.168.15.2:8505/api/health | jq .
```

### **Status do Sistema**
```bash
curl http://192.168.15.2:8505/api/status | jq .
```

### **Lista de Agentes**
```bash
curl http://192.168.15.2:8505/api/agents | jq .
```

### **Tarefas em Execução**
```bash
curl http://192.168.15.2:8505/api/tasks | jq .
```

### **Métricas**
```bash
curl http://192.168.15.2:8505/api/metrics | jq .
```

---

## 🛠️ Configuração Técnica

### **Variáveis de Ambiente**
```bash
DASHBOARD_PORT=8505                    # Porta do dashboard
COORDINATOR_URL=http://192.168.15.2:8503  # URL do Coordinator
OPEN_WEBUI_URL=http://192.168.15.2:8080   # URL do Open WebUI
```

### **Servidor**
- **Framework**: FastAPI + Uvicorn
- **Porta**: 8505
- **Host**: 0.0.0.0 (accessível remotamente)
- **Auto-reload**: Desativado em produção

### **Performance**
- ⚡ Refresh automático: 5 segundos
- 🔄 Sem cache de dados (sempre real-time)
- 📡 Comunicação via HTTP (sem WebSocket por enquanto)

---

## 🔐 Segurança

⚠️ **IMPORTANTE**: Este dashboard **não possui autenticação**. Para produção:

1. Adicione middleware de autenticação (JWT, OAuth)
2. Configure CORS adequadamente
3. Use HTTPS em vez de HTTP
4. Implemente rate limiting
5. Proteja via firewall/reverse proxy

---

## 📱 Modo Responsivo

O dashboard funciona em:
- ✅ Desktop (1920px+)
- ✅ Tablet (768px+)
- ✅ Mobile (320px+)

Layout adapta automaticamente!

---

## 🐛 Troubleshooting

### **Dashboard não carrega**
```bash
# Verificar status
curl http://192.168.15.2:8505/api/health

# Verificar logs
ssh homelab@192.168.15.2 "tail -100 /tmp/dashboard_server_8505.log"
```

### **Agentes não aparecem**
- Verificar se Coordinator está em execução: `curl http://192.168.15.2:8503/health`
- Aguardar 30s para agentes se registrarem
- Recarregar página do dashboard

### **Taxa de atualização lenta**
- Verificar conexão de rede
- Verificar CPU/memória do Coordinator
- Verificar logs: `ssh homelab@192.168.15.2 "tail /tmp/dashboard_server_8505.log"`

### **Porta 8505 em uso**
```bash
# Verificar
ssh homelab@192.168.15.2 "lsof -i :8505"

# Usar porta alternativa
ssh homelab@192.168.15.2 "DASHBOARD_PORT=8506 nohup python3 /tmp/dashboard_server.py &"
```

---

## 📊 Dados Monitorados em Tempo Real

### **Coordinator Health**
- Status de saúde geral
- CPU e Memória utilizados
- Timestamp de última atualização
- Conectividade com Agents

### **Communication Bus**
- Fila atual de mensagens
- Agentes ativos
- Total histórico processado
- Taxa de mensagens/segundo

### **Agentes Especializados**
- 🐍 Python (FastAPI, Django, ML)
- 🟨 JavaScript (Node.js, Express)
- 🔷 TypeScript (Next.js, Vue)
- 🐹 Go (Microserviços, High-performance)
- 🦀 Rust (Sistemas críticos)
- ☕ Java (Spring Boot, Enterprise)
- 🟦 C# (ASP.NET, .NET)
- 🐘 PHP (Laravel, WordPress)

---

## 🚀 Iniciar/Reiniciar o Dashboard

### **Iniciar**
```bash
ssh homelab@192.168.15.2 "DASHBOARD_PORT=8505 nohup python3 /tmp/dashboard_server.py > /tmp/dashboard.log 2>&1 &"
```

### **Verificar Status**
```bash
ssh homelab@192.168.15.2 "ps aux | grep dashboard_server"
```

### **Reiniciar**
```bash
ssh homelab@192.168.15.2 "pkill -f dashboard_server && sleep 2 && DASHBOARD_PORT=8505 nohup python3 /tmp/dashboard_server.py > /tmp/dashboard.log 2>&1 &"
```

### **Parar**
```bash
ssh homelab@192.168.15.2 "pkill -f dashboard_server"
```

---

## 📈 Próximos Passos

- [ ] Adicionar WebSocket para atualização em tempo real
- [ ] Implementar autenticação JWT
- [ ] Criar gráficos históricos de performance
- [ ] Adicionar controle de tarefas (pause, cancel)
- [ ] Notificações push ao receber alertas
- [ ] Exportar relatórios em PDF
- [ ] Dark/Light mode persistente
- [ ] Integração com Grafana

---

## 📞 Suporte

**Status do Dashboard**: ✅ Operacional
**Último atualizado**: 2026-02-20 03:09:27 UTC
**Systemd Service**: Não (rode via `nohup` ou cron)

Para monitoramento permanente, crie um systemd service:

```bash
sudo systemctl enable multi-agent-dashboard
sudo systemctl start multi-agent-dashboard
```

---

## 📝 Notas

- Dashboard não requer banco de dados (stateless)
- Todos os dados são obtidos em tempo real via API
- Não persiste histórico (é apenas um monitor)
- Safe para reiniciar sem perda de dados
- Suporta múltiplas instâncias em portas diferentes

**Desenvolvido para**: Estou Aqui | Multi-Agent System Architecture
