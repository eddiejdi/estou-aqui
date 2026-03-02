#!/usr/bin/env python3
"""Teste: faz login via UI do Flutter e verifica eventos no mapa"""
import time
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from selenium_helpers import create_driver, register_and_login


def run():
    print('Iniciando teste de login + visualização de eventos...')
    api_base = 'http://localhost:3000/api'
    driver, wait = create_driver(geolocation=(-23.5505, -46.6333), headless=False)
    
    try:
        # Registrar usuário via API primeiro
        name = f'E2EUser'
        email = f'e2e_user_{int(time.time())}@example.com'
        password = 'password123'
        
        print(f'📝 Criando usuário: {email}')
        token, user = register_and_login(api_base, name, email, password)
        print(f'✅ Usuário criado com sucesso!')
        
        # Abrir aplicação direto na página de login (não splash)
        print('\n🌐 Abrindo aplicação em /login')
        driver.get('http://localhost:8080/#/login')
        time.sleep(3)
        
        # Screenshot da tela de login
        driver.save_screenshot('/tmp/selenium_login_screen.png')
        print('📸 Screenshot: /tmp/selenium_login_screen.png')
        
        # Fazer login via UI
        print(f'\n🔐 Fazendo login com email: {email}')
        
        # Abordagem: Tab para campos e digitar
        from selenium.webdriver.common.action_chains import ActionChains
        actions = ActionChains(driver)
        
        # Clicar no body para garantir foco
        body = driver.find_element('tag name', 'body')
        body.click()
        time.sleep(0.5)
        
        # Campo email (pressionar Tab até chegar)
        for _ in range(5):
            actions.send_keys(Keys.TAB)
            actions.pause(0.2)
        
        # Digitar email
        print('  Digitando email...')
        actions.send_keys(email)
        actions.pause(0.5)
        
        # Campo senha
        actions.send_keys(Keys.TAB)
        actions.pause(0.3)
        print('  Digitando senha...')
        actions.send_keys(password)
        actions.pause(0.5)
        
        # Submeter form (Tab para botão + Enter)
        actions.send_keys(Keys.TAB)
        actions.pause(0.3)
        actions.send_keys(Keys.ENTER)
        
        # Executar ações
        actions.perform()
        
        print('  ⌛ Aguardando login...')
        time.sleep(5)
        
        # Verificar se redirecionou para /map
        current_url = driver.current_url
        print(f'\n📍 URL atual: {current_url}')
        
        if '#/map' in current_url or '#/events' in current_url:
            print('✅ Login bem-sucedido! Redirecionado para o mapa.')
        else:
            print('⚠️  Não redirecionou para o mapa. Verificando erros...')
            page_text = driver.find_element('tag name', 'body').text
            print(f'Texto da página: {page_text[:500]}')
        
        # Aguardar carregamento do mapa
        print('\n⏳ Aguardando carregamento do mapa (10 segundos)...')
        time.sleep(10)
        
        # Capturar elementos de semântica (marcadores, etc)
        semantics = driver.execute_script("""
            const elements = document.querySelectorAll('flt-semantics');
            return {
                count: elements.length,
                texts: Array.from(elements).slice(0, 10).map(el => el.innerText).filter(t => t)
            };
        """)
        print(f'\n📱 Elementos Flutter renderizados:')
        print(f'  Total de elementos: {semantics["count"]}')
        if semantics["texts"]:
            print(f'  Primeiros textos: {semantics["texts"][:5]}')
        
        # Screenshot do mapa
        driver.save_screenshot('/tmp/selenium_map_logged.png')
        print('\n📸 Screenshot do mapa: /tmp/selenium_map_logged.png')
        
        # Verificar se consegue buscar eventos
        print('\n🔍 Verificando se API de eventos é acessível...')
        api_check = driver.execute_script("""
            const apiService = async () => {
                // Tentar ler token do flutter_secure_storage (web usa localStorage com prefixo)
                const keys = Object.keys(localStorage);
                const tokenKey = keys.find(k => k.includes('auth_token') || k.includes('token'));
                console.log('Chaves no localStorage:', keys);
                console.log('Token key encontrada:', tokenKey);
                
                return {
                    localStorageKeys: keys,
                    tokenKeyFound: tokenKey || null
                };
            };
            return apiService();
        """)
        print(f'  LocalStorage keys: {api_check.get("localStorageKeys", [])}')
        print(f'  Token key: {api_check.get("tokenKeyFound")}')
        
        # Logs do console
        print('\n📋 Logs do browser:')
        logs = driver.get_log('browser')
        for log in logs[-10:]:
            level = log['level']
            msg = log['message']
            if 'SEVERE' in level or 'ERROR' in level:
                print(f"  ❌ [{level}] {msg[:200]}")
        
        print('\n' + '='*70)
        print('TESTE CONCLUÍDO')
        print('='*70)
        print('\nVerifique os screenshots:')
        print('  - /tmp/selenium_login_screen.png (tela de login)')
        print('  - /tmp/selenium_map_logged.png (mapa após login)')
        
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
