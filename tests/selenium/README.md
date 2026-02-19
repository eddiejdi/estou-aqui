# Selenium E2E

Este teste automatizado abre o frontend, cria um evento e verifica se ele aparece após reload.

Pré-requisitos
- Chrome e Chromedriver instalados e disponíveis no PATH.
- App web rodando (ex: `flutter run -d chrome` ou `docker compose up`) em `http://localhost:PORT`.

Instalação

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r tests/selenium/requirements.txt
```

Executando

```bash
python tests/selenium/test_create_event.py --url http://localhost:34951/#/events

LinkedIn Page overview monitor

- Local run: LINKEDIN_PASSWORD="$LINKEDIN_PASSWORD" pytest tests/selenium/test_linkedin_overview.py::test_linkedin_page_overview_contains_rpa4all
- CI: workflow `.github/workflows/selenium-linkedin-monitor.yml` (scheduled). Requires repository secret `LINKEDIN_PASSWORD` for the admin account `edenilson.adm@gmail.com`.
```

Observações
- Caso o Chromedriver não esteja no PATH, ajuste o `webdriver.Chrome()` para usar `Service('/path/to/chromedriver')`.
- O teste usa geolocalização simulada (São Paulo) via CDP.
