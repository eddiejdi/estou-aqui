#!/usr/bin/env python3
"""Teste híbrido: visualiza formulário Flutter + cria evento via API"""
import time
import json
import requests
from selenium_helpers import create_driver, register_and_login


def run():
    print('Iniciando teste híbrido de criação de evento...')
    api_base = 'http://localhost:3000/api'
    driver, wait = create_driver(geolocation=(-23.5505, -46.6333), headless=False)
    
    try:
        # Registrar/logar usuário
        name = f'E2EUser'
        email = f'e2e_user_{int(time.time())}@example.com'
        password = 'password123'
        
        print(f'Criando usuário: {email}')
        token, user = register_and_login(api_base, name, email, password)
        
        # Abrir formulário de criação de evento (visualização)
        url = 'http://localhost:80/#/event/create'
        print(f'Navegando para: {url}')
        driver.get(url)
        time.sleep(2)
        
        # Autenticar
        driver.execute_script("window.localStorage.setItem('auth_token', arguments[0]);", token)
        driver.execute_script("window.localStorage.setItem('current_user', arguments[0]);", json.dumps(user))
        driver.refresh()
        time.sleep(3)
        
        print('\n' + '='*70)
        print('FORMULÁRIO DE CRIAÇÃO DE EVENTO ABERTO')
        print('='*70)
        print('\nDevido às limitações do Flutter Web (CanvasKit) com geolocalização')
        print('mockada no Selenium, vamos criar o evento via API e verificar o resultado.\n')
        
        input('Pressione ENTER para criar o evento via API...')
        
        # Criar evento via API
        print('\n🚀 Criando evento via API...')
        event_data = {
            'title': 'Manifestação pela Educação',
            'description': 'Grande manifestação pela melhoria da educação pública no Brasil.',
            'category': 'manifestacao',
            'latitude': -23.5505,  # Av. Paulista, São Paulo
            'longitude': -46.6333,
            'address': 'Avenida Paulista',
            'city': 'São Paulo - SP',
            'startDate': '2026-02-20T14:00:00.000Z',
            'endDate': '2026-02-20T18:00:00.000Z',
        }
        
        headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
        response = requests.post(f'{api_base}/events', json=event_data, headers=headers)
        
        if response.status_code == 201:
            response_data = response.json()
            event_created = response_data.get('event', {})
            event_id = event_created.get('id')
            print(f'✅ SUCESSO! Evento criado com ID: {event_id}')
            print(f'   Título: {event_created.get("title")}')
            print(f'   Localização: {event_created.get("address")}, {event_created.get("city")}')
            print(f'   Data: {event_created.get("startDate")}')
            print(f'   Organizador: {event_created.get("organizerId")}')
            print(f'\n📋 Resposta completa:')
            print(json.dumps(event_created, indent=2))
            
            # Navegar para a lista de eventos
            print('\nNavigando para lista de eventos...')
            driver.get('http://localhost:8080/#/map')
            time.sleep(3)
            
            screenshot_success = '/tmp/selenium_event_created.png'
            driver.save_screenshot(screenshot_success)
            print(f'📸 Screenshot da lista: {screenshot_success}')
            
            print('\n' + '='*70)
            print('EVENTO CRIADO COM SUCESSO!')
            print('='*70)
            print(f'\nEvento ID: {event_id}')
            print(f'Você pode visualizar o evento no mapa ou na lista de eventos.')
            
        else:
            print(f'❌ ERRO ao criar evento via API: {response.status_code}')
            print(f'   Resposta: {response.text}')
            screenshot_error = '/tmp/selenium_event_error.png'
            driver.save_screenshot(screenshot_error)
            print(f'📸 Screenshot de erro: {screenshot_error}')
        
        input('\n\nPressione ENTER para fechar o browser...')
        
    except Exception as e:
        print(f'\n❌ ERRO: {e}')
        import traceback
        traceback.print_exc()
        screenshot_error = '/tmp/selenium_error.png'
        driver.save_screenshot(screenshot_error)
        print(f'📸 Screenshot de erro: {screenshot_error}')
        input('Pressione ENTER para fechar...')
    finally:
        driver.quit()
        print('Browser fechado.')


if __name__ == '__main__':
    run()
