"""
Teste de validação: verifica se os erros COOP foram corrigidos
e se os eventos carregam corretamente no mapa.
"""
import time
import requests
import json
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

API = "http://localhost:3000/api"
APP = "http://localhost:8081"

def create_test_user():
    """Criar usuário e retornar token"""
    ts = int(time.time())
    email = f"fix_test_{ts}@example.com"
    resp = requests.post(f"{API}/auth/register", json={
        "name": "Fix Test User",
        "email": email,
        "password": "Test123!@#"
    })
    if resp.status_code in (200, 201):
        data = resp.json()
        return data.get("token"), email
    return None, email

def check_api_events():
    """Verificar se API retorna eventos"""
    resp = requests.get(f"{API}/events?limit=5")
    data = resp.json()
    events = data.get("events", [])
    return len(events), events

def check_api_headers():
    """Verificar headers COOP do backend"""
    resp = requests.head(f"{API}/events")
    coop = resp.headers.get("Cross-Origin-Opener-Policy", "NOT SET")
    cors = resp.headers.get("Access-Control-Allow-Origin", "NOT SET")
    return coop, cors

def test_browser():
    """Abrir app no Chrome e verificar console"""
    token, email = create_test_user()
    
    print("=" * 60)
    print("TESTE DE VALIDAÇÃO - Correção COOP + Eventos no Mapa")
    print("=" * 60)
    
    # 1. Verificar headers
    coop, cors = check_api_headers()
    print(f"\n[1/5] Headers da API:")
    print(f"  COOP: {coop}")
    print(f"  CORS: {cors}")
    coop_ok = "allow-popups" in coop
    print(f"  {'✅' if coop_ok else '❌'} COOP permite popups: {coop_ok}")
    
    # 2. Verificar eventos na API
    count, events = check_api_events()
    print(f"\n[2/5] Eventos na API:")
    print(f"  Total: {count}")
    for e in events[:3]:
        print(f"  - {e.get('title')} ({e.get('status')}) @ ({e.get('latitude')}, {e.get('longitude')})")
    
    # 3. Abrir browser
    print(f"\n[3/5] Abrindo browser...")
    opts = Options()
    opts.add_argument("--headless=new")
    opts.add_argument("--no-sandbox")
    opts.add_argument("--disable-dev-shm-usage")
    opts.add_argument("--disable-gpu")
    opts.add_argument("--window-size=1280,900")
    opts.set_capability("goog:loggingPrefs", {"browser": "ALL"})
    
    driver = webdriver.Chrome(options=opts)
    
    try:
        # Abrir app
        driver.get(APP)
        time.sleep(3)
        
        # Injetar token no localStorage
        if token:
            driver.execute_script(f"""
                window.localStorage.setItem('auth_token', '{token}');
                console.log('🔑 Token injetado para: {email}');
            """)
            print(f"  ✅ Token injetado: {token[:30]}...")
        
        # Navegar para o mapa
        driver.get(f"{APP}/#/map")
        time.sleep(5)
        
        print(f"  URL atual: {driver.current_url}")
        print(f"  Título: {driver.title}")
        
        # Screenshot
        driver.save_screenshot("/tmp/fix_validation.png")
        print(f"  📸 Screenshot: /tmp/fix_validation.png")
        
        # 4. Analisar logs do console
        print(f"\n[4/5] Logs do console:")
        logs = driver.get_log("browser")
        
        severe_errors = []
        warnings = []
        info_logs = []
        coop_errors = 0
        connection_errors = 0
        
        for log in logs:
            msg = log.get("message", "")
            level = log.get("level", "")
            
            if "Cross-Origin-Opener-Policy" in msg:
                coop_errors += 1
            elif "Could not establish connection" in msg:
                connection_errors += 1
            elif level == "SEVERE":
                severe_errors.append(msg[:120])
            elif level == "WARNING":
                warnings.append(msg[:120])
            else:
                # Capturar nossos logs de debug
                if any(x in msg for x in ["📍", "🔄", "✅", "❌", "📡", "🔐", "⚠️"]):
                    info_logs.append(msg[:150])
        
        print(f"  COOP errors: {coop_errors} {'✅ (0)' if coop_errors == 0 else '⚠️'}")
        print(f"  Connection errors: {connection_errors} {'✅ (0)' if connection_errors == 0 else '⚠️'}")
        print(f"  Erros graves: {len(severe_errors)}")
        for e in severe_errors[:5]:
            print(f"    ❌ {e}")
        print(f"  Avisos: {len(warnings)}")
        for w in warnings[:3]:
            print(f"    ⚠️ {w}")
        print(f"  Logs de debug do app:")
        for l in info_logs:
            print(f"    📋 {l}")
        
        # Aguardar mais para ver se os eventos carregam
        time.sleep(5)
        
        # Verificar novos logs
        logs2 = driver.get_log("browser")
        for log in logs2:
            msg = log.get("message", "")
            if any(x in msg for x in ["📍", "🔄", "✅", "❌", "📡", "🔐", "⚠️", "eventos"]):
                info_logs.append(msg[:150])
                print(f"    📋 {msg[:150]}")
        
        # 5. Resultado final
        print(f"\n[5/5] RESULTADO:")
        all_ok = coop_errors == 0 and connection_errors == 0 and len(severe_errors) == 0
        print(f"  COOP fix: {'✅ OK' if coop_errors == 0 else '❌ FALHOU'}")
        print(f"  Connection fix: {'✅ OK' if connection_errors == 0 else '❌ FALHOU'}")
        print(f"  Sem erros graves: {'✅ OK' if len(severe_errors) == 0 else '❌ FALHOU'}")
        print(f"  Eventos na API: {'✅ OK' if count > 0 else '❌ NENHUM'}")
        print(f"  GERAL: {'✅ TUDO OK' if all_ok else '⚠️ PROBLEMAS ENCONTRADOS'}")
        
    finally:
        driver.quit()

if __name__ == "__main__":
    test_browser()
