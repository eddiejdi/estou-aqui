#!/usr/bin/env python3
"""Teste: verifica se eventos aparecem no mapa e na lista"""
import time
import json
from selenium_helpers import create_driver, register_and_login


def run():
    print('Iniciando teste de visualização de eventos...')
    api_base = 'http://localhost:3000/api'
    driver, wait = create_driver(geolocation=(-23.5505, -46.6333), headless=False)
    
    try:
        # Registrar/logar usuário
        name = f'E2EUser'
        email = f'e2e_user_{int(time.time())}@example.com'
        password = 'password123'
        
        print(f'Criando usuário: {email}')
        token, user = register_and_login(api_base, name, email, password)
        
        # Abrir mapa
        url = 'http://localhost:8080/#/map'
        print(f'Navegando para: {url}')
        driver.get(url)
        time.sleep(2)
        
        # Autenticar
        print('Autenticando...')
        driver.execute_script("window.localStorage.setItem('auth_token', arguments[0]);", token)
        driver.execute_script("window.localStorage.setItem('current_user', arguments[0]);", json.dumps(user))
        driver.refresh()
        
        # Aguardar carregamento do mapa
        print('⏳ Aguardando carregamento do mapa (10 segundos)...')
        time.sleep(10)
        
        # Capturar texto da página
        page_text = driver.find_element('tag name', 'body').text
        print('\n📋 Texto visível na página:')
        print('='*70)
        print(page_text[:1000])
        print('='*70)
        
        # Verificar console logs
        print('\n📋 Logs do browser:')
        logs = driver.get_log('browser')
        for log in logs[-20:]:
            level = log['level']
            msg = log['message']
            if 'SEVERE' in level or 'ERROR' in level:
                print(f"  ❌ [{level}] {msg}")
            elif 'WARNING' in level:
                print(f"  ⚠️  [{level}] {msg[:200]}")
        
        # Screenshot do mapa
        screenshot_map = '/tmp/selenium_map_view.png'
        driver.save_screenshot(screenshot_map)
        print(f'\n📸 Screenshot do mapa: {screenshot_map}')
        
        # Tentar clicar no botão de lista
        print('\n🔄 Tentando alternar para visualização de lista...')
        time.sleep(2)
        
        # Buscar botão de lista (ícone de lista vs mapa)
        try:
            # Executar script para alternar view
            driver.execute_script("""
                const buttons = document.querySelectorAll('button, [role="button"]');
                console.log('Total de botões:', buttons.length);
            """)
            time.sleep(1)
            
            # Capturar elementos clicáveis
            clickables = driver.find_elements('css selector', 'button, [role="button"]')
            print(f'Encontrados {len(clickables)} elementos clicáveis')
            
        except Exception as e:
            print(f'⚠️  Erro ao buscar botões: {e}')
        
        # Screenshot final
        screenshot_final = '/tmp/selenium_map_final.png'
        driver.save_screenshot(screenshot_final)
        print(f'📸 Screenshot final: {screenshot_final}')
        
        print('\n' + '='*70)
        print('ANÁLISE CONCLUÍDA')
        print('='*70)
        print('\nVerifique os screenshots para ver se os marcadores estão no mapa.')
        print('Se não estiver vendo eventos, pode ser:')
        print('  1. Problema de carregamento assíncrono (eventos não carregaram)')
        print('  2. Problema no provider (dados não chegaram ao widget)')
        print('  3. Problema no MarkerLayer (dados não renderizaram)')
        
        input('\nPressione ENTER para fechar o browser...')
        
    except Exception as e:
        print(f'\n❌ ERRO: {e}')
        import traceback
        traceback.print_exc()
        driver.save_screenshot('/tmp/selenium_error.png')
        input('Pressione ENTER para fechar...')
    finally:
        driver.quit()
        print('Browser fechado.')


if __name__ == '__main__':
    run()
