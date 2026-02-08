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

## 🛠️ Stack

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
