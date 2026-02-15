#!/usr/bin/env python3
"""Teste Selenium: preenche formulário de criação de evento.

Como o Flutter Web usa CanvasKit, os campos não são HTML nativos.
Usamos navegação por Tab e digitação direta.
"""
import time
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.action_chains import ActionChains
from selenium_helpers import create_driver, register_and_login
import json


def run():
    print('Iniciando teste de preenchimento do formulário...')
    driver, wait = create_driver(geolocation=(-23.5505, -46.6333), headless=False)
    
    try:
        # Registrar/logar usuário via API
        api_base = 'http://localhost:3000/api'
        name = f'E2EUser'
        email = f'e2e_user_{int(time.time())}@example.com'
        password = 'password123'
        
        print(f'Criando usuário: {email}')
        token, user = register_and_login(api_base, name, email, password)
        
        # Abrir a aplicação
        url = 'http://localhost:8080/#/event/create'
        print(f'Navegando para: {url}')
        driver.get(url)
        time.sleep(2)
        
        # Injetar autenticação
        print('Autenticando...')
        driver.execute_script("window.localStorage.setItem('auth_token', arguments[0]);", token)
        driver.execute_script("window.localStorage.setItem('current_user', arguments[0]);", json.dumps(user))
        driver.refresh()
        
        # Aguardar geolocalização ser obtida (até 10 segundos)
        print('⏳ Aguardando geolocalização mockada ser processada...')
        time.sleep(5)
        
        print('\n' + '='*60)
        print('PREENCHENDO FORMULÁRIO DE CRIAÇÃO DE EVENTO')
        print('='*60 + '\n')
        
        # Clicar no body para garantir foco
        body = driver.find_element('tag name', 'body')
        body.click()
        time.sleep(0.5)
        
        # Criar objeto ActionChains para automação de teclado
        actions = ActionChains(driver)
        
        # Campo 1: Título (primeiro campo do formulário)
        print('Preenchendo: Título')
        actions.send_keys(Keys.TAB)  # Navegar para o primeiro campo
        time.sleep(0.3)
        actions.send_keys('Manifestação pela Educação')
        time.sleep(0.5)
        
        # Campo 2: Descrição
        print('Preenchendo: Descrição')
        actions.send_keys(Keys.TAB)
        time.sleep(0.3)
        actions.send_keys('Grande manifestação pela melhoria da educação pública no Brasil.')
        time.sleep(0.5)
        
        # Campo 3: Categoria (dropdown)
        print('Selecionando: Categoria')
        actions.send_keys(Keys.TAB)
        time.sleep(0.3)
        # Abrir dropdown com Enter ou Space
        actions.send_keys(Keys.SPACE)
        time.sleep(0.5)
        # Navegar para "manifestacao" (primeira opção já deve estar selecionada)
        actions.send_keys(Keys.ENTER)
        time.sleep(0.5)
        
        # Campo 4: CEP (opcional)
        print('Preenchendo: CEP')
        actions.send_keys(Keys.TAB)
        time.sleep(0.3)
        actions.send_keys('01310100')  # CEP da Av. Paulista, São Paulo
        
        # Executar as ações até aqui
        actions.perform()
        
        # Aguardar lookup de CEP e geocoding (crítico!)
        print('⏳ Aguardando lookup de CEP e geocoding (5 segundos)...')
        time.sleep(5)  
        
        # Verificar se latitude/longitude foram preenchidas via console
        try:
            lat = driver.execute_script("return document.querySelector('flt-semantics')?.innerText.match(/-?\\d+\\.\\d+/)?.[0];")
            print(f'📍 Coordenadas detectadas: {lat}')
        except:
            print('⚠️  Não foi possível detectar coordenadas via JavaScript')
        
        # Tirar screenshot do formulário preenchido
        screenshot_path = '/tmp/selenium_form_filled.png'
        driver.save_screenshot(screenshot_path)
        print(f'\nScreenshot do formulário preenchido: {screenshot_path}')
        
        print('\n' + '='*60)
        print('FORMULÁRIO PREENCHIDO')
        print('Campos preenchidos:')
        print('  - Título: Manifestação pela Educação')
        print('  - Descrição: Grande manifestação...')
        print('  - Categoria: Manifestação')
        print('  - CEP: 01310100 (Av. Paulista)')
        print('='*60 + '\n')
        
        input('Pressione ENTER para submeter o formulário...')
        
        # Verificar se há mensagem de erro visível antes de submeter
        page_text = driver.find_element('tag name', 'body').text
        if 'erro' in page_text.lower() or 'error' in page_text.lower():
            print('⚠️  Erro detectado na página:')
            print(page_text[:500])
        
        # Submeter o formulário
        print('\n🚀 Submetendo formulário...')
        
        # Tentar encontrar e clicar o botão "Criar Evento"
        try:
            # Abordagem 1: buscar por texto exato "Criar Evento"
            print('Buscando botão "Criar Evento"...')
            elements = driver.find_elements('css selector xpath', '//*')
            submit_clicked = False
            
            for elem in elements:
                text = elem.text.strip()
                if text == 'CRIAR EVENTO' or text == 'Criar Evento':
                    print(f'✓ Encontrado botão com texto: "{text}"')
                    driver.execute_script("arguments[0].scrollIntoView(true);", elem)
                    time.sleep(0.5)
                    elem.click()
                    submit_clicked = True
                    break
            
            if not submit_clicked:
                # Abordagem 2: scroll até o final e buscar botões
                print('Fazendo scroll até o final da página...')
                driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
                time.sleep(1)
                
                # Tentar clicar no último botão visível (geralmente é o submit)
                buttons = driver.find_elements('css selector', 'button, [role="button"]')
                if buttons:
                    print(f'Encontrados {len(buttons)} botões, clicando no último...')
                    buttons[-1].click()
                    submit_clicked = True
                
            if not submit_clicked:
                raise Exception('Botão de submit não encontrado')
                
        except Exception as e:
            print(f'⚠️  Erro ao clicar no botão: {e}')
            print('Tentando abordagem de Tab + Enter...')
            # Approach 3: Tab múltiplas vezes até botão e Enter
            actions = ActionChains(driver)
            for i in range(15):
                actions.send_keys(Keys.TAB)
                actions.pause(0.2)
            actions.send_keys(Keys.ENTER)
            actions.perform()
        
        time.sleep(3)  # Aguardar processamento
        
        # Capturar resultado
        print('\n📸 Capturando resultado...')
        screenshot_result = '/tmp/selenium_form_submitted.png'
        driver.save_screenshot(screenshot_result)
        print(f'Screenshot do resultado: {screenshot_result}')
        
        # Verificar se há mensagem de sucesso ou erro no console
        logs = driver.get_log('browser')
        print('\n📋 Logs do browser:')
        for log in logs[-10:]:  # Últimos 10 logs
            print(f"  [{log['level']}] {log['message']}")
        
        # Verificar URL (se redirecionou para lista ou detalhes)
        current_url = driver.current_url
        print(f'\n🔗 URL atual: {current_url}')
        
        if '/#/events' in current_url or '/#/event/' in current_url and '/create' not in current_url:
            print('\n✅ SUCESSO! Evento criado e redirecionado.')
        elif '/#/event/create' in current_url:
            print('\n⚠️  Ainda na página de criação. Verificar se há erros de validação.')
        
        print('\n' + '='*60)
        print('RESULTADO DO CADASTRO')
        print('='*60)
        
        # Aguardar para visualização
        input('\nPressione ENTER para fechar o browser...')
        
    except Exception as e:
        print(f'\nERRO: {e}')
        import traceback
        traceback.print_exc()
        screenshot_path = '/tmp/selenium_error.png'
        driver.save_screenshot(screenshot_path)
        print(f'Screenshot de erro: {screenshot_path}')
        
        # Aguardar mesmo em caso de erro para análise
        input('Pressione ENTER para fechar...')
    finally:
        driver.quit()
        print('Browser fechado.')


if __name__ == '__main__':
    run()
