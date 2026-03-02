#!/usr/bin/env python3
"""Teste avançado: monitora console JavaScript e erros de inicialização"""
import time
import json
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By


def run():
    print('Teste avançado: Monitorando inicialização do Dart...')
    
    # Criar driver com mais detalhes
    options = Options()
    options.set_capability("goog:loggingPrefs", {"browser": "ALL"})
    
    driver = webdriver.Chrome(options=options)
    
    try:
        print('📖 Abrindo página...')
        driver.get('http://localhost:8081/')
        time.sleep(3)
        
        # Executar script de debug
        print('\n🔍 Inspecionando inicialização Dart...')
        debug_info = driver.execute_script("""
            return {
                dartLoaded: typeof window.dartPageClose === 'function',
                flutterRunning: typeof window.$dartAppInstanceId !== 'undefined',
                mainDartLoaded: typeof window.main === 'function',
                entrypointLoaded: typeof _flutter !== 'undefined',
                errors: window.__flutterErrors || [],
                location: window.location.href
            };
        """)
        
        print(f'\n📋 Debug Info:')
        for key, value in debug_info.items():
            print(f'  {key}: {value}')
        
        # Capturar TODOS os logs
        print('\n📊 Todos os logs do console:')
        all_logs = driver.get_log('browser')
        
        # Agrupar por level
        logs_by_level = {}
        for log in all_logs:
            level = log['level']
            if level not in logs_by_level:
                logs_by_level[level] = []
            logs_by_level[level].append(log['message'])
        
        for level in sorted(logs_by_level.keys()):
            print(f'\n  [{level}] — {len(logs_by_level[level])} entradas:')
            for msg in logs_by_level[level][:10]:  # Primeiras 10 de cada level
                print(f'    • {msg[:200]}')
        
        # Tentar disparar eventos
        print('\n🎯 Tentando disparar inicialização manual...')
        driver.execute_script("""
            if (typeof _flutter !== 'undefined' && _flutter.loader) {
                console.log('Loader disponível, tentando inicializar...');
                _flutter.loader.loadEntrypoint({
                    onEntrypointLoaded: function(engineInitializer) {
                        console.log('Entrypoint loaded!');
                        engineInitializer.initializeEngine().then(engine => {
                            console.log('Engine initialized!');
                            engine.runApp();
                        });
                    }
                }).catch(e => {
                    console.error('Erro ao carregar:', e);
                });
            } else {
                console.log('Loader NÃO disponível');
            }
        """)
        
        time.sleep(5)
        
        # Capturar logs finais
        print('\n📊 Logs após tentativa:')
        new_logs = driver.get_log('browser')
        for log in new_logs[-10:]:
            print(f"  [{log['level']}] {log['message'][:150]}")
        
        # Screenshot
        driver.save_screenshot('/tmp/flutter_debug_console.png')
        print(f'\n📸 Screenshot: /tmp/flutter_debug_console.png')
        
        input('\nPressione ENTER para fechar...')
        
    except Exception as e:
        print(f'❌ Erro: {e}')
        import traceback
        traceback.print_exc()
        input('Pressione ENTER...')
    finally:
        driver.quit()


if __name__ == '__main__':
    run()
