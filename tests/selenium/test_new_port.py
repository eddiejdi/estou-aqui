#!/usr/bin/env python3
"""Teste final com novo servidor Flutter"""
import time
import json
from selenium_helpers import create_driver, register_and_login


def run():
    print('Teste do novo servidor Flutter Web (porta 8081)...')
    api_base = 'http://localhost:3000/api'
    driver, wait = create_driver(geolocation=(-23.5505, -46.6333), headless=False)
    
    try:
        # Registrar usuário via API
        name = f'E2EUser'
        email = f'e2e_user_{int(time.time())}@example.com'
        password = 'password123'
        
        print(f'📝 Criando usuário: {email}')
        token, user = register_and_login(api_base, name, email, password)
        print(f'✅ Usuário criado!')
        
        # Tentar nova porta
        print('\n🌐 Abrindo http://localhost:8081')
        driver.get('http://localhost:8081/')
        time.sleep(5)
        
        # Verificar renderização
        elements = driver.execute_script("""
            return {
                semantics_count: document.querySelectorAll('flt-semantics').length,
                body_text: document.body.innerText.substring(0, 200),
                has_flutter: !!document.querySelector('flutter-view, flt-glass-pane')
            };
        """)
        
        print(f'\n📱 Flutter renderizado:')
        print(f'  Elementos: {elements["semantics_count"]}')
        print(f'  Tem Flutter: {elements["has_flutter"]}')
        if elements["body_text"]:
            print(f'  Texto: {elements["body_text"][:100]}')
        
        # Injetar token via localStorage com prefixo correto
        print('\n🔐 Injetando autenticação...')
        driver.execute_script("""
            localStorage.setItem('auth_token', arguments[0]);
            localStorage.setItem('current_user', arguments[1]);
        """, token, json.dumps(user))
        
        # Navegar para mapa
        print('🗺️ Navegando para mapa...')
        driver.get('http://localhost:8081/#/map')
        time.sleep(5)
        
        # Capturar screenshot
        driver.save_screenshot('/tmp/flutter_new_server.png')
        print(f'📸 Screenshot: /tmp/flutter_new_server.png')
        
        # Verificar console
        logs = driver.get_log('browser')
        print(f'\n📋 Logs do console: {len(logs)} entradas')
        for log in logs[-5:]:
            print(f"  [{log['level']}] {log['message'][:150]}")
        
        print('\nTeste concluído!')
        input('Pressione ENTER para fechar...')
        
    except Exception as e:
        print(f'❌ Erro: {e}')
        import traceback
        traceback.print_exc()
        input('Pressione ENTER...')
    finally:
        driver.quit()


if __name__ == '__main__':
    run()
