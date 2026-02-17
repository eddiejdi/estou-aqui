# Estou Aqui — Relatório de Screenshots & Integração Grafana

> **Data:** 2026-02-17 | **Build:** Flutter Web Release (CanvasKit + WASM)

---

## 1. Screenshots Capturados

| # | Tela | Arquivo | Tamanho | Descrição |
|---|------|---------|---------|-----------|
| 01 | Splash | `01_splash.png` | 49 KB | Tela de carregamento inicial com logo |
| 02 | Login | `02_login.png` | 49 KB | Tela de login (Google Sign-In + e-mail) |
| 03 | Registro | `03_register.png` | 67 KB | Cadastro de novo usuário |
| 04 | Lista de Eventos | `04_events_list.png` | 87 KB | Feed de eventos com banner de ad, cards de evento |
| 05 | Lista de Coalizões | `05_coalitions_list.png` | 89 KB | Coalizões ativas — agrupa protestos da mesma causa |
| 06 | Perfil | `06_profile.png` | 33 KB | Perfil do usuário com menu de assinatura |
| 07 | Detalhe do Evento | `07_event_detail.png` | 48 KB | Detalhe com botão "Vincular à Coalizão" |
| 08 | Detalhe da Coalizão | `08_coalition_detail.png` | 19 KB | Coalizão com abas: Eventos, Mapa, Impacto, Dashboard |
| 09 | Blue Check | `09_blue_check.png` | 112 KB | Verificação premium (selo azul) |
| 10 | Notificações | `10_notifications.png` | 44 KB | Feed de notificações |

---

## 2. Integração Grafana — Fluxo Implementado

### 2.1 Infraestrutura
- **Grafana:** `192.168.15.2:3002` (Docker) → público via `https://www.rpa4all.com/grafana`
- **Pasta:** "Estou Aqui - Eventos" (uid: `estou-aqui-eventos`)
- **Dashboards públicos** (sem autenticação necessária):
  - Evento: `20724d6938144eeba8287cfb475bcf52` (11 painéis)
  - Coalizão: `eb027d48df8e4c948975669d3be5ac54` (8 painéis)

### 2.2 Painéis do Dashboard de Evento
1. Participantes Confirmados
2. Estimativa de Público
3. Check-ins Ativos
4. Densidade
5. Check-ins ao Longo do Tempo
6. Estimativas de Público
7. Últimos Check-ins
8. Distribuição por Método
9. Mensagens no Chat
10. Grupos Telegram
11. Duração

### 2.3 Painéis do Dashboard de Coalizão
1. Total Eventos Ativos
2. Total Participantes
3. Cidades com Eventos
4. Coalizões Ativas
5. Eventos por Dia
6. Participantes por Cidade
7. Eventos por Categoria
8. Coalizões com Maior Impacto

### 2.4 Acesso Restrito
- **Usuários NÃO acessam painéis do homelab** — somente dashboards públicos de eventos
- Iframe embedado via `HtmlElementView` (web) com token público
- Nativo (Android/iOS): dashboard simulado com KPIs e gráficos
- Desbloqueio via assinatura premium (R$ 14,90/mês)

---

## 3. Feature: Reunir Protestos (Coalizão)

### 3.1 Fluxo de Vinculação
1. Usuário abre evento sem coalizão → botão **"Vincular à Coalizão"** aparece
2. Bottom sheet lista coalizões disponíveis (via `ApiService().getCoalitions()`)
3. Ao selecionar, chama `ApiService().joinCoalition(coalitionId, eventId)`
4. Evento passa a fazer parte da coalizão

### 3.2 Dashboard da Coalizão
- **4 abas:** Eventos | Mapa | Impacto | Dashboard
- Dashboard Grafana mostra métricas agregadas de todos os eventos vinculados
- Suporte web (iframe real) e nativo (dashboard simulado)

### 3.3 Arquivos Modificados
- `lib/screens/event/event_detail_screen.dart` — botão _JoinCoalitionButton
- `lib/screens/coalition/coalition_detail_screen.dart` — aba Dashboard + iframe Grafana
- `lib/screens/coalition/coalition_grafana_stub.dart` — stub para compilação nativa

---

## 4. Testes Executados

| Suite | Resultado | Detalhes |
|-------|-----------|----------|
| Flutter Analyze | ✅ 0 erros prod | Único erro em test/widget_test.dart (MyApp) |
| Backend (Jest) | ✅ 7/7 passed | 2 suites, 14.3s |
| Python Integration | ✅ 3 passed, 3 failed* | *Falhas esperadas: Prometheus/Alertmanager offline local |
| Web Build | ✅ Success | 300.5s (CanvasKit + WASM) |

---

## 5. Estrutura de Prints

```
prints/
├── 01_splash.png          # Tela de splash/loading
├── 02_login.png           # Login com Google Sign-In
├── 03_register.png        # Cadastro de usuário
├── 04_events_list.png     # Lista de eventos (com ad banner)
├── 05_coalitions_list.png # Lista de coalizões
├── 06_profile.png         # Perfil do usuário
├── 07_event_detail.png    # Detalhe do evento + vincular coalizão
├── 08_coalition_detail.png # Detalhe da coalizão (4 abas)
├── 09_blue_check.png      # Verificação premium
└── 10_notifications.png   # Notificações
```
