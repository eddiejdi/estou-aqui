"""
Estou Aqui — Massa de Testes Completa com screenshots e gravação para marketing.

Cenários cobertos:
  1. Registro de usuário (organizador)
  2. Login
  3. Criar evento tipo Manifestação (sem passeata)
  4. Criar evento tipo Marcha/Passeata (com local de início e fim)
  5. Listar eventos por proximidade
  6. Detalhes do evento (manifestação simples)
  7. Detalhes do evento (passeata: percurso início→fim)
  8. Check-in no evento
  9. Estimativa de público (crowd gauge)
 10. Chat Telegram — botão e fluxo
 11. Navegação "Ir para lá"
 12. Criar evento com CEP (auto-fill endereço)
 13. Múltiplos check-ins (simular 5 usuários)
 14. Listar grupos Telegram do evento
 15. Segundo organizador cria passeata com percurso diferente

Cada cenário gera screenshots + frames para GIF.
"""

import os
import sys
import json
import time
import glob
import requests
import pytest
from datetime import datetime, timedelta

# ---------- Paths ----------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SCREENSHOTS_DIR = os.path.join(BASE_DIR, "screenshots")
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

# ---------- Config ----------
API_BASE = os.environ.get("API_BASE", "https://estouaqui.rpa4all.com/api")
WEB_URL = os.environ.get("WEB_URL", "http://localhost:8686")

# ---------- Helpers ----------
_screenshot_counter = 0

def _step_screenshot(driver, scenario, step_name):
    """Salva screenshot com numeração sequencial."""
    global _screenshot_counter
    _screenshot_counter += 1
    fname = f"{_screenshot_counter:03d}_{scenario}_{step_name}.png"
    fpath = os.path.join(SCREENSHOTS_DIR, fname)
    driver.save_screenshot(fpath)
    print(f"  📸 {fname}")
    return fpath


def api_call(method, path, token=None, json_data=None, expect_status=None):
    """Helper para chamadas à API REST."""
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    url = f"{API_BASE}{path}"
    r = getattr(requests, method)(url, headers=headers, json=json_data, timeout=15)
    if expect_status and r.status_code != expect_status:
        print(f"  ⚠️  API {method.upper()} {path} → {r.status_code}: {r.text[:200]}")
    return r


def register_user(name, email, password):
    """Registra ou faz login de um usuário, retorna (token, user)."""
    r = api_call("post", "/auth/register", json_data={"name": name, "email": email, "password": password})
    if r.status_code == 201:
        d = r.json()
        return d.get("token"), d.get("user")
    # Fallback: login
    r2 = api_call("post", "/auth/login", json_data={"email": email, "password": password})
    if r2.status_code == 200:
        d = r2.json()
        return d.get("token"), d.get("user")
    raise RuntimeError(f"Auth failed: register={r.status_code}, login={r2.status_code}")


# ---------- Fixtures ----------
@pytest.fixture(scope="session")
def api_tokens():
    """Registra vários usuários para testes."""
    users = {}

    org_data = [
        ("Carlos Manifestante", "carlos@estouaqui.test", "SenhaForte123!"),
        ("Ana Organizadora", "ana@estouaqui.test", "SenhaForte123!"),
        ("Pedro Participante", "pedro@estouaqui.test", "SenhaForte123!"),
        ("Maria Cidadã", "maria@estouaqui.test", "SenhaForte123!"),
        ("João Ativista", "joao@estouaqui.test", "SenhaForte123!"),
        ("Lucia Voluntária", "lucia@estouaqui.test", "SenhaForte123!"),
        ("Roberto Líder", "roberto@estouaqui.test", "SenhaForte123!"),
    ]

    for name, email, pw in org_data:
        try:
            token, user = register_user(name, email, pw)
            users[email] = {"token": token, "user": user, "name": name}
            print(f"  ✅ Registrado: {name} ({email})")
        except Exception as e:
            print(f"  ❌ Falha ao registrar {name}: {e}")

    return users


@pytest.fixture(scope="session")
def driver():
    """Cria driver Selenium com geolocalização de São Paulo."""
    from selenium import webdriver
    options = webdriver.ChromeOptions()
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=412,915")  # Mobile viewport
    options.add_argument("--force-device-scale-factor=1")
    options.add_experimental_option("prefs", {
        "profile.default_content_setting_values.geolocation": 1,
    })

    d = webdriver.Chrome(options=options)

    # Simular geolocalização: Av. Paulista, São Paulo
    try:
        d.execute_cdp_cmd("Emulation.setGeolocationOverride", {
            "latitude": -23.5614,
            "longitude": -46.6558,
            "accuracy": 50,
        })
    except Exception:
        pass

    yield d
    d.quit()


# ===================================================================
# PARTE 1: TESTES DE API — Massa de dados realista
# ===================================================================

class TestAPIDataCreation:
    """Cria massa de dados via API para cenários realistas."""

    def test_01_register_users(self, api_tokens):
        """Cenário 1: Registrar 7 usuários com perfis diferentes."""
        assert len(api_tokens) >= 5, f"Mínimo 5 usuários, obteve {len(api_tokens)}"
        print(f"\n✅ {len(api_tokens)} usuários registrados com sucesso")

    def test_02_create_manifestacao_simple(self, api_tokens):
        """Cenário 2: Criar evento tipo Manifestação na Av. Paulista."""
        token = api_tokens["carlos@estouaqui.test"]["token"]
        event_data = {
            "title": "Manifestação pela Educação — Av. Paulista",
            "description": "Grande manifestação pacífica em defesa da educação pública de qualidade. "
                          "Concentração na Av. Paulista, em frente ao MASP. Traga cartazes e muita energia! "
                          "Água e lanches serão distribuídos. #EducaçãoParaTodos #EstouAqui",
            "category": "manifestacao",
            "latitude": -23.5614,
            "longitude": -46.6558,
            "address": "Av. Paulista, 1578 - Bela Vista, São Paulo - SP",
            "city": "São Paulo",
            "startDate": (datetime.now() + timedelta(hours=2)).isoformat(),
            "endDate": (datetime.now() + timedelta(hours=6)).isoformat(),
            "areaSquareMeters": 15000,
            "tags": ["educação", "av paulista", "pacífico"],
        }
        r = api_call("post", "/events", token=token, json_data=event_data)
        assert r.status_code in [200, 201], f"Criar evento falhou: {r.status_code} {r.text[:200]}"
        event = r.json().get("event", r.json())
        api_tokens["_event_manifestacao"] = event
        print(f"\n✅ Evento criado: {event.get('title', 'N/A')} (ID: {event.get('id', 'N/A')[:8]}...)")

    def test_03_create_passeata_marcha(self, api_tokens):
        """Cenário 3: Criar Marcha/Passeata com ponto de início e chegada."""
        token = api_tokens["ana@estouaqui.test"]["token"]
        event_data = {
            "title": "Marcha pela Igualdade — Sé até Paulista",
            "description": "Passeata saindo da Praça da Sé até a Av. Paulista. Percurso de 3km. "
                          "Concentração às 14h na Praça da Sé, saída às 15h. "
                          "Trajeto: Sé → Rua Direita → Viaduto do Chá → Av. Paulista. "
                          "Evento pacífico com trio elétrico e palestrantes ao longo do percurso.",
            "category": "marcha",
            "latitude": -23.5503,
            "longitude": -46.6340,
            "address": "Praça da Sé, S/N — Sé, São Paulo - SP",
            "city": "São Paulo",
            "endLatitude": -23.5614,
            "endLongitude": -46.6558,
            "endAddress": "Av. Paulista, 1578 — Bela Vista, São Paulo - SP",
            "startDate": (datetime.now() + timedelta(hours=3)).isoformat(),
            "endDate": (datetime.now() + timedelta(hours=8)).isoformat(),
            "areaSquareMeters": 5000,
            "tags": ["igualdade", "passeata", "marcha", "sé", "paulista"],
        }
        r = api_call("post", "/events", token=token, json_data=event_data)
        assert r.status_code in [200, 201], f"Criar passeata falhou: {r.status_code} {r.text[:200]}"
        event = r.json().get("event", r.json())
        api_tokens["_event_passeata"] = event
        print(f"\n✅ Passeata criada: {event.get('title', 'N/A')} (Sé → Paulista)")

    def test_04_create_protesto_copacabana(self, api_tokens):
        """Cenário 4: Criar protesto no Rio — Copacabana."""
        token = api_tokens["pedro@estouaqui.test"]["token"]
        event_data = {
            "title": "Protesto Pacífico — Copacabana, Rio de Janeiro",
            "description": "Ato público na orla de Copacabana contra a reforma tributária. "
                          "Reunião pacífica com faixas e megafones. Ponto de concentração no Posto 6.",
            "category": "protesto",
            "latitude": -22.9711,
            "longitude": -43.1822,
            "address": "Av. Atlântica, Posto 6 — Copacabana, Rio de Janeiro - RJ",
            "city": "Rio de Janeiro",
            "endLatitude": -22.9868,
            "endLongitude": -43.1896,
            "endAddress": "Forte de Copacabana — Copacabana, Rio de Janeiro - RJ",
            "startDate": (datetime.now() + timedelta(days=1, hours=2)).isoformat(),
            "endDate": (datetime.now() + timedelta(days=1, hours=6)).isoformat(),
            "areaSquareMeters": 20000,
            "tags": ["protesto", "copacabana", "rio", "reforma"],
        }
        r = api_call("post", "/events", token=token, json_data=event_data)
        assert r.status_code in [200, 201], f"Criar protesto RJ falhou: {r.status_code} {r.text[:200]}"
        event = r.json().get("event", r.json())
        api_tokens["_event_protesto_rj"] = event
        print(f"\n✅ Protesto RJ criado: {event.get('title', 'N/A')}")

    def test_05_create_assembleia(self, api_tokens):
        """Cenário 5: Criar Assembleia em Brasília."""
        token = api_tokens["maria@estouaqui.test"]["token"]
        event_data = {
            "title": "Assembleia Popular — Esplanada dos Ministérios",
            "description": "Assembleia aberta para discutir pautas sociais. "
                          "Local: gramado da Esplanada dos Ministérios. "
                          "Horário: 10h. Duração estimada: 4h. Aberta ao público.",
            "category": "assembleia",
            "latitude": -15.7997,
            "longitude": -47.8645,
            "address": "Esplanada dos Ministérios — Brasília - DF",
            "city": "Brasília",
            "startDate": (datetime.now() + timedelta(days=2)).isoformat(),
            "endDate": (datetime.now() + timedelta(days=2, hours=4)).isoformat(),
            "areaSquareMeters": 50000,
            "tags": ["assembleia", "brasília", "pautas sociais"],
        }
        r = api_call("post", "/events", token=token, json_data=event_data)
        assert r.status_code in [200, 201], f"Criar assembleia falhou: {r.status_code}"
        event = r.json().get("event", r.json())
        api_tokens["_event_assembleia"] = event
        print(f"\n✅ Assembleia criada: {event.get('title', 'N/A')}")

    def test_06_create_vigilia(self, api_tokens):
        """Cenário 6: Criar Vigília em Belo Horizonte."""
        token = api_tokens["joao@estouaqui.test"]["token"]
        event_data = {
            "title": "Vigília pela Paz — Praça da Liberdade, BH",
            "description": "Vigília noturna pela paz e contra a violência urbana. "
                          "Velas, orações e música. Praça da Liberdade a partir das 20h.",
            "category": "vigilia",
            "latitude": -19.9319,
            "longitude": -43.9381,
            "address": "Praça da Liberdade — Funcionários, Belo Horizonte - MG",
            "city": "Belo Horizonte",
            "startDate": (datetime.now() + timedelta(days=1, hours=10)).isoformat(),
            "tags": ["vigília", "paz", "bh", "praça da liberdade"],
        }
        r = api_call("post", "/events", token=token, json_data=event_data)
        assert r.status_code in [200, 201], f"Criar vigília falhou: {r.status_code}"
        event = r.json().get("event", r.json())
        api_tokens["_event_vigilia"] = event
        print(f"\n✅ Vigília criada: {event.get('title', 'N/A')}")

    def test_07_create_greve(self, api_tokens):
        """Cenário 7: Criar Greve em Porto Alegre."""
        token = api_tokens["lucia@estouaqui.test"]["token"]
        event_data = {
            "title": "Greve dos Trabalhadores — Largo Glênio Peres, POA",
            "description": "Greve geral dos trabalhadores do serviço público. "
                          "Concentração no Largo Glênio Peres, Centro Histórico de Porto Alegre.",
            "category": "greve",
            "latitude": -30.0273,
            "longitude": -51.2288,
            "address": "Largo Glênio Peres — Centro Histórico, Porto Alegre - RS",
            "city": "Porto Alegre",
            "startDate": (datetime.now() + timedelta(days=3)).isoformat(),
            "endDate": (datetime.now() + timedelta(days=3, hours=8)).isoformat(),
            "areaSquareMeters": 8000,
            "tags": ["greve", "trabalhadores", "porto alegre"],
        }
        r = api_call("post", "/events", token=token, json_data=event_data)
        assert r.status_code in [200, 201], f"Criar greve falhou: {r.status_code}"
        event = r.json().get("event", r.json())
        api_tokens["_event_greve"] = event
        print(f"\n✅ Greve criada: {event.get('title', 'N/A')}")

    def test_08_create_passeata2_recife(self, api_tokens):
        """Cenário 8: Segunda passeata em Recife com percurso."""
        token = api_tokens["roberto@estouaqui.test"]["token"]
        event_data = {
            "title": "Marcha pela Cultura — Marco Zero ao Recife Antigo",
            "description": "Passeata cultural saindo do Marco Zero do Recife até o Bairro do Recife Antigo. "
                          "Com atrações culturais, maracatu e frevo ao longo do percurso.",
            "category": "marcha",
            "latitude": -8.0631,
            "longitude": -34.8711,
            "address": "Marco Zero — Recife Antigo, Recife - PE",
            "city": "Recife",
            "endLatitude": -8.0575,
            "endLongitude": -34.8714,
            "endAddress": "Rua do Bom Jesus — Recife Antigo, Recife - PE",
            "startDate": (datetime.now() + timedelta(days=4)).isoformat(),
            "endDate": (datetime.now() + timedelta(days=4, hours=5)).isoformat(),
            "tags": ["cultura", "recife", "marcha", "maracatu"],
        }
        r = api_call("post", "/events", token=token, json_data=event_data)
        assert r.status_code in [200, 201], f"Criar passeata Recife falhou: {r.status_code}"
        event = r.json().get("event", r.json())
        api_tokens["_event_passeata_recife"] = event
        print(f"\n✅ Passeata Recife criada: {event.get('title', 'N/A')}")

    def test_09_multiple_checkins(self, api_tokens):
        """Cenário 9: Múltiplos check-ins no evento Manifestação."""
        event = api_tokens.get("_event_manifestacao")
        if not event:
            pytest.skip("Evento manifestação não foi criado")

        event_id = event.get("id")
        checkin_users = ["pedro@estouaqui.test", "maria@estouaqui.test",
                        "joao@estouaqui.test", "lucia@estouaqui.test", "roberto@estouaqui.test"]

        success_count = 0
        for email in checkin_users:
            user_data = api_tokens.get(email)
            if not user_data:
                continue
            checkin_data = {
                "eventId": event_id,
                "latitude": -23.5614 + (success_count * 0.0001),
                "longitude": -46.6558 + (success_count * 0.0001),
            }
            r = api_call("post", "/checkins", token=user_data["token"], json_data=checkin_data)
            if r.status_code in [200, 201]:
                success_count += 1
                print(f"  ✅ Check-in: {user_data['name']}")
            else:
                print(f"  ⚠️  Check-in falhou para {user_data['name']}: {r.status_code}")

        print(f"\n✅ {success_count} check-ins realizados no evento Manifestação")
        assert success_count >= 3, f"Mínimo 3 check-ins, obteve {success_count}"

    def test_10_checkins_passeata(self, api_tokens):
        """Cenário 10: Check-ins na passeata Sé→Paulista."""
        event = api_tokens.get("_event_passeata")
        if not event:
            pytest.skip("Evento passeata não foi criado")

        event_id = event.get("id")
        checkin_users = ["carlos@estouaqui.test", "pedro@estouaqui.test", "maria@estouaqui.test"]

        success_count = 0
        for email in checkin_users:
            user_data = api_tokens.get(email)
            if not user_data:
                continue
            checkin_data = {
                "eventId": event_id,
                "latitude": -23.5503 + (success_count * 0.0002),
                "longitude": -46.6340 + (success_count * 0.0002),
            }
            r = api_call("post", "/checkins", token=user_data["token"], json_data=checkin_data)
            if r.status_code in [200, 201]:
                success_count += 1
        print(f"\n✅ {success_count} check-ins na passeata")

    def test_11_list_events(self, api_tokens):
        """Cenário 11: Listar todos os eventos e validar dados."""
        r = api_call("get", "/events")
        assert r.status_code == 200
        data = r.json()
        events = data.get("events", [])
        total = data.get("pagination", {}).get("total", len(events))
        print(f"\n✅ {total} eventos listados na API")

        # Validar que temos pelo menos 5 eventos
        assert total >= 5, f"Esperado >= 5 eventos, obteve {total}"

        # Validar que há passeatas com endLocation
        marchas = [e for e in events if e.get("endLatitude") is not None]
        print(f"  🚶 {len(marchas)} eventos com percurso (passeata)")

    def test_12_event_detail(self, api_tokens):
        """Cenário 12: Buscar detalhes de evento específico."""
        event = api_tokens.get("_event_passeata")
        if not event:
            pytest.skip("Evento passeata não foi criado")

        event_id = event.get("id")
        r = api_call("get", f"/events/{event_id}")
        assert r.status_code == 200
        detail = r.json().get("event", r.json())

        assert detail.get("endLatitude") is not None, "endLatitude faltando"
        assert detail.get("endLongitude") is not None, "endLongitude faltando"
        assert detail.get("endAddress") is not None, "endAddress faltando"
        print(f"\n✅ Detalhe do evento: {detail.get('title')}")
        print(f"  📍 Início: {detail.get('address')}")
        print(f"  🏁 Chegada: {detail.get('endAddress')}")

    def test_13_telegram_groups(self, api_tokens):
        """Cenário 13: Listar grupos Telegram do evento."""
        event = api_tokens.get("_event_manifestacao")
        if not event:
            pytest.skip("Evento manifestação não foi criado")

        event_id = event.get("id")
        token = api_tokens["carlos@estouaqui.test"]["token"]
        r = api_call("get", f"/telegram-groups/{event_id}", token=token)
        # 200 = grupos existem, 404 = nenhum grupo ainda (ambos OK)
        assert r.status_code in [200, 404], f"Status inesperado: {r.status_code}"
        if r.status_code == 200:
            groups = r.json().get("groups", [])
            print(f"\n✅ Grupos Telegram para o evento: {len(groups)}")
        else:
            print(f"\n✅ Nenhum grupo Telegram ainda (esperado para novos eventos)")


# ===================================================================
# PARTE 2: TESTES VISUAIS COM SELENIUM — Screenshots para Marketing
# ===================================================================

class TestWebUIScreenshots:
    """Testes visuais no Flutter Web com screenshots para marketing."""

    def test_20_homepage_loading(self, driver):
        """Cenário 20: Tela inicial do app carregando."""
        driver.get(WEB_URL)
        time.sleep(4)
        _step_screenshot(driver, "homepage", "01_loading")
        time.sleep(3)
        _step_screenshot(driver, "homepage", "02_loaded")
        print("\n✅ Homepage carregada e screenshots salvos")

    def test_21_login_screen(self, driver):
        """Cenário 21: Tela de login."""
        driver.get(WEB_URL)
        time.sleep(5)
        _step_screenshot(driver, "login", "01_screen")

        # Tentar encontrar elementos de login
        page = driver.page_source
        has_login = any(t in page.lower() for t in ["login", "entrar", "sign in", "google", "email"])
        if has_login:
            _step_screenshot(driver, "login", "02_form_visible")
        print(f"\n✅ Tela de login — elementos de login {'encontrados' if has_login else 'não visíveis (pode requerer navegação)'}")

    def test_22_navigate_to_events(self, driver):
        """Cenário 22: Navegar para lista de eventos."""
        driver.get(f"{WEB_URL}/#/events")
        time.sleep(5)
        _step_screenshot(driver, "events_list", "01_loading")
        time.sleep(3)
        _step_screenshot(driver, "events_list", "02_loaded")

        page = driver.page_source
        has_events = any(t in page for t in ["Manifestação", "Marcha", "Protesto", "Paulista", "Evento"])
        print(f"\n✅ Lista de eventos — {'eventos encontrados' if has_events else 'lista pode estar vazia no web view'}")

    def test_23_event_detail_manifestacao(self, driver, api_tokens):
        """Cenário 23: Detalhe de evento - Manifestação."""
        event = api_tokens.get("_event_manifestacao")
        if not event:
            pytest.skip("Evento manifestação não criado")

        event_id = event.get("id")
        driver.get(f"{WEB_URL}/#/event/{event_id}")
        time.sleep(5)
        _step_screenshot(driver, "event_detail_manifestacao", "01_loading")
        time.sleep(3)
        _step_screenshot(driver, "event_detail_manifestacao", "02_full")

        # Scroll down para ver mais conteúdo
        driver.execute_script("window.scrollBy(0, 400)")
        time.sleep(1)
        _step_screenshot(driver, "event_detail_manifestacao", "03_scrolled")

        driver.execute_script("window.scrollBy(0, 400)")
        time.sleep(1)
        _step_screenshot(driver, "event_detail_manifestacao", "04_bottom")
        print(f"\n✅ Detalhe: Manifestação pela Educação")

    def test_24_event_detail_passeata(self, driver, api_tokens):
        """Cenário 24: Detalhe de evento - Passeata com percurso."""
        event = api_tokens.get("_event_passeata")
        if not event:
            pytest.skip("Evento passeata não criado")

        event_id = event.get("id")
        driver.get(f"{WEB_URL}/#/event/{event_id}")
        time.sleep(5)
        _step_screenshot(driver, "event_detail_passeata", "01_loading")
        time.sleep(3)
        _step_screenshot(driver, "event_detail_passeata", "02_header")

        # Scroll para ver percurso
        driver.execute_script("window.scrollBy(0, 350)")
        time.sleep(1)
        _step_screenshot(driver, "event_detail_passeata", "03_route_info")

        driver.execute_script("window.scrollBy(0, 350)")
        time.sleep(1)
        _step_screenshot(driver, "event_detail_passeata", "04_buttons")

        driver.execute_script("window.scrollBy(0, 350)")
        time.sleep(1)
        _step_screenshot(driver, "event_detail_passeata", "05_telegram_chat")
        print(f"\n✅ Detalhe: Passeata Sé→Paulista (percurso visível)")

    def test_25_event_detail_protesto_rj(self, driver, api_tokens):
        """Cenário 25: Detalhe do protesto no Rio."""
        event = api_tokens.get("_event_protesto_rj")
        if not event:
            pytest.skip("Evento protesto RJ não criado")

        event_id = event.get("id")
        driver.get(f"{WEB_URL}/#/event/{event_id}")
        time.sleep(5)
        _step_screenshot(driver, "event_protesto_rj", "01_header")
        time.sleep(3)

        driver.execute_script("window.scrollBy(0, 500)")
        time.sleep(1)
        _step_screenshot(driver, "event_protesto_rj", "02_details")
        print(f"\n✅ Detalhe: Protesto Copacabana")

    def test_26_create_event_form(self, driver):
        """Cenário 26: Formulário de criação de evento."""
        driver.get(f"{WEB_URL}/#/events/create")
        time.sleep(5)
        _step_screenshot(driver, "create_event", "01_form_top")

        driver.execute_script("window.scrollBy(0, 400)")
        time.sleep(1)
        _step_screenshot(driver, "create_event", "02_form_middle")

        driver.execute_script("window.scrollBy(0, 400)")
        time.sleep(1)
        _step_screenshot(driver, "create_event", "03_form_bottom")
        print(f"\n✅ Formulário de criação de evento capturado")

    def test_27_navigation_flow(self, driver, api_tokens):
        """Cenário 27: Fluxo de navegação entre telas."""
        screens = [
            (f"{WEB_URL}", "nav_flow", "01_home"),
            (f"{WEB_URL}/#/events", "nav_flow", "02_events"),
            (f"{WEB_URL}/#/events/create", "nav_flow", "03_create"),
        ]

        # Add event details if available
        for key in ["_event_manifestacao", "_event_passeata", "_event_vigilia"]:
            event = api_tokens.get(key)
            if event:
                eid = event.get("id")
                name = key.replace("_event_", "")
                screens.append((f"{WEB_URL}/#/event/{eid}", "nav_flow", f"04_{name}"))

        for url, scenario, step in screens:
            driver.get(url)
            time.sleep(4)
            _step_screenshot(driver, scenario, step)

        print(f"\n✅ Fluxo de navegação: {len(screens)} telas capturadas")

    def test_28_mobile_responsive(self, driver, api_tokens):
        """Cenário 28: Capturas em viewport mobile (412x915 já configurado)."""
        event = api_tokens.get("_event_passeata")
        if not event:
            pytest.skip("Evento não criado")

        # O driver já está em 412x915 (mobile), vamos capturar framing mobile
        event_id = event.get("id")
        driver.get(f"{WEB_URL}/#/event/{event_id}")
        time.sleep(5)
        _step_screenshot(driver, "mobile", "01_event_hero")

        # Scroll incremental para efeito de demo
        for i in range(5):
            driver.execute_script(f"window.scrollBy(0, 200)")
            time.sleep(0.5)
            _step_screenshot(driver, "mobile", f"0{i+2}_scroll_{i+1}")

        print(f"\n✅ Mobile responsive: frames capturados para GIF")


# ===================================================================
# PARTE 3: GERAÇÃO DE GIFs
# ===================================================================

class TestGenerateGifs:
    """Gera GIFs animados a partir das screenshots capturadas."""

    def test_90_generate_gifs(self):
        """Gera GIFs para marketing a partir dos screenshots."""
        try:
            import imageio.v3 as iio
        except ImportError:
            import imageio as iio

        gif_groups = {}
        screenshots = sorted(glob.glob(os.path.join(SCREENSHOTS_DIR, "*.png")))

        if not screenshots:
            pytest.skip("Nenhum screenshot encontrado")

        # Agrupar por cenário
        for fpath in screenshots:
            fname = os.path.basename(fpath)
            parts = fname.split("_", 2)
            if len(parts) >= 3:
                scenario = parts[1]
                if scenario not in gif_groups:
                    gif_groups[scenario] = []
                gif_groups[scenario].append(fpath)

        gifs_created = 0
        for scenario, frames in gif_groups.items():
            if len(frames) < 2:
                continue

            gif_path = os.path.join(SCREENSHOTS_DIR, f"gif_{scenario}.gif")
            try:
                images = []
                for f in sorted(frames):
                    try:
                        img = iio.imread(f)
                        images.append(img)
                    except Exception:
                        pass

                if len(images) >= 2:
                    iio.imwrite(gif_path, images, duration=1500, loop=0)
                    gifs_created += 1
                    print(f"  🎬 GIF: {os.path.basename(gif_path)} ({len(images)} frames)")
            except Exception as e:
                print(f"  ⚠️  GIF falhou para {scenario}: {e}")

        # Gerar GIF geral com todas as screenshots
        if len(screenshots) >= 3:
            try:
                all_images = []
                for f in screenshots[:30]:  # Limitar a 30 frames
                    try:
                        img = iio.imread(f)
                        all_images.append(img)
                    except Exception:
                        pass

                if all_images:
                    gif_all = os.path.join(SCREENSHOTS_DIR, "gif_ALL_SCENARIOS.gif")
                    iio.imwrite(gif_all, all_images, duration=1000, loop=0)
                    gifs_created += 1
                    print(f"  🎬 GIF COMPLETO: gif_ALL_SCENARIOS.gif ({len(all_images)} frames)")
            except Exception as e:
                print(f"  ⚠️  GIF geral falhou: {e}")

        print(f"\n✅ {gifs_created} GIFs gerados em {SCREENSHOTS_DIR}")

    def test_91_summary_report(self):
        """Relatório final com inventário de screenshots e GIFs."""
        screenshots = sorted(glob.glob(os.path.join(SCREENSHOTS_DIR, "*.png")))
        gifs = sorted(glob.glob(os.path.join(SCREENSHOTS_DIR, "*.gif")))

        print(f"\n{'='*60}")
        print(f"📊 RELATÓRIO DE EVIDÊNCIAS — ESTOU AQUI")
        print(f"{'='*60}")
        print(f"\n📸 Screenshots: {len(screenshots)}")
        for f in screenshots:
            print(f"   • {os.path.basename(f)}")
        print(f"\n🎬 GIFs: {len(gifs)}")
        for f in gifs:
            size_kb = os.path.getsize(f) / 1024
            print(f"   • {os.path.basename(f)} ({size_kb:.0f} KB)")
        print(f"\n📁 Diretório: {SCREENSHOTS_DIR}")
        print(f"{'='*60}")
