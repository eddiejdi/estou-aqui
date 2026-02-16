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
bash scripts/setup-alert-integration.sh
```

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

Atualmente, 4 regras monitorando:

| Alerta | Threshold | Severity | Duration |
|--------|-----------|----------|----------|
| `DiskUsageHigh` | Disco < 20% livre | warning | 5 minutos |
| `DiskUsageCritical` | Disco < 10% livre | critical | 1 minuto |
| `HighCPUUsage` | CPU idle < 15% | warning | 5 minutos |
| `HighMemoryUsage` | Memória > 85% | warning | 5 minutos |

**Arquivo:** `/etc/prometheus/rules/homelab-alerts.yml`

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

## 🔗 Integration with Agent Bus

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
