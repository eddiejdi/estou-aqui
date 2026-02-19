# 🚨 Alert Integration Guide - Estou Aqui + Prometheus + AlertManager

**Data:** 2026-02-16  
**Status:** ✅ Production Ready  
**Version:** 1.0

---

## 📋 Overview

Integração completa do pipeline de alertas Prometheus + AlertManager com o app **Estou Aqui**, permitindo que:

1. **AlertManager** dispara alertas baseado em métricas (disco, CPU, memória)
2. **Backend (Node.js)** recebe webhooks em tempo real
3. **Socket.io** transmite alertas para painéis/apps conectados
4. **Agent Bus** publica eventos para o sistema de agentes
5. **UI (Flutter/Web)** exibe alertas em tempo real

---

## 🔧 Arquitetura

```
┌──────────────────────────────────┐
│   Prometheus (Metrics Collection) │
└────────────┬─────────────────────┘
             │
             ▼
┌──────────────────────────────────┐
│ AlertManager (Rule Evaluation)   │ ◄─── Carregou 4 rules ✅
└────────────┬─────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
    ▼                 ▼
┌────────────────┐  ┌─────────────────────────────┐
│  Agent API     │  │  Estou Aqui Backend         │
│ :8503/alerts   │  │ :3000/api/alerts/webhook    │
└────────────────┘  └────────────┬─────────────────┘
    │                            │
    │                            ▼
    │                ┌───────────────────────┐
    │                │  Alert Processing     │
    │                │  - Parsing            │
    │                │  - Caching            │
    │                │  - History            │
    │                └───────────┬───────────┘
    │                            │
    │          ┌─────────────────┼─────────────────┐
    │          │                 │                 │
    ▼          ▼                 ▼                 ▼
┌──────┐  ┌──────────┐  ┌─────────────┐  ┌──────────────────┐
│ Bus  │  │Socket.io │  │ REST API    │  │ Agent Bus Publish│
│      │  │/alerts   │  │ /api/alerts │  │                  │
└──────┘  └──────────┘  └─────────────┘  └──────────────────┘
              │              │
              ▼              ▼
         ┌─────────────────────────┐
         │   Frontend Clients      │
         │ - Flutter App           │
         │ - Web Dashboard         │
         │ - Monitoring Screens    │
         └─────────────────────────┘
```

---

## 📦 Componentes Implementados

### 1. **Backend Services** (Node.js)

#### a) `services/alerting.js` - Core Alert Processing
- Recebe webhooks do AlertManager
- Processa e valida alertas
- Mantém cache de alertas ativos
- Armazena histórico (últimas 100)
- Publica no Agent Bus

**Método Principal:**
```javascript
alertingService.processAlertManagerWebhook(payload)
```

#### b) `routes/alerts.js` - REST API
```
POST   /api/alerts/webhook         ← Recebe AlertManager
GET    /api/alerts/active          ← Alertas ativos agora
GET    /api/alerts/history?limit=50 ← Histórico
GET    /api/alerts/stats           ← Estatísticas
DELETE /api/alerts/clear?hours=24  ← Limpeza
```

#### c) `services/alert-socket.js` - Socket.io Real-time
**Namespace:** `/alerts`

**Events (Server → Client):**
```javascript
'alerts:update'    // Novo alerta disparado
'alert:critical'   // Alerta crítico específico
'alert:warning'    // Alerta de aviso
'alerts:active'    // Lista de alertas ativos
'alerts:history'   // Histórico
'alerts:stats'     // Estatísticas
'alerts:error'     // Erro no processamento
```

**Events (Client → Server):**
```javascript
'alerts:request-active'    // Solicitar alertas ativos
'alerts:request-history'   // Solicitar histórico
'alerts:request-stats'     // Solicitar estatísticas
```

### 2. **Client Libraries**

#### `clients/alert-client.js` - JavaScript/Web Client
```javascript
import AlertClient from './alert-client.js';

const client = new AlertClient('http://localhost:3000');

// Registrar callbacks
client.onAlertsUpdate((alerts, status) => {
  console.log('Alertas:', alerts);
});

client.onCriticalAlert((alert) => {
  console.log('CRÍTICO:', alert);
  // Mostrar toast/notificação
});

client.onStats((stats) => {
  console.log('Stats:', stats);
});
```

---

## 🚀 Setup & Configuration

### Passo 1: Configurar AlertManager para webhooks
```bash
cd /home/edenilson/eddie-auto-dev/estou-aqui/backend

# O script configura AlertManager para enviar para ambos:
# - Agent API (:8503)
# - Estou Aqui (:3000)
# OBS: usa `127.0.0.1` para evitar resoluções de `localhost` em containers
bash scripts/setup-alert-integration.sh
```

#### Troubleshooting: 405 Method Not Allowed (AlertManager → Estou-Aqui)
- Sintoma: AlertManager registra `405 Method Not Allowed` ao postar em `http://localhost:3000/api/alerts/webhook`.
- Causas comuns:
  - AlertManager está dentro de um container e `localhost` aponta para o próprio container (chave: use `127.0.0.1` ou o IP do host).
  - Outro serviço escuta na porta 3000 (Nginx/Grafana) e responde com 405.
  - O backend estava parado no momento do envio; o proxy respondeu com 405/erro genérico.
- Correção rápida:
  1. Atualize o webhook do AlertManager para `http://127.0.0.1:3000/api/alerts/webhook` **ou** para `http://127.0.0.1:3456/api/alerts/webhook` (use 3456 to target the backend process directly when nginx serves the SPA on :3000). (script updated to prefer :3456).
  2. Verifique se o `estou-aqui` backend está ativo: `curl -sS http://127.0.0.1:3000/health` (esperado 200).
  3. Confirme que nada mais está escutando na porta 3000: `sudo ss -ltnp | grep :3000`.
  4. Recarregue o AlertManager: `sudo systemctl reload alertmanager` and re-run the test alert.
- Recomendação: adicionar testes automatizados (incluídos abaixo) para evitar regressões.

#### Testes incluídos
- `tests/test_homelab_agent_registration.py` — teste `pytest -m integration` que valida `advisor_api_registration_status == 1` no agent `/metrics` (usa `HOMELAB_HOST` para apontar o host remoto).  
- Como executar localmente (homelab access):
  - HOMELAB_HOST=192.168.15.2 pytest -q -m integration tests/test_homelab_agent_registration.py
  - No CI esses testes ficam marcados como `integration` (executar explicitamente quando necessário).


### Passo 2: Iniciar o Backend do Estou Aqui
```bash
cd /home/edenilson/eddie-auto-dev/estou-aqui/backend

npm install
npm start
# ou
PORT=3000 npm start
```

O backend agora estará:
- ✅ Recebendo webhooks em `/api/alerts/webhook`
- ✅ Transmitindo via Socket.io no `/alerts`
- ✅ Publicando no Agent Bus

### Painel Grafana — saneamento de alertas
- Novo painel `Active Prometheus Alerts` foi adicionado ao dashboard `homelab-copilot-agent` para visualizar alertas `firing` relacionados ao homelab e ao homelab-advisor.
- Use o link `Open Alertmanager` no próprio painel para abrir o Alertmanager e silenciar/rever notificações rapidamente.

#### Provisionar Contact Point no Grafana (Estou‑Aqui webhook)
- Objetivo: configurar o Grafana para enviar notificações/alertas diretamente ao backend `estou-aqui` via `POST /api/alerts/grafana-webhook`.

Opções:
1) Runtime (via API Grafana):
```bash
curl -sS -u <grafana_user>:<grafana_pass> \
  -H "Content-Type: application/json" \
  -d '{"name":"Estou-Aqui Backend","type":"webhook","settings":{"url":"http://127.0.0.1:3456/api/alerts/grafana-webhook","httpMethod":"POST","uploadImage":false},"disableResolveMessage":false}' \
  -X POST http://<grafana-host>:3000/api/v1/provisioning/contact-points
```
2) Provisioning (arquivo) — opcional: adicionar um arquivo de provisioning `contact-points` na pasta de provisioning do Grafana (ex.: `/home/homelab/monitoring/grafana/provisioning/`) conforme sua estratégia de provisionamento.

Validação:
- Listar contact points provisionados:
  `curl -sS -u <grafana_user>:<grafana_pass> http://<grafana-host>:3000/api/v1/provisioning/contact-points | jq '.'`
- Confirmar que o Contact Point aparece com `url: http://127.0.0.1:3456/api/alerts/grafana-webhook`.

Teste E2E (rápido):
1. Criar/acionar uma regra de alerta no Grafana que notifique o Contact Point (ou usar o botão "Test" no UI se disponível).
2. OU simular o payload do Grafana diretamente no backend (exemplo abaixo):
```bash
curl -sS -X POST http://<estou-aqui-host>:3456/api/alerts/grafana-webhook \
  -H 'Content-Type: application/json' \
  -d '{"title":"High memory usage","ruleName":"HighMemoryUsage","state":"alerting","message":"Memory > 90%","evalMatches":[{"metric":"memory_total","value":93,"tags":{"instance":"homelab"},"time":"2026-02-16T22:00:00.000Z"}],"tags":{"severity":"critical"},"ruleUrl":"http://grafana/alert/1"}'
```
3. Verificar backend/homelab:
  - `curl http://<estou-aqui-host>:3456/api/alerts/active | jq` — o alerta deve aparecer como `HighMemoryUsage`.
  - Conferir `journalctl -u estouaqui-backend` e `curl http://<homelab>:8085/metrics | grep advisor` conforme necessário.

Observações operacionais:
- Use `127.0.0.1:3456` para apontar diretamente ao processo backend quando nginx serve SPA em `:3000`.
- Se Grafana estiver containerizada, prefira provisioning via API ou um arquivo de provisioning que seja aplicado no container host.

- Boas práticas ao saneamento:
  - Priorize alertas `critical` para investigação imediata; `warning` pode ser agrupado e avaliado durante manutenção.
  - Ajuste `duration`/`thresholds` nas regras do Prometheus (em `/etc/prometheus/rules/`) em vez de apenas no dashboard — isso reduz ruído globalmente.
  - Sempre documente alterações de regras em `ALERT_INTEGRATION_GUIDE.md` e revalide com um teste de integração (ex.: `tests/test_homelab_agent_registration.py`).

### Passo 3: Integrar no Frontend

#### Para Web (React/Vue/Vanilla JS):
```html
<script src="https://cdn.socket.io/4.5.4/socket.io.min.js"></script>
<script type="module">
  import AlertClient from './alert-client.js';
  
  const alerts = new AlertClient('http://localhost:3000');
  
  alerts.onCriticalAlert((alert) => {
    // Mostrar badge/notificação crítica
    updateUI(alert);
  });
</script>
```

#### Para Flutter:
```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class AlertsPanel extends StatefulWidget {
  @override
  _AlertsPanelState createState() => _AlertsPanelState();
}

class _AlertsPanelState extends State<AlertsPanel> {
  late IO.Socket socket;
  List<Map> alerts = [];

  @override
  void initState() {
    super.initState();
    _initializeSocket();
  }

  void _initializeSocket() {
    socket = IO.io('http://localhost:3000/alerts',
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build()
    );

    socket.on('connect', (_) {
      print('✅ Connected to alerts');
      socket.emit('alerts:request-active');
    });

    socket.on('alerts:update', (data) {
      setState(() {
        alerts = List<Map>.from(data['alerts'] ?? []);
      });
    });

    socket.on('alert:critical', (alert) {
      _showCriticalAlert(alert);
    });

    socket.connect();
  }

  void _showCriticalAlert(Map alert) {
    // Mostrar notificação crítica
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚨 ${alert['summary']}'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: alerts.map((alert) => 
        AlertCard(alert: alert)
      ).toList(),
    );
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }
}

class AlertCard extends StatelessWidget {
  final Map alert;

  const AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final severity = alert['severity'] ?? 'unknown';
    final icon = severity == 'critical' ? '🚨' : severity == 'warning' ? '⚠️' : 'ℹ️';
    final color = severity == 'critical' ? Colors.red : Colors.orange;

    return Card(
      color: color.withOpacity(0.1),
      child: ListTile(
        leading: Text(icon, style: TextStyle(fontSize: 24)),
        title: Text(alert['summary'] ?? 'Alert'),
        subtitle: Text(alert['description'] ?? ''),
        trailing: Text(
          alert['status'] == 'firing' ? '🔴 Ativo' : '🟢 Resolvido',
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
```

---

## 📊 Alert Rules

Atualmente, 4 regras monitorando (infra geral):

| Alerta | Threshold | Severity | Duration |
|--------|-----------|----------|----------|
| `DiskUsageHigh` | Disco < 20% livre | warning | 5 minutos |
| `DiskUsageCritical` | Disco < 10% livre | critical | 1 minuto |
| `HighCPUUsage` | CPU idle < 15% | warning | 5 minutos |
| `HighMemoryUsage` | Memória > 85% | warning | 5 minutos |

**Arquivo:** `/etc/prometheus/rules/homelab-alerts.yml`

---

### homelab-advisor (agent-specific rules)

As regras do *Homelab Advisor* monitoram a disponibilidade e integridade do agente. Essas regras foram ajustadas para reduzir ruído — o `heartbeat` agora tolera até 5 minutos sem atualização e as regras incluem `runbook_url` para triagem rápida.

| Alerta | Expressão / Trigger | Severity | For |
|--------|---------------------|----------|-----|
| `HomelabAdvisorMissingHeartbeat` | time() - advisor_heartbeat_timestamp > 300 | critical | 2m |
| `HomelabAdvisorNotRegistered` | advisor_api_registration_status == 0 | warning | 5m |
| `HomelabAdvisorReportErrors` | increase(advisor_api_reports_total{status="error"}[5m]) > 0 | warning | 5m |

**Arquivo:** `/etc/prometheus/rules/homelab-advisor-alerts.yml`

Notas:
- `runbook_url` foi adicionado às anotações das regras para direcionar operadores às instruções de resolução.
- Recomendação: não baixe o `heartbeat` para valores baixos (<2 min) em ambientes com possíveis GC/pauses — 5 minutos é um compromisso razoável para reduzir falsos positivos.
- Após alterar regras, recarregue o Prometheus: `sudo systemctl reload prometheus` e verifique com `http://127.0.0.1:9090/api/v1/rules`.


---

## 🧪 Testing

### Teste 1: Enviar alerta via curl
```bash
curl -X POST http://localhost:3000/api/alerts/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "groupLabels": {
      "alertname": "TestAlert"
    },
    "status": "firing",
    "alerts": [
      {
        "status": "firing",
        "labels": {
          "alertname": "TestAlert",
          "severity": "warning",
          "instance": "test"
        },
        "annotations": {
          "summary": "Este é um alerta de teste",
          "description": "Teste da integração de alertas"
        },
        "startsAt": "2026-02-16T14:30:00Z",
        "endsAt": "0001-01-01T00:00:00Z"
      }
    ]
  }'
```

### Teste 2: Verificar alertas ativos
```bash
curl http://localhost:3000/api/alerts/active | jq
```

### Teste 3: Verificar estatísticas
```bash
curl http://localhost:3000/api/alerts/stats | jq
```

### Teste 4: Socket.io real-time (usando socket.io-client)
```bash
npm install -g socket.io-client-cli
socketio client --url http://localhost:3000/alerts \
  --events "alerts:update,alert:critical" \
  --emit "alerts:request-active"
```

---

## 📈 Monitoring & Logs

### Ver logs do backend
```bash
cd estou-aqui/backend
npm start  # Verá eventos de alertas no console
```

### Ver logs do AlertManager
```bash
sudo journalctl -u alertmanager -f
```

### Verificar conexões Socket.io
```bash
# No navegador console ou terminal:
socket.on('connect', () => console.log('Connected!'));
socket.emit('alerts:request-active');
```

---

## �️ Runbooks — Homelab Advisor

### Heartbeat troubleshooting {#heartbeat-troubleshooting}
- Symptom: `HomelabAdvisorMissingHeartbeat` firing.
- Checar métricas:
  - curl http://<homelab>:8085/metrics | grep advisor_heartbeat_timestamp
  - Verifique se o valor foi atualizado recentemente (timestamp unix).
- Logs e serviços:
  - sudo journalctl -u homelab_copilot_agent -f
  - docker ps / docker logs homelab-copilot-agent
- Possíveis ações:
  1. Reinicie o agent: `sudo systemctl restart homelab_copilot_agent`.
  2. Se o agente estiver em container, confirme `API_BASE_URL` e conectividade ao host (`curl -sS http://172.17.0.1:8503/health`).
  3. Aumente tolerância do heartbeat em Prometheus se o ambiente sofrer pausas ocasionalmente.

### Registration failure {#registration-failure}
- Symptom: `HomelabAdvisorNotRegistered` firing.
- Checar métricas:
  - curl http://<homelab>:8085/metrics | grep advisor_api_registration_status
- Verificar IPC/API:
  - curl -sS http://127.0.0.1:8503/health
  - Confirme que o container tem a variável `API_BASE_URL` apontando para o host gateway (ex: `http://172.17.0.1:8503`).
  - Se o backend estiver rodando em container, defina `AGENT_BUS_URL=http://172.17.0.1:8503` para garantir que os webhooks sejam publicados no mesmo Agent Bus que os agentes consultam.
- Ações rápidas:
  1. Ajuste systemd override para passar `API_BASE_URL` e reinicie o serviço.
  2. Revise logs do agent para `Registrado na API principal via IPC`.

### IPC / Network troubleshooting {#ipc-network-troubleshooting}
- Symptom: `advisor_ipc_ready == 0` or `IPC init failed: could not translate host name` in agent logs.
- Causas comuns:
  - O container do agent não está na mesma rede Docker que o Postgres (hostname `eddie-postgres` não resolvido).
  - `DATABASE_URL` configurado com host/porta incorretos ou credenciais inválidas.
- Ações imediatas:
  1. Use o sample systemd em `scripts/systemd/homelab_copilot_agent.service.sample` (inclui `--network homelab_monitoring` e `DATABASE_URL` apontando para `eddie-postgres`).
  2. Verifique conectividade DNS/TCP a partir do container: `docker exec <agent-cid> python3 -c "import socket; socket.create_connection(('eddie-postgres',5432),2)"`
  3. Confirme credenciais: `docker exec eddie-postgres env | grep POSTGRES_PASSWORD` e ajuste `DATABASE_URL` conforme necessário.
  4. Reinicie o serviço systemd que inicia o container (`sudo systemctl daemon-reload && sudo systemctl restart homelab_copilot_agent`).
- Comportamento esperado: após correção, `curl -sS http://127.0.0.1:8085/health` deve retornar `"ipc_available": true` e `advisor_ipc_ready` deve ser exportada como métrica.
- Nota operacional: prefira injetar senha via Secrets Agent (não hardcode).

### Reporting errors {#reporting-errors}
- Symptom: `HomelabAdvisorReportErrors` firing.
- Checar métricas:
  - curl http://<homelab>:8085/metrics | grep advisor_api_reports_total
- Logs:
  - sudo journalctl -u homelab_copilot_agent -u -f | grep report
- Ações:
  1. Investigar payloads/Endpoints responsáveis por `status=error`.
  2. Reprocessar falhas ou aplicar backoff/retry no agent se for transitório.

---

## �🔗 Integration with Agent Bus

Alertas são automaticamente publicados no Agent Communication Bus:

```javascript
// Automaticamente feito pelo alerting.js
bus.publish(
  MessageType.ALERT,
  'estou-aqui-backend',
  'monitoring',
  '[CRITICAL] Disk usage critical',
  {
    alert_name: 'DiskUsageCritical',
    severity: 'critical',
    instance: 'homelab',
    group_labels: { ... }
  }
)
```

**Verificar mensagens no bus:**
```bash
curl http://localhost:8503/interceptor/conversations/active | jq
```

---

## 🔄 Workflow Completo

1. **Prometheus** coleta métricas a cada 15s
2. **AlertManager** avalia regras a cada 60s
3. **Alerta dispara** → AlertManager envia webhook
4. **Backend recebe** → processa e cacheia
5. **Socket.io emite** → todos os clientes recebem
6. **Agent Bus publica** → agentes são notificados
7. **UI atualiza** → painéis mostram alerta em tempo real

---

## 🚨 Próximas Melhorias

- [ ] Integração com Telegram/Email para críticos
- [ ] Dashboard Grafana com alertas em tempo real
- [ ] Histórico persistente de alertas (DB)
- [ ] Regras customizáveis via API
- [ ] Grouping inteligente de alertas correlacionados
- [ ] Webhook com autenticação (JWT)
- [ ] Retry automático de falhas

---

## 📞 API Reference

Ver [ALERT_API.md](./ALERT_API.md) para documentação completa de endpoints.

---

**Status:** ✅ **PRODUCTION READY**

Integração testada e validada. Pronta para produção.

*Last updated: 2026-02-16T14:30:00Z*
