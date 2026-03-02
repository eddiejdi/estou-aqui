#!/usr/bin/env python3
"""Teste DEBUG: captura console detalhado e elementos DOM"""
import time
import json
from selenium_helpers import create_driver, register_and_login
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC


def run():
    print('Iniciando teste DEBUG detalhado...')
    api_base = 'http://localhost:3000/api'
    driver, wait = create_driver(geolocation=(-23.5505, -46.6333), headless=False)
    
    try:
        # Registrar/logar usuário
        name = f'E2EUser'
        email = f'e2e_user_{int(time.time())}@example.com'
        password = 'password123'
        
        print(f'Criando usuário: {email}')
        token, user = register_and_login(api_base, name, email, password)
        
        # Primeiro verificar a home
        print('\n1️⃣ TESTANDO HOME (/')
        driver.get('http://localhost:8080/')
        time.sleep(3)
        
        # Injetar token logo de cara
        driver.execute_script("window.localStorage.setItem('auth_token', arguments[0]);", token)
        driver.execute_script("window.localStorage.setItem('current_user', arguments[0]);", json.dumps(user))
        
        # Capturar HTML root
        html = driver.execute_script("return document.documentElement.outerHTML;")
        print(f'HTML length: {len(html)} chars')
        
        # Verificar se tem flutter-view
        has_flutter = driver.execute_script("return !!document.querySelector('flt-glass-pane, flutter-view, [flt-renderer]');")
        print(f'Flutter view detected: {has_flutter}')
        
        # Verificar se JavaScript está carregado
        has_main = driver.execute_script("return typeof window.main !== 'undefined';")
        print(f'main.dart.js loaded: {has_main}')
        
        # Capturar TODOS os logs do console (incluindo INFO)
        print('\n📋 CONSOLE LOGS:')
        logs = driver.get_log('browser')
        for log in logs:
            level = log['level']
            timestamp = log['timestamp']
            msg = log['message']
            print(f"  [{level}] {msg[:300]}")
        
        driver.save_screenshot('/tmp/debug_home.png')
        
        # Agora testar rota /map
        print('\n2️⃣ TESTANDO ROTA /map')
        driver.get('http://localhost:8080/#/map')
        time.sleep(5)
        
        # Verificar URL atual
        current_url = driver.current_url
        print(f'URL atual: {current_url}')
        
        # Verificar se roteador do Flutter funcionou
        route_info = driver.execute_script("""
            return {
                hash: window.location.hash,
                pathname: window.location.pathname,
                href: window.location.href
            };
        """)
        print(f'Route info: {route_info}')
        
        # Capturar elementos na página
        print('\n📱 ELEMENTOS DOM:')
        elements = driver.execute_script("""
            const body = document.body;
            const flutterView = document.querySelector('flutter-view');
            const fltGlass = document.querySelector('flt-glass-pane');
            const semantics = document.querySelectorAll('flt-semantics');
            
            return {
                body_children: body.children.length,
                has_flutter_view: !!flutterView,
                has_flt_glass: !!fltGlass,
                semantics_count: semantics.length,
                body_text: body.innerText.substring(0, 500)
            };
        """)
        print(json.dumps(elements, indent=2))
        
        # Capturar erros de rede
        print('\n🌐 NETWORK LOGS:')
        perf_logs = driver.get_log('performance')
        for log in perf_logs[-10:]:
            msg = json.loads(log['message'])
            method = msg.get('message', {}).get('method', '')
            if 'Network.response' in method or 'Network.request' in method:
                params = msg.get('message', {}).get('params', {})
                if 'response' in params:
                    status = params['response'].get('status', '')
                    url = params['response'].get('url', '')
                    if url and 'localhost' in url:
                        print(f"  {status} {url[:100]}")
        
        # Screenshot final
        driver.save_screenshot('/tmp/debug_map.png')
        
        # Verificar requisição à API
        print('\n🔍 TESTANDO REQUISIÇÃO À API DE EVENTOS:')
        api_test = driver.execute_script("""
            return fetch('http://localhost:3000/api/events?lat=-23.5505&lng=-46.6333', {
                headers: {
                    'Authorization': 'Bearer ' + localStorage.getItem('auth_token')
                }
            })
            .then(r => r.json())
            .then(data => ({success: true, count: data.events?.length || 0}))
            .catch(err => ({success: false, error: err.toString()}));
        """)
        time.sleep(2)
        print(f'API test result: {api_test}')
        
        print('\n' + '='*70)
        print('DEBUG COMPLETO')
        print('='*70)
        print('\nScreenshots salvos:')
        print('  - /tmp/debug_home.png')
        print('  - /tmp/debug_map.png')
        
        input('\nPressione ENTER para fechar o browser...')
        
    except Exception as e:
        print(f'\n❌ ERRO: {e}')
        import traceback
        traceback.print_exc()
        driver.save_screenshot('/tmp/debug_error.png')
        input('Pressione ENTER para fechar...')
    finally:
        driver.quit()
        print('Browser fechado.')


if __name__ == '__main__':
    run()
