#!/usr/bin/env python3
"""Teste: Simula app visual e monitora fluxo de eventos"""
import time
import json
import requests
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium_helpers import register_and_login


def run():
    print('\n📱 TESTE VISUAL COM MONITORAMENTO COMPLETO')
    print('='*70)
    
    api_base = 'http://localhost:3000/api'
    
    # Registrar usuário
    name = 'E2EUser'
    email = f'e2e_user_{int(time.time())}@example.com'
    password = 'password123'
    
    print(f'\n1️⃣  Criando usuário: {email}')
    token, user = register_and_login(api_base, name, email, password)
    print(f'✅ Usuário criado!')
    
    # Criar evento via API
    print(f'\n2️⃣  Criando evento via API...')
    event_data = {
        'title': 'Teste Mapa - Manifestação',
        'description': 'Evento de teste para verificar renderização no mapa.',
        'category': 'manifestacao',
        'latitude': -23.5505,
        'longitude': -46.6333,
        'address': 'Avenida Paulista',
        'city': 'São Paulo',
        'startDate': '2026-02-20T15:00:00Z',
    }
    headers = {'Authorization': f'Bearer {token}'}
    response = requests.post(f'{api_base}/events', json=event_data, headers=headers)
    
    if response.status_code == 201:
        event = response.json().get('event', {})
        event_id = event.get('id')
        print(f'✅ Evento criado: {event_id}')
    else:
        print(f'❌ Erro ao criar evento: {response.status_code}')
        print(f'   {response.text}')
        return
    
    # Testar API de busca
    print(f'\n3️⃣  Testando API de busca (sem filtro)...')
    resp = requests.get(f'{api_base}/events', headers=headers)
    all_events = resp.json().get('events', [])
    print(f'   Total de eventos: {len(all_events)}')
    
    # Buscar evento criado
    found = any(e['id'] == event_id for e in all_events)
    print(f'   Evento no banco: {found}')
    
    # Testar API com filtro de localização
    print(f'\n4️⃣  Testando API com filtro de proximidade...')
    resp = requests.get(
        f'{api_base}/events',
        params={'lat': -23.5505, 'lng': -46.6333, 'radius': 50},
        headers=headers
    )
    nearby_events = resp.json().get('events', [])
    print(f'   Eventos próximos (50km): {len(nearby_events)}')
    
    # Buscar evento criado
    found = any(e['id'] == event_id for e in nearby_events)
    print(f'   Evento encontrado no filtro: {found}')
    
    # Exibir detalhes do evento
    if nearby_events:
        test_event = nearby_events[0]
        print(f'\n5️⃣  Detalhes do evento:')
        print(f'   ID: {test_event["id"]}')
        print(f'   Título: {test_event["title"]}')
        print(f'   Status: {test_event["status"]}')
        print(f'   Categoria: {test_event["category"]}')
        print(f'   Lat/Lng: {test_event["latitude"]}, {test_event["longitude"]}')
        print(f'   Data início: {test_event["startDate"]}')
    
    # Agora abrir a app visual
    print(f'\n6️⃣  Abrindo app visual (porta 8081)...')
    print('   Por favor, verifique manualmente:')
    print('   - A) Se o mapa carrega')
    print('   - B) Se você vê marcadores/eventos')
    print('   - C) Abra Dev Tools (F12) → Console e procure por erros')
    print('   - D) Abra Network e veja requisição para /events')
    
    options = Options()
    options.add_argument('--disable-gpu')
    options.add_argument('--no-sandbox')
    driver = webdriver.Chrome(options=options)
    
    try:
        # Injetar auth e abrir
        driver.get('http://localhost:8081/')  
        time.sleep(2)
        
        # Injetar token
        driver.execute_script("""
            localStorage.setItem('auth_token', arguments[0]);
            localStorage.setItem('current_user', arguments[1]);
        """, token, json.dumps(user))
        
        # Recarregar
        driver.refresh()
        time.sleep(5)
        
        # Verificar se a app renderizou
        app_info = driver.execute_script("""
            return {
                url: window.location.href,
                title: document.querySelector('title')?.innerText,
                hasAppBar: !!document.body.innerText.match(/Mapa|Eventos|Alertas|Perfil|Estou Aqui/),
                listeners: Object.keys(window._listeners || {}).length,
                timestamp: new Date().toISOString()
            };
        """)
        
        print(f'\n7️⃣  Estado da app:')
        print(f'   URL: {app_info["url"]}')
        print(f'   Tem interface: {app_info["hasAppBar"]}')
        
        # Screenshot
        driver.save_screenshot('/tmp/flutter_visual_test.png')
        print(f'\n📸 Screenshot: /tmp/flutter_visual_test.png')
        
        # Capturar logs
        print(f'\n📋 Logs do console:')
        logs = driver.get_log('browser')
        for log in logs[-15:]:
            level = log['level']
            msg = log['message']
            if 'SEVERE' in level or 'WARNING' in level:
                print(f"   [{level}] {msg[:120]}")
        
        # Aguardar inspeção manual
        print(f'\n💡 Mantenha o browser aberto para inspecionar/debugar.')
        print(f'    Pressione F12 para abrir Dev Tools')
        print(f'    Veja:')
        print(f'     - Console: erros de Dart/JavaScript')
        print(f'     - Network: requisições para /events')
        print(f'     - Application > Local Storage: tokens')
        
        input('\nPressione ENTER quando terminar de inspecionar...')
        
    finally:
        driver.quit()
    
    print(f'\n✅ Teste finalizado!')


if __name__ == '__main__':
    run()
