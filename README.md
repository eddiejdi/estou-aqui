# 📍 Estou Aqui - Monitor e Estimativa de Movimentos Sociais

Aplicação mobile (Android & iOS) para monitorar, participar e estimar a dimensão de movimentos sociais em tempo real.

## 🎯 Funcionalidades

- **🗺️ Mapa em Tempo Real** — Visualize movimentos e manifestações no mapa com GPS
- **👥 Estimativa de Público** — Algoritmo para estimar número de pessoas em eventos
- **📍 Check-in "Estou Aqui"** — Marque presença em movimentos sociais
- **📰 Feed de Eventos** — Lista de movimentos ativos e agendados
- **💬 Chat** — Comunicação entre participantes
- **🔔 Notificações Push** — Alertas sobre eventos próximos ou em andamento

## 🏗️ Arquitetura

```
estou-aqui/
├── app/                    # Flutter mobile app (Android + iOS)
│   ├── lib/
│   │   ├── models/         # Modelos de dados
│   │   ├── screens/        # Telas do app
│   │   ├── services/       # Serviços (API, GPS, Auth)
│   │   ├── widgets/        # Componentes reutilizáveis
│   │   ├── providers/      # State management (Riverpod)
│   │   └── utils/          # Utilitários
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
├── backend/                # API REST Node.js/Express
│   ├── src/
│   │   ├── routes/         # Rotas da API
│   │   ├── controllers/    # Controllers
│   │   ├── models/         # Modelos Sequelize
│   │   ├── middleware/      # Auth, validação
│   │   ├── services/       # Lógica de negócio
│   │   └── config/         # Configurações
│   ├── migrations/         # Migrações do banco
│   └── package.json
└── docs/                   # Documentação adicional
```

## 🚀 Quick Start

### Backend
```bash
cd backend
npm install
cp .env.example .env       # Configure variáveis de ambiente
npm run migrate             # Rodar migrações
npm run dev                 # Iniciar servidor (porta 3000)
```

### App Flutter
```bash
cd app
flutter pub get
flutter run                 # Rodar no dispositivo/emulador
```

## 🔧 Homelab‑first (política recomendada)
- Objetivo: delegar *builds*, *testes* e tarefas pesadas ao **homelab** (host: `192.168.15.2`) para não sobrecarregar máquinas de desenvolvimento.
- CI: workflows críticos (Build / Test) **devem** usar runners self-hosted (label `homelab`). A verificação automática `scripts/verify-homelab-preference.sh` falhará se essa regra for violada.

Como usar o homelab rapidamente:
```bash
# execução manual de build/tests no homelab (script de conveniência)
./scripts/homelab/run-on-homelab.sh "cd /home/homelab/estou-aqui && docker compose build && docker compose up -d"

# forçar orquestrador remoto (dev/CI)
export REMOTE_ORCHESTRATOR_ENABLED=true
export HOMELAB_HOST=192.168.15.2
```

Segurança / secrets:
- Armazene credenciais e chaves SSH no **Secrets Agent** (porta 8088) e referencie via `SECRETS_AGENT_URL` + `SECRETS_AGENT_API_KEY`.
- Política importante: **questões relacionadas a IA (modelos, Modelfiles, training, etc.) devem ser submetidas ao repositório pai `eddie-auto-dev`** — veja `docs/AI_COMMIT_POLICY.md` para detalhes.
- Use o helper: `scripts/secrets-agent/register-homelab-secrets.sh` (modelo) para inserir segredos no cofre local.

Por que isso ajuda: reduz uso de CPU/RAM no laptop, garante consistência de ambiente de build e habilita runners mais potentes para E2E/Selenium.  

## �️ Visualização do Mapa

O mapa exibe:
- **Seu Ponto de Localização** — Círculo azul com halo, indicando sua posição atual via GPS
- **Áreas Circulares de Eventos** — Cada evento aparece como um círculo semitransparente, cujo raio varia conforme o número estimado de participantes
- **Marcadores de Eventos** — Ícone com emoji da categoria + número de confirmações, centralizado na área do evento
- **Zoom Adaptivo** — Toque no botão de localização para centralizar no seu ponto
- **Filtros de Categoria** — Filtre eventos por tipo (manifestação, protesto, marcha, etc.)

### Mudanças Recentes (v1.1)
✨ **Mapa Melhorado:**
- Localização do usuário agora visível com indicador visual ( pulsação/halo)
- Eventos exibidos com áreas circulares para melhor percepção da cobertura
- Melhor performance com marcadores em background renderizados primeiro

## �🛠️ Stack

| Camada     | Tecnologia                          |
|------------|-------------------------------------|
| Mobile     | Flutter 3.x + Dart                  |
| State Mgmt | Riverpod                            |
| Mapas      | Google Maps / OpenStreetMap (Leaflet)|
| Backend    | Node.js + Express.js                |
| Banco      | PostgreSQL + PostGIS                |
| Auth       | JWT + bcrypt                        |
| Realtime   | Socket.IO                           |
| Push       | Firebase Cloud Messaging            |

## 📋 Requisitos

- Flutter SDK >= 3.0
- Node.js >= 18
- PostgreSQL >= 15 com PostGIS
- Conta Google Maps API (ou usar OpenStreetMap)
- Conta Firebase (para notificações push)

## 📄 Licença

MIT
