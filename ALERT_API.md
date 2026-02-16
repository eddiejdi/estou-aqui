# 🚨 Alert API Reference

**Version:** 1.0  
**Base URL:** `http://localhost:3000/api/alerts`

---

## Endpoints

### 1. Webhook (POST)

**Recebe webhooks do AlertManager**

```
POST /api/alerts/webhook
Content-Type: application/json
```

#### Request Body
```json
{
  "groupLabels": {
    "alertname": "DiskUsageHigh"
  },
  "status": "firing",
  "alerts": [
    {
      "status": "firing",
      "labels": {
        "alertname": "DiskUsageHigh",
        "severity": "warning",
        "instance": "192.168.15.2:9100"
      },
      "annotations": {
        "summary": "High disk usage on /dev/mapper",
        "description": "Disk has 15% free space available"
      },
      "startsAt": "2026-02-16T14:30:00Z",
      "endsAt": "0001-01-01T00:00:00Z"
    }
  ]
}
```

#### Response
```json
{
  "status": "received",
  "processed": 1,
  "timestamp": "2026-02-16T14:30:00Z"
}
```

#### Status Code
- `200 OK` - Webhook processado com sucesso
- `500 Internal Server Error` - Erro ao processar

---

### 1.1 Grafana webhook (POST)

**Recebe webhooks do Grafana Alerting.** Use este endpoint quando provisionar um Contact Point no Grafana que encaminhe notificações para o backend Estou‑Aqui.

```
POST /api/alerts/grafana-webhook
Content-Type: application/json
```

#### Payload (exemplo enviado pelo Grafana)
```json
{
  "title": "High memory usage",
  "ruleName": "HighMemoryUsage",
  "state": "alerting",
  "message": "Memory > 90%",
  "evalMatches": [
    { "metric": "memory_total", "value": 93, "tags": { "instance": "homelab" }, "time": "2026-02-16T22:00:00.000Z" }
  ],
  "tags": { "severity": "critical" },
  "ruleUrl": "http://grafana/alert/1"
}
```

> Nota: o backend mapeia o payload do Grafana para um formato interno (semelhante ao AlertManager) e publica o alerta no Agent Bus / Socket.io.

#### Response
```json
{
  "status": "received",
  "processed": 1,
  "timestamp": "2026-02-16T22:00:00Z"
}
```

#### Status Code
- `200 OK` - Webhook processado com sucesso
- `400 Bad Request` - Payload inválido
- `500 Internal Server Error` - Erro ao processar

> Ver `ALERT_INTEGRATION_GUIDE.md` para instruções de provisionamento do Contact Point no Grafana e teste E2E.

---

### 2. Get Active Alerts (GET)

**Retorna todos os alertas ativos no momento**

```
GET /api/alerts/active
```

#### Response
```json
{
  "status": "success",
  "alerts": [
    {
      "id": "DiskUsageHigh_2026-02-16T14:30:00Z_abc123",
      "name": "DiskUsageHigh",
      "status": "firing",
      "severity": "warning",
      "instance": "192.168.15.2:9100",
      "summary": "High disk usage on /dev/mapper",
      "description": "Disk has 15% free space available",
      "startsAt": "2026-02-16T14:30:00Z",
      "endsAt": "0001-01-01T00:00:00Z",
      "labels": {
        "alertname": "DiskUsageHigh",
        "severity": "warning",
        "instance": "192.168.15.2:9100"
      },
      "timestamp": "2026-02-16T14:30:00Z",
      "groupLabels": {
        "alertname": "DiskUsageHigh"
      }
    }
  ],
  "count": 1,
  "timestamp": "2026-02-16T14:30:00Z"
}
```

#### Status Code
- `200 OK` - Sucesso
- `500 Internal Server Error` - Erro

---

### 3. Get Alert History (GET)

**Retorna histórico de alertas (últimos N)**

```
GET /api/alerts/history?limit=50
```

#### Query Parameters
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | int | 50 | Número de alertas a retornar |

#### Response
```json
{
  "status": "success",
  "alerts": [
    {
      "id": "DiskUsageHigh_2026-02-16T14:30:00Z_abc123",
      "name": "DiskUsageHigh",
      "status": "firing",
      "severity": "warning",
      "instance": "192.168.15.2:9100",
      "summary": "High disk usage on /dev/mapper",
      "description": "Disk has 15% free space available",
      "startsAt": "2026-02-16T14:30:00Z",
      "endsAt": "0001-01-01T00:00:00Z",
      "labels": {
        "alertname": "DiskUsageHigh",
        "severity": "warning",
        "instance": "192.168.15.2:9100"
      },
      "timestamp": "2026-02-16T14:30:00Z",
      "groupLabels": {
        "alertname": "DiskUsageHigh"
      }
    }
  ],
  "count": 1,
  "limit": 50,
  "timestamp": "2026-02-16T14:30:00Z"
}
```

---

### 4. Get Alert Statistics (GET)

**Retorna estatísticas dos alertas**

```
GET /api/alerts/stats
```

#### Response
```json
{
  "status": "success",
  "stats": {
    "totalActive": 2,
    "critical": 1,
    "warning": 1,
    "history": 25,
    "timestamp": "2026-02-16T14:30:00Z"
  },
  "timestamp": "2026-02-16T14:30:00Z"
}
```

#### Fields
| Field | Type | Description |
|-------|------|-------------|
| `totalActive` | int | Número de alertas ativos |
| `critical` | int | Quantidade de alertas críticos |
| `warning` | int | Quantidade de alertas de aviso |
| `history` | int | Total de alertas no histórico |

---

### 5. Clear Old Alerts (DELETE)

**Remove alertas antigos do histórico**

```
DELETE /api/alerts/clear?hours=24
```

#### Query Parameters
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `hours` | int | 24 | Remover alertas com mais de N horas |

#### Response
```json
{
  "status": "success",
  "removed": 5,
  "timestamp": "2026-02-16T14:30:00Z"
}
```

---

## Socket.io Events

### Base URL
```
http://localhost:3000/alerts
```

### Server → Client Events

#### `alerts:update`
Enviado quando novos alertas disparam
```javascript
socket.on('alerts:update', (data) => {
  console.log(data);
  // {
  //   status: "firing",
  //   alerts: [{ ... }],
  //   activeCount: 2,
  //   timestamp: "2026-02-16T14:30:00Z"
  // }
});
```

#### `alert:critical`
Enviado especificamente para alertas críticos
```javascript
socket.on('alert:critical', (alert) => {
  console.log('CRÍTICO:', alert);
  // {
  //   name: "DiskUsageCritical",
  //   severity: "critical",
  //   summary: "...",
  //   ...
  // }
});
```

#### `alert:warning`
Enviado especificamente para alertas de aviso
```javascript
socket.on('alert:warning', (alert) => {
  console.log('AVISO:', alert);
});
```

#### `alerts:active`
Resposta para `alerts:request-active`
```javascript
socket.on('alerts:active', (data) => {
  console.log(data);
  // {
  //   alerts: [{ ... }],
  //   count: 2,
  //   timestamp: "2026-02-16T14:30:00Z"
  // }
});
```

#### `alerts:history`
Resposta para `alerts:request-history`
```javascript
socket.on('alerts:history', (data) => {
  console.log(data);
  // {
  //   alerts: [{ ... }],
  //   count: 50,
  //   limit: 50,
  //   timestamp: "2026-02-16T14:30:00Z"
  // }
});
```

#### `alerts:stats`
Resposta para `alerts:request-stats`
```javascript
socket.on('alerts:stats', (data) => {
  console.log(data);
  // {
  //   stats: {
  //     totalActive: 2,
  //     critical: 1,
  //     warning: 1,
  //     history: 25,
  //     timestamp: "2026-02-16T14:30:00Z"
  //   },
  //   timestamp: "2026-02-16T14:30:00Z"
  // }
});
```

#### `alerts:error`
Enviado em caso de erro
```javascript
socket.on('alerts:error', (error) => {
  console.error('Error:', error.message);
});
```

### Client → Server Events

#### `alerts:request-active`
Solicita alertas ativos
```javascript
socket.emit('alerts:request-active');
// Receberá: alerts:active
```

#### `alerts:request-history`
Solicita histórico com limite
```javascript
socket.emit('alerts:request-history', { limit: 50 });
// Receberá: alerts:history
```

#### `alerts:request-stats`
Solicita estatísticas
```javascript
socket.emit('alerts:request-stats');
// Receberá: alerts:stats
```

---

## Alert Object Structure

```javascript
{
  id: string,           // UUID único do alerta
  name: string,         // Nome da regra (ex: "DiskUsageHigh")
  status: string,       // "firing" | "resolved"
  severity: string,     // "critical" | "warning" | "info" | "unknown"
  instance: string,     // Host/instância (ex: "192.168.15.2:9100")
  summary: string,      // Resumo do alerta
  description: string,  // Descrição detalhada
  startsAt: string,     // ISO timestamp quando disparou
  endsAt: string,       // ISO timestamp quando foi resolvido (se aplicável)
  labels: object,       // Labels do Prometheus
  timestamp: string,    // Quando foi processado
  groupLabels: object   // Group labels do AlertManager
}
```

---

## Status Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 200 | OK | Request succeeded |
| 500 | Internal Server Error | Server error processing request |

---

## Error Response Example

```json
{
  "error": "Error processing AlertManager webhook"
}
```

---

## Rate Limiting

Não aplicado (pode ser adicionado em produção com middleware rate-limit)

---

## Example: Complete Workflow

```javascript
// 1. Conectar ao Socket.io
const socket = io('http://localhost:3000/alerts');

// 2. Ouvir atualizações em tempo real
socket.on('alerts:update', (data) => {
  console.log(`${data.activeCount} alertas ativos`);
});

// 3. Ouvir apenas alertas críticos
socket.on('alert:critical', (alert) => {
  // Mostrar notificação visual/sonora
  triggerNotification(alert);
});

// 4. Solicitar alertas ativos ao conectar
socket.on('connect', () => {
  socket.emit('alerts:request-active');
});

// 5. Obter histórico via REST
fetch('http://localhost:3000/api/alerts/history?limit=20')
  .then(r => r.json())
  .then(data => console.log(data.alerts));

// 6. Obter stats via REST
fetch('http://localhost:3000/api/alerts/stats')
  .then(r => r.json())
  .then(data => console.log(`${data.stats.critical} críticos`));
```

---

**Last Updated:** 2026-02-16  
**Status:** Production Ready ✅
