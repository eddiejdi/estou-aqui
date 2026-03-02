# 📍 Estou Aqui — Documentação da API

## Base URL
```
http://localhost:3000/api
```

## Autenticação  
Todas as rotas protegidas requerem header:
```
Authorization: Bearer <token>
```

---

## Auth

### POST /auth/register
Cria nova conta.
```json
{
  "name": "João Silva",
  "email": "joao@email.com",
  "password": "123456"
}
```
**Resposta:** `201` `{ token, user }`

### POST /auth/login
```json
{
  "email": "joao@email.com",
  "password": "123456"
}
```
**Resposta:** `200` `{ token, user }`

### GET /auth/me 🔒
**Resposta:** `200` `{ user }`

### PUT /auth/profile 🔒
```json
{
  "name": "Novo Nome",
  "bio": "Ativista social"
}
```

### PUT /auth/fcm-token 🔒
```json
{ "fcmToken": "firebase-token-aqui" }
```

---

## Events

### GET /events
Parâmetros de query:
| Param    | Tipo   | Descrição               |
|----------|--------|-------------------------|
| lat      | float  | Latitude do centro      |
| lng      | float  | Longitude do centro     |
| radius   | int    | Raio em km (default 50) |
| status   | string | scheduled/active/ended  |
| category | string | manifestacao/protesto/...|
| city     | string | Filtro por cidade       |
| page     | int    | Página (default 1)      |
| limit    | int    | Items por página (20)   |

### GET /events/:id
### POST /events 🔒
### PUT /events/:id 🔒
### PUT /events/:id/status 🔒

---

## Check-ins

### POST /checkins 🔒
```json
{
  "eventId": "uuid",
  "latitude": -23.5505,
  "longitude": -46.6333
}
```

### DELETE /checkins/:eventId 🔒
Check-out do evento.

### GET /checkins/event/:eventId
Lista check-ins ativos.

### GET /checkins/me 🔒
Meus check-ins ativos.

---

## Chat

### GET /chat/:eventId 🔒
Mensagens do evento (paginado).

### POST /chat/:eventId 🔒
```json
{
  "content": "Estou chegando!",
  "type": "text"
}
```

---

## Estimativas

### GET /estimates/:eventId
Histórico de estimativas.

### POST /estimates/:eventId/calculate 🔒
```json
{
  "areaSquareMeters": 5000,
  "densityLevel": "medium"
}
```

### POST /estimates/:eventId/manual 🔒
```json
{ "estimatedCount": 5000, "notes": "Contagem visual" }
```

---

## Notificações

### GET /notifications 🔒
### PUT /notifications/:id/read 🔒
### PUT /notifications/read-all 🔒

---

## WebSocket (Socket.IO)

### Conexão
```javascript
const socket = io('http://localhost:3000', {
  auth: { token: 'jwt-token' }
});
```

### Eventos emitidos pelo cliente
| Evento           | Payload                          |
|------------------|----------------------------------|
| event:join       | eventId (string)                 |
| event:leave      | eventId (string)                 |
| chat:send        | { eventId, content, type }       |
| chat:typing      | { eventId }                      |
| location:update  | { eventId, latitude, longitude } |

### Eventos recebidos do servidor
| Evento           | Payload                                    |
|------------------|--------------------------------------------|
| chat:message     | ChatMessage object                         |
| checkin:new      | { eventId, activeCheckins, estimated... }  |
| checkout         | { eventId, activeCheckins }                |
| estimate:updated | { eventId, estimatedAttendees, method... } |
| event:status     | { eventId, status }                        |

---

## Performance e Tuning

### Capacidade estimada (infraestrutura atual — homelab)

| Componente | Configuração |
|---|---|
| **CPU** | Intel i9-9900T (16 threads) @ 2.10 GHz |
| **RAM** | 32 GB |
| **Backend** | Node.js single-thread (Express + Socket.IO) |
| **DB** | PostgreSQL 16 (Docker), `max_connections = 100` |
| **Sequelize pool** | `max: 20`, `min: 2`, `acquire: 30s`, `idle: 10s` |
| **Proxy** | Cloudflare Tunnel (TLS na edge) |

**Throughput estimado: ~3.000–6.000 req/min** (single process)

### Pool de conexões (Sequelize)

Configurado em `/backend/src/config/database.js`:

| Ambiente | `max` | `min` | `acquire` | `idle` |
|---|---|---|---|---|
| development | 20 | 2 | 30s | 10s |
| test | 5 | 1 | 30s | 10s |
| production | 20 | 5 | 30s | 10s |

### Logging (Morgan)

- **Development**: `morgan('dev')` — log colorido completo
- **Production**: `morgan('combined')` — formato Apache, skip `/health`

### Escalabilidade futura

| Ação | Ganho | Esforço |
|---|---|---|
| `pm2 cluster` (8 workers) | +400–700% | 5 min |
| Redis cache para eventos | +200% | 2h |
| PgBouncer (connection pooler) | +50% | 30 min |
