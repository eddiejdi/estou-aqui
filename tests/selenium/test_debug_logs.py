#!/usr/bin/env python3
"""
Debug script para capturar logs de console da app Flutter
Objetivo: Ver exatamente o que está acontecendo no navegador
"""
import time
import sys
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

def test_console_logs():
    """Captura todos os logs do console navegador"""
    options = webdriver.ChromeOptions()
    options.set_capability("goog:loggingPrefs", {"browser": "ALL"})
    
    driver = webdriver.Chrome(options=options)
    
    try:
        print("\n" + "="*60)
        print("🔍 TESTE DE DEBUG - Capturando logs de console")
        print("="*60)
        
        # Abre a app
        print("\n[1] Abrindo http://localhost:8081...")
        driver.get("http://localhost:8081")
        
        # Aguarda um pouco para a app carregar
        time.sleep(10)
        
        # Captura logs de console
        print("\n[2] Capturando logs de browser...")
        logs = driver.get_log("browser")
        
        if not logs:
            print("❌ Nenhum log capturado!")
        else:
            print(f"✅ Total de logs: {len(logs)}\n")
            
            # Filtra e exibe logs por tipo
            for log_type in ["SEVERE", "WARNING", "INFO", "DEBUG", "LOG"]:
                typed_logs = [l for l in logs if l["level"] == log_type]
                if typed_logs:
                    print(f"\n📌 {log_type.upper()} ({len(typed_logs)} mensagens):")
                    print("-" * 60)
                    for log in typed_logs[:10]:  # Primeiras 10
                        msg = log["message"]
                        # Remove prefixos do Chrome
                        if " " in msg:
                            msg = msg.split(" ", 1)[1]  
                        print(f"  • {msg}")
                    if len(typed_logs) > 10:
                        print(f"  ... e mais {len(typed_logs) - 10} mensagens")
        
        # Também tenta executar código no console para ver a API
        print("\n[3] Testando acesso a localStorage via JS...")
        try:
            token = driver.execute_script("return localStorage.getItem('auth_token') || 'NENHUM TOKEN'")
            print(f"✅ Token em localStorage: {token[:30] if token != 'NENHUM TOKEN' else token}...")
        except Exception as e:
            print(f"❌ Erro ao acessar localStorage: {e}")
        
        # Verifica se há iframes (Flutter renderiza em canvas, então pode não haver elementos)
        print("\n[4] Analisando DOM...")
        try:
            body_text = driver.execute_script("return document.body.innerText || 'SEM TEXTO'")
            print(f"✅ Texto visível: {body_text[:100]}...")
        except Exception as e:
            print(f"❌ Erro ao ler texto: {e}")
        
        # Screenshot
        print("\n[5] Capturando screenshot...")
        driver.save_screenshot("/tmp/debug_logs.png")
        print("✅ Screenshot salvo em /tmp/debug_logs.png")
        
    finally:
        driver.quit()

if __name__ == "__main__":
    try:
        test_console_logs()
    except Exception as e:
        print(f"\n❌ Erro principal: {e}")
        sys.exit(1)
