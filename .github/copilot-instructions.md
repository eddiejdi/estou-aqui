# Estou Aqui — Copilot Instructions

## Architecture Overview

Full-stack social movement monitoring app: **Flutter mobile/web** (`app/`) + **Node.js/Express API** (`backend/`) + **PostgreSQL**. Real-time features via **Socket.IO**. Production URL: `https://estouaqui.rpa4all.com`.

```
Flutter App (Riverpod + GoRouter + Dio)
    ↕ REST + Socket.IO
Express API (:3000) → PostgreSQL (Sequelize ORM)
    ↕ Socket.IO (chat, check-ins, estimates)
Firebase Cloud Messaging (push notifications)
```

## Backend (Node.js/Express)

- **Entry point**: `backend/src/server.js` — creates Express app + HTTP server + Socket.IO. Exports `{ app, server, io, start }`. Only calls `start()` when `require.main === module && NODE_ENV !== 'test'`.
- **Models**: Sequelize models in `backend/src/models/` — factory pattern (`module.exports = (sequelize) => {...}`). Associations defined in `models/index.js`. All IDs are `UUID`.
- **Key domain models**: `User`, `Event` (9 categories: manifestacao, protesto, marcha, etc.), `Checkin`, `ChatMessage`, `CrowdEstimate`, `Coalition`, `TelegramGroup`, `BetaSignup`, `WebChatMessage`.
- **Routes**: RESTful in `backend/src/routes/` — all prefixed `/api/` (auth, events, checkins, chat, estimates, notifications, alerts, telegram-groups, beta-signup, coalitions, webchat).
- **Auth**: JWT Bearer tokens in `middleware/auth.js`. Three middlewares: `auth` (required), `optionalAuth`, `requireRole(...roles)`.
- **Services**: `crowdEstimation.js` (density × area + check-in multiplier), `socket.js` (real-time chat/events), `alert-socket.js`, `alerting.js`, `pushNotification.js` (Firebase Admin SDK).
- **DB config**: `backend/src/config/database.js` — env-based (development/test/production). Dev auto-syncs with `{ alter: true }`.
- **Prometheus metrics**: `prom-client` at `/metrics` endpoint.

## Flutter App

- **State management**: Riverpod (`flutter_riverpod`). Providers defined in `lib/providers/app_providers.dart` — singleton services (`ApiService`, `LocationService`, `GeocodeService`, `SocketService`) + `AuthNotifier` as `StateNotifier<AsyncValue<User?>>`.
- **Routing**: GoRouter in `lib/router.dart`. `ShellRoute` wraps main tabs (`/map`, `/events`, `/coalitions`, `/notifications`, `/profile`) inside `HomeScreen`. Standalone routes: `/login`, `/register`, `/event/create`, `/event/:id`, `/chat/:eventId`.
- **API client**: `lib/services/api_service.dart` — singleton `Dio` instance pointing to `AppConstants.apiBaseUrl`. Auto-injects JWT from `FlutterSecureStorage`. Web fallback to `localStorage`.
- **Real-time**: `lib/services/socket_service.dart` — singleton wrapping `socket_io_client`. Exposes `Stream<ChatMessage>`, `Stream<Map>` for estimates and check-ins.
- **Models**: `lib/models/` — use `Equatable`. `EventCategory` enum mirrors backend categories with `label` and `emoji` getters. Parse with `fromString()` / `fromJson()`.
- **Constants**: `lib/utils/constants.dart` — API URL, default coordinates (São Paulo), density levels, category mappings.
- **Offline support**: `CheckinRetryService` initializes at startup to retry pending check-ins.
- **Code generation**: Uses `build_runner` + `json_serializable` + `freezed` + `riverpod_generator`. Run `flutter pub run build_runner build` after model changes.

## Development Workflow

```bash
# Backend
cd backend && npm install && npm run dev     # Express on :3000

# Flutter
cd app && flutter pub get && flutter run     # Mobile/web

# Docker (full stack)
docker compose up                            # postgres:5432 + api:3000 + web:80

# Tests
cd backend && npm test                       # Jest with coverage
cd app && flutter test                       # Flutter widget tests
cd tests/selenium && pytest test_auth.py     # Selenium E2E (Python, web app)
```

## Key Conventions

- **Language**: All user-facing strings, API error messages, and comments are in **Brazilian Portuguese**.
- **Event categories** are a closed enum — must match across `Event.js` model ENUM, `event.dart` `EventCategory`, and `constants.dart`. When adding a category, update all three.
- **Socket.IO events** follow `namespace:action` pattern: `event:join`, `chat:send`, `chat:message`, `estimate:updated`, `checkin:new`.
- **CI**: GitHub Actions on self-hosted runner (`homelab`). Runs `npm test` for backend, `flutter analyze` + `flutter test` for app. See `.github/workflows/ci.yml`.
- **Crowd estimation algorithm** in `backend/src/services/crowdEstimation.js`: combines check-in count × adjustment factor with density × area calculation. Density levels are env-configurable (`CROWD_DENSITY_LOW`, etc.).
- **Docker networking**: Inside containers, use service hostnames (`postgres`, not `localhost`). The API container reaches external agent bus via Docker host gateway (`172.17.0.1`).

## Testing

- **Backend**: Jest tests in `backend/__tests__/{routes,services,helpers}/`. Config in `jest.config.js`. Coverage excludes `server.js`. Test DB uses `estou_aqui_test`.
- **Selenium E2E**: Python tests in `tests/selenium/` targeting the Flutter web build. Uses `conftest.py` + `selenium_helpers.py` for shared fixtures.
- **Flutter**: Widget tests in `app/test/`.

## File Patterns to Follow

- New backend routes: create `backend/src/routes/<name>.js`, register in `server.js` with `app.use('/api/<name>', route)`.
- New Sequelize models: factory in `backend/src/models/<Name>.js`, import + associate in `models/index.js`.
- New Flutter screens: `app/lib/screens/<feature>/<name>_screen.dart`, add route in `router.dart`.
- New Flutter providers: add to `app/lib/providers/app_providers.dart`.
