#!/usr/bin/env python3
"""Diagnostic: captura XHR/fetch do admin da LinkedIn Page para localizar endpoints de edição.

Uso:
  LINKEDIN_PASSWORD="..." python tests/selenium/diagnose_linkedin_api.py

Gera:
  - /tmp/linkedin_network_log.json (amostra de events)
  - imprime endpoints candidatos encontrados
"""
import json
import os
import time
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium_helpers import create_driver, short_sleep

EMAIL = "edenilson.adm@gmail.com"
COMPANY_ADMIN_URL = "https://www.linkedin.com/company/37873425/"


def main():
    pw = os.environ.get("LINKEDIN_PASSWORD")
    if not pw:
        raise RuntimeError("LINKEDIN_PASSWORD env var not set")

    driver, wait = create_driver(headless=False, enable_performance=True)
    try:
        # login
        driver.get("https://www.linkedin.com/login")
        wait.until(EC.presence_of_element_located((By.ID, "username"))).send_keys(EMAIL)
        driver.find_element(By.ID, "password").send_keys(pw)
        driver.find_element(By.XPATH, "//button[@type='submit']").click()
        short_sleep(3)

        driver.get(COMPANY_ADMIN_URL)
        short_sleep(3)
        driver.save_screenshot('/tmp/selenium_linkedin_diagnose_after_login.png')

        # tentar abrir menus que possivelmente disparam chamadas de edição
        candidates_to_click = [
            "//button[contains(., 'Admin tools') or contains(., 'Ferramentas do administrador')]",
            "//button[contains(@aria-label,'Manage page') or contains(., 'Manage page') or contains(@aria-label,'Editar') or contains(.,'Editar')][1]",
            "//a[contains(., 'Manage page') or contains(., 'Gerenciar página') or contains(., 'Editar página')]",
            "//button[contains(., 'More') or contains(., 'Mais') or contains(., 'Ver mais') or contains(@aria-label,'More actions') ]",
        ]

        for xp in candidates_to_click:
            try:
                els = driver.find_elements(By.XPATH, xp)
                if not els:
                    continue
                els[0].click()
                short_sleep(1.2)
            except Exception:
                continue

        # tentativa RPA adicional: localizar explicitamente o cabeçalho 'Sobre'/'About', clicar o botão de editar,
        # preencher o campo e acionar 'Salvar' — tudo para forçar a requisição que atualiza a descrição.
        ABOUT_TEXT = (
            "RPA4ALL — Automação inteligente, observabilidade e IA aplicada para operações críticas. "
            "Transformamos processos manuais em fluxos auditáveis e escaláveis, integrando RPA, agentes de IA e dashboards de observabilidade.\n\n"
            "Somos os criadores do 'Estou Aqui' — app para monitoramento e estimativa de movimentos sociais em tempo real: check‑ins, estimativas de público, chat e notificações. "
            "Oferecemos consultoria, integração com ERPs e governança com trilhas de auditoria para garantir conformidade.\n\n"
            "Visite https://www.rpa4all.com para cases, soluções e contato."
        )
        try:
            js_open_and_fill = '''
            (async function(about){
              function findAboutHeading(){
                const keywords = ['sobre','about','company description','descri','about us','overview'];
                const nodes = Array.from(document.querySelectorAll('h1,h2,h3,div,span'));
                for(const n of nodes){
                  try{ const t=(n.innerText||'').toLowerCase(); if(t.length && keywords.some(k=>t.includes(k))) return n; }catch(e){}
                }
                return null;
              }
              const heading = findAboutHeading();
              if(!heading) return {opened:false, reason:'no-heading-found'};
              const container = heading.closest('section') || heading.parentElement || document;
              // procurar botão editar próximo
              let editBtn = container.querySelector('button[aria-label*="Edit" i], button[aria-label*="Editar" i], a[role="button"]');
              if(!editBtn){
                // procurar ícone de lápis
                editBtn = Array.from(container.querySelectorAll('button, a, svg')).find(n=> (n.outerHTML||'').toLowerCase().includes('pencil') || (n.getAttribute && n.getAttribute('data-test-id') && n.getAttribute('data-test-id').toLowerCase().includes('edit')) );
              }
              if(!editBtn){
                // tentar menu local
                const menu = container.querySelector('button[aria-haspopup], button[aria-label*="more" i], button[aria-label*="mais" i]');
                if(menu){ menu.click(); await new Promise(r=>setTimeout(r,400));
                  const editItem = Array.from(document.querySelectorAll('a,button')).find(n=>(n.innerText||'').toLowerCase().includes('editar') || (n.innerText||'').toLowerCase().includes('edit') || (n.innerText||'').toLowerCase().includes('page info'));
                  if(editItem){ editItem.click(); await new Promise(r=>setTimeout(r,400)); }
                }
              } else {
                try{ editBtn.click(); }catch(e){}
              }
              // aguardar modal e preencher
              await new Promise(r=>setTimeout(r,800));
              const modal = document.querySelector('div[role="dialog"], .artdeco-modal, .modal-dialog');
              const targetRoot = modal || container || document;
              // procurar campo editável
              const cand = targetRoot.querySelector('[contenteditable="true"], textarea, [role="textbox"], input[type=text]');
              if(!cand) return {opened:true, reason:'no-editable-found'};
              // preencher
              try{ if(cand.tagName.toLowerCase()==='textarea' || cand.tagName.toLowerCase()==='input'){ cand.value = about; cand.dispatchEvent(new Event('input',{bubbles:true})); cand.dispatchEvent(new Event('change',{bubbles:true})); } else { cand.innerText = about; cand.dispatchEvent(new Event('input',{bubbles:true})); cand.dispatchEvent(new Event('change',{bubbles:true})); } }catch(e){}
              // procurar botão salvar
              const saveBtn = Array.from(document.querySelectorAll('button')).find(b=> (b.innerText||'').toLowerCase().match(/salvar|save|publicar|publish|done|atualizar|update/));
              if(saveBtn){ try{ saveBtn.click(); }catch(e){}; return {opened:true, filled:true, saved:true}; }
              return {opened:true, filled:true, saved:false};
            })(arguments[0]);'''
            res = driver.execute_script(js_open_and_fill, ABOUT_TEXT)
            print('DIAG: edit attempt result ->', res)
            short_sleep(2.0)
        except Exception as e:
            print('DIAG: exception during open_and_fill', e)

        # collect performance logs
        logs = []
        try:
            raw = driver.get_log('performance')
            for entry in raw:
                try:
                    logs.append(json.loads(entry['message'])['message'])
                except Exception:
                    continue
        except Exception:
            pass

        # extract XHR/fetch events with voyager/api or pages keywords
        candidates = set()
        for m in logs:
            try:
                method = m.get('method','')
                params = m.get('params',{})
                if method in ('Network.requestWillBeSent','Network.responseReceived'):
                    url = params.get('request', {}).get('url') or params.get('response', {}).get('url')
                    if url and ('/voyager/api/' in url or '/pages/' in url or 'organization' in url or 'page' in url):
                        candidates.add(url)
            except Exception:
                continue

        cand_list = sorted(candidates)
        with open('/tmp/linkedin_network_log.json','w',encoding='utf-8') as f:
            json.dump({'candidates': cand_list, 'sample_events': logs[:200]}, f, ensure_ascii=False, indent=2)

        print('DIAG: found candidate endpoints (sample):')
        for c in cand_list[:40]:
            print('  -', c)

        if not cand_list:
            print('DIAG: no candidate XHRs found in performance logs — can re-run with manual UI interaction to capture.')

    finally:
        try:
            driver.quit()
        except Exception:
            pass


if __name__ == '__main__':
    main()
