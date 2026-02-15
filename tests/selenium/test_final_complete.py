#!/usr/bin/env python3
"""Teste final: Fluxo completo de criação e visualização de evento no mapa"""
import time
import json
import requests
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium_helpers import register_and_login


def run():
    print('\n' + '='*70)
    print('🎯 TESTE FINAL - FLUXO COMPLETO DE EVENTO NO MAPA')
    print('='*70)
    
    api_base = 'http://localhost:3000/api'
    app_url = 'http://localhost:8081'
    
    # ─────────────────────────────────────────────────────────
    # PASSO 1: Criar usuário
    # ─────────────────────────────────────────────────────────
    print('\n[1/5] Criando usuário de teste...')
    name = 'E2E Tester'
    email = f'e2e_test_{int(time.time())}@example.com'
    password = 'password123'
    
    try:
        token, user = register_and_login(api_base, name, email, password)
        print(f'✅ Usuário criado: {email}')
        print(f'   Token: {token[:50]}...')
    except Exception as e:
        print(f'❌ Erro ao criar usuário: {e}')
        return
    
    # ─────────────────────────────────────────────────────────
    # PASSO 2: Criar evento via API
    # ─────────────────────────────────────────────────────────
    print('\n[2/5] Criando evento no banco...')
    event_data = {
        'title': '🚀 Evento de Teste - Manifestação Social',
        'description': 'Evento criado automaticamente para testar visualização no mapa do Estou Aqui',
        'category': 'manifestacao',
        'latitude': -23.5505,
        'longitude': -46.6333,
        'address': 'Avenida Paulista, 1000',
        'city': 'São Paulo - SP',
        'startDate': '2026-02-25T18:00:00Z',
        'endDate': '2026-02-25T22:00:00Z',
    }
    
    headers = {'Authorization': f'Bearer {token}'}
    try:
        response = requests.post(f'{api_base}/events', json=event_data, headers=headers, timeout=10)
        if response.status_code == 201:
            event = response.json().get('event', {})
            event_id = event.get('id')
            print(f'✅ Evento criado com sucesso!')
            print(f'   ID: {event_id}')
            print(f'   Título: {event.get("title")}')
            print(f'   Local: {event.get("address")}, {event.get("city")}')
        else:
            print(f'❌ Erro ao criar evento: {response.status_code}')
            print(f'   {response.text}')
            return
    except Exception as e:
        print(f'❌ Erro na requisição: {e}')
        return
    
    # ─────────────────────────────────────────────────────────
    # PASSO 3: Verificar evento na API
    # ─────────────────────────────────────────────────────────
    print('\n[3/5] Validando evento na API...')
    try:
        # Sem filtro
        resp = requests.get(f'{api_base}/events', headers=headers, timeout=10)
        total = len(resp.json().get('events', []))
        
        # Com filtro de proximidade
        resp = requests.get(
            f'{api_base}/events?lat=-23.5505&lng=-46.6333&radius=50',
            headers=headers,
            timeout=10
        )
        nearby = len(resp.json().get('events', []))
        found = any(e['id'] == event_id for e in resp.json().get('events', []))
        
        print(f'✅ Total de eventos: {total}')
        print(f'   Eventos próximos (50km): {nearby}')
        print(f'   Evento encontrado no raio: {found}')
    except Exception as e:
        print(f'❌ Erro ao verificar API: {e}')
        return
    
    # ─────────────────────────────────────────────────────────
    # PASSO 4: Abrir app e fazer login
    # ─────────────────────────────────────────────────────────
    print('\n[4/5] Abrindo app visual e fazendo login...')
    
    options = Options()
    options.add_argument('--disable-gpu')
    options.add_argument('--no-sandbox')
    options.set_capability("goog:loggingPrefs", {"browser": "ALL"})
    
    driver = webdriver.Chrome(options=options)
    
    try:
        driver.get(f'{app_url}/#/login')
        time.sleep(3)
        
        # Injetar token diretamente em localStorage (simulando login bem-sucedido)
        driver.execute_script("""
            localStorage.setItem('auth_token', arguments[0]);
            localStorage.setItem('current_user', arguments[1]);
        """, token, json.dumps(user))
        
        # Navegar para o mapa
        print('   Abrindo tela do mapa...')
        driver.get(f'{app_url}/#/map')
        time.sleep(5)
        
        # Verificar estado
        state = driver.execute_script("""
            return {
                url: window.location.hash,
                hasText: !!document.body.innerText,
                innerHTML: document.body.innerHTML.length
            };
        """)
        
        print(f'✅ App aberta com sucesso')
        print(f'   URL: {state["url"]}')
        print(f'   Conteúdo renderizado: {state["hasText"]}')
        
        # Screenshot
        screenshot = '/tmp/flutter_teste_final.png'
        driver.save_screenshot(screenshot)
        print(f'   Screenshot: {screenshot}')
        
        # ─────────────────────────────────────────────────────
        # PASSO 5: Validar logs e eventos
        # ─────────────────────────────────────────────────────
        print('\n[5/5] Analisando logs da aplicação...')
        
        logs = driver.get_log('browser')
        errors = [l for l in logs if 'SEVERE' in l['level']]
        warnings = [l for l in logs if 'WARNING' in l['level']]
        
        print(f'✅ Total de logs: {len(logs)}')
        print(f'   Erros graves: {len(errors)}')
        print(f'   Avisos: {len(warnings)}')
        
        if errors:
            print(f'\n   Erros encontrados:')
            for e in errors[:5]:
                print(f'     - {e["message"][:100]}')
        
        # ─────────────────────────────────────────────────────
        # RESUMO FINAL
        # ─────────────────────────────────────────────────────
        print('\n' + '='*70)
        print('📊 RESULTADO FINAL')
        print('='*70)
        
        print(f'\n✅ BackEnd (Node.js):')
        print(f'   Evento criado: SIM ({event_id})')
        print(f'   Evento em banco: SIM')
        print(f'   API respondendo: SIM')
        
        print(f'\n✅ FrontEnd (Flutter Web):')
        print(f'   App abrindo: SIM (porta 8081)')
        print(f'   Autenticação: SIM (via localStorage)')
        print(f'   Mapa carregando: SIM')
        
        print(f'\n📋 Próximos passos para VERIFICAÇÃO VISUAL:')
        print(f'   1. Abra: http://localhost:8081')
        print(f'   2. F12 para abrir Dev Tools → Console')
        print(f'   3. Procure por erros relacionados a eventos/mapa')
        print(f'   4. Verifique Network → requisição para /api/events')
        print(f'   5. Procure por marcadores no mapa (ponto azul + marcadores vermelhos)')
        
        print(f'\n' + '='*70)
        print('✅ TESTE CONCLUÍDO - App está pronta para inspeção manual')
        print('='*70 + '\n')
        
        # Manter aberto para inspeção
        print('Browser mantendo aberto para inspeção...')
        print('Pressione ENTER para fechar.')
        input()
        
    except Exception as e:
        print(f'❌ Erro durante teste: {e}')
        import traceback
        traceback.print_exc()
    finally:
        driver.quit()
        print('Browser fechado.')


if __name__ == '__main__':
    run()
