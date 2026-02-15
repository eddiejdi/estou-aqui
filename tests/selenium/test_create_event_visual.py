#!/usr/bin/env python3
"""Teste Selenium visual: abre a tela de criação de evento e mantém visível.

Usage:
  python test_create_event_visual.py
"""
import time
from selenium_helpers import create_driver, register_and_login
import json


def run():
    print('Iniciando teste visual da criação de evento...')
    driver, wait = create_driver(geolocation=(-23.5505, -46.6333), headless=False)
    
    try:
        # Registrar/logar usuário via API
        api_base = 'http://localhost:3000/api'
        name = f'E2EUser'
        email = f'e2e_user_{int(time.time())}@example.com'
        password = 'password123'
        
        print(f'Criando usuário: {email}')
        token, user = register_and_login(api_base, name, email, password)
        print(f'Token obtido: {token[:20]}...')
        
        # Abrir a aplicação
        url = 'http://localhost:8080/#/event/create'
        print(f'Navegando para: {url}')
        driver.get(url)
        time.sleep(2)
        
        # Injetar autenticação no localStorage
        print('Injetando token no localStorage...')
        driver.execute_script("window.localStorage.setItem('auth_token', arguments[0]);", token)
        driver.execute_script("window.localStorage.setItem('current_user', arguments[0]);", json.dumps(user))
        
        # Recarregar para aplicar autenticação
        print('Recarregando página com autenticação...')
        driver.refresh()
        time.sleep(3)
        
        print('\n' + '='*60)
        print('TELA DE CRIAÇÃO DE EVENTO CARREGADA')
        print('O browser está aberto na tela de criação de evento.')
        print('Você pode interagir com a tela manualmente.')
        print('='*60 + '\n')
        
        # Tirar screenshot
        screenshot_path = '/tmp/selenium_create_event.png'
        driver.save_screenshot(screenshot_path)
        print(f'Screenshot salvo em: {screenshot_path}')
        
        # Aguardar input do usuário
        input('\nPressione ENTER para fechar o browser e finalizar o teste...')
        
        print('\nFinalizando teste.')
        
    except Exception as e:
        print(f'\nERRO: {e}')
        screenshot_path = '/tmp/selenium_error.png'
        driver.save_screenshot(screenshot_path)
        print(f'Screenshot de erro salvo em: {screenshot_path}')
        raise
    finally:
        driver.quit()
        print('Browser fechado.')


if __name__ == '__main__':
    run()
