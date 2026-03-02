#!/usr/bin/env python3
"""Teste correto: injetar auth ANTES de carregar a app"""
import time
import json
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium_helpers import register_and_login


def run():
    print('[15/02/2026 - 12:37] Teste com injeção PRÉ-APP...')
    
    # Criar driver padrão
    options = Options()
    options.add_argument('--disable-gpu')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    
    driver = webdriver.Chrome(options=options)
    
    try:
        api_base = 'http://localhost:3000/api'
        
        # Registrar usuário
        name ='E2EUser'
        email = f'e2e_user_{int(time.time())}@example.com'
        password = 'password123'
        
        print(f'📝 Criando usuário: {email}')
        token, user = register_and_login(api_base, name, email, password)
        print(f'✅ Usuário criado!')
        
        # PASSO CRÍTICO: Injetar token na página em branco ANTES de carregar a app
        print('\n🔐 Injetando autenticação PRÉ-LOAD...')
        # Usar localhost em vez de data: URL para permitir localStorage
        driver.get('http://localhost:3000/blank.html' if False else 'http://localhost:8081/')  
        time.sleep(1)
        
        # Injetar localStorage ANTES de qualquer coisa
        driver.execute_script("""
            // Try both localStorage and sessionStorage
            localStorage.setItem('auth_token', arguments[0]);
            localStorage.setItem('current_user', arguments[1]);
            sessionStorage.setItem('auth_token', arguments[0]);
            sessionStorage.setItem('current_user', arguments[1]);
            
            //  Simulate flutter_secure_storage web behavior
            const key = 'flutter_secure_storage-auth_token';
            localStorage.setItem(key, arguments[0]);
            
            console.log('Auth injected. Keys:', Object.keys(localStorage).filter(k => k.includes('auth') || k.includes('token')));
        """, token, json.dumps(user))
        
        # AGORA carregar a app
        print('🌐 Carregando app (http://localhost:8081)...')
        driver.get('http://localhost:8081/')
        time.sleep(6)
        
        # Verificar renderização
        render_info = driver.execute_script("""
            return {
                semantics: document.querySelectorAll('flt-semantics').length,
                appBar: !!document.body.innerText.match(/Estou Aqui|Mapa|Eventos|Alertas|Perfil/),
                nav: !!document.body.innerText.match(/Mapa|Eventos|Alertas|Perfil/),
                url: window.location.hash,
                text: document.body.innerText.substring(0, 300)
            };
        """)
        
        print(f'\n📱 Renderização:')
        print(f'  Elementos semânticos: {render_info["semantics"]}')
        print(f'  App Bar detectada: {render_info["appBar"]}')
        print(f'  Navbar detectada: {render_info["nav"]}')
        print(f'  URL: {render_info["url"]}')
        print(f'  Texto visível: {render_info["text"][:100]}...')
        
        # Screenshot
        driver.save_screenshot('/tmp/flutter_auth_preload.png')
        print(f'\n📸 Screenshot: /tmp/flutter_auth_preload.png')
        
        # Se não estiver no mapa, tentar navegar
        if '#/map' not in render_info['url']:
            print('\n🗺️ Navegando para mapa...')
            driver.get('http://localhost:8081/#/map')
            time.sleep(5)
            driver.save_screenshot('/tmp/flutter_map_final.png')
            print('📸 Screenshot do mapa: /tmp/flutter_map_final.png')
        
        # Verificar logs
        logs = driver.get_log('browser')
        print(f'\n📋 Logs ({len(logs)} entradas):')
        for log in logs[-10:]:
            level = log['level']
            msg = log['message']
            if 'SERIOUS' in level or 'SEVERE' in  level:
                print(f"  ❌ [{level}] {msg[:150]}")
            else:
                print(f"  [{level}] {msg[:150]}")
        
        print('\n✅ Teste completo!')
        input('Pressione ENTER para fechar...')
        
    except Exception as e:
        print(f'❌ Erro: {e}')
        import traceback
        traceback.print_exc()
        driver.save_screenshot('/tmp/flutter_error.png')
        input('Pressione ENTER...')
    finally:
        driver.quit()


if __name__ == '__main__':
    run()
