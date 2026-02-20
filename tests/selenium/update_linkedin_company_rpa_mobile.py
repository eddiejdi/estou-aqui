#!/usr/bin/env python3
"""RPA attempt: emular mobile, abrir editor 'Sobre' e tentar salvar.
Gera logs: /tmp/linkedin_network_rpa_mobile.json e screenshot /tmp/selenium_linkedin_rpa_mobile.png
"""
import os
import time
import json
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium_helpers import create_driver, short_sleep

EMAIL = "edenilson.adm@gmail.com"
ABOUT_TEXT = (
    "RPA4ALL — Automação inteligente, observabilidade e IA aplicada para operações críticas. "
    "Transformamos processos manuais em fluxos auditáveis e escaláveis, integrando RPA, agentes de IA e dashboards de observabilidade.\n\n"
    "Somos os criadores do 'Estou Aqui' — app para monitoramento e estimativa de movimentos sociais em tempo real: check‑ins, estimativas de público, chat e notificações. "
    "Oferecemos consultoria, integração com ERPs e governança com trilhas de auditoria para garantir conformidade.\n\n"
    "Visite https://www.rpa4all.com para cases, soluções e contato."
)
COMPANY_ABOUT_URL = "https://www.linkedin.com/company/37873425/about/"


def try_set_value_js(driver, el, value):
    try:
        driver.execute_script("arguments[0].focus(); arguments[0].scrollIntoView({block:'center'});", el)
        tag = el.tag_name.lower()
        if tag in ('textarea', 'input'):
            el.clear()
            el.send_keys(value)
            driver.execute_script("arguments[0].dispatchEvent(new Event('input', { bubbles: true })); arguments[0].dispatchEvent(new Event('change', { bubbles: true })); arguments[0].blur();", el)
            return True
        if el.get_attribute('contenteditable') == 'true' or el.get_attribute('role') == 'textbox':
            driver.execute_script("arguments[0].innerText = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true })); arguments[0].dispatchEvent(new Event('change', { bubbles: true })); arguments[0].blur();", el, value)
            return True
        driver.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true })); arguments[0].dispatchEvent(new Event('change', { bubbles: true })); arguments[0].blur();", el, value)
        return True
    except Exception:
        return False


def main():
    pw = os.environ.get('LINKEDIN_PASSWORD')
    if not pw:
        raise RuntimeError('LINKEDIN_PASSWORD env var not set')

    driver, wait = create_driver(headless=False, enable_performance=True)
    try:
        # emulate mobile UA / viewport
        try:
            ua = 'Mozilla/5.0 (Linux; Android 12; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Mobile Safari/537.36'
            driver.execute_cdp_cmd('Network.setUserAgentOverride', {'userAgent': ua})
            driver.execute_cdp_cmd('Emulation.setDeviceMetricsOverride', {'width': 412, 'height': 915, 'deviceScaleFactor': 3, 'mobile': True})
        except Exception:
            pass

        # login
        driver.get('https://www.linkedin.com/login')
        wait.until(EC.presence_of_element_located((By.ID, 'username'))).send_keys(EMAIL)
        driver.find_element(By.ID, 'password').send_keys(pw)
        driver.find_element(By.XPATH, "//button[@type='submit']").click()
        short_sleep(3)

        driver.get(COMPANY_ABOUT_URL)
        short_sleep(3)
        driver.save_screenshot('/tmp/selenium_linkedin_rpa_mobile_before.png')

        # JS: localizar heading 'Sobre' e tentar abrir editor (mobile-specific selectors)
        js = '''(function(){
            const keywords=['sobre','about','overview','company description','descri'];
            function findHeading(){
                const nodes = Array.from(document.querySelectorAll('h1,h2,h3,div,span'));
                for(const n of nodes){ const t=(n.innerText||'').toLowerCase(); if(t.length && keywords.some(k=>t.includes(k))) return n; }
                return null;
            }
            const h = findHeading(); if(!h) return {found:false};
            const cont = h.closest('section') || h.parentElement || document;
            // procurar pencil / edit
            const edit = cont.querySelector('button[aria-label*="Edit" i], button[aria-label*="Editar" i], a[aria-label*="Edit" i], a[aria-label*="Editar" i]') || Array.from(cont.querySelectorAll('button,a')).find(x=> (x.innerText||'').toLowerCase().includes('editar') || (x.innerText||'').toLowerCase().includes('edit') );
            if(edit){ try{ edit.click(); return {found:true,method:'button-click'} }catch(e){} }
            // tentar menu de contexto
            const menu = cont.querySelector('button[aria-haspopup], button[aria-label*="more" i], a[role="button"][aria-haspopup]');
            if(menu){ try{ menu.click(); }catch(e){}; await new Promise(r=>setTimeout(r,500)); const item = Array.from(document.querySelectorAll('a,button')).find(n=>(n.innerText||'').toLowerCase().includes('editar') || (n.innerText||'').toLowerCase().includes('edit') ); if(item){ try{ item.click(); return {found:true,method:'menu-item'} }catch(e){} }
            }
            return {found:false};
        })();'''
        try:
            res = driver.execute_script(js)
        except Exception:
            res = None
        print('RPA-MOBILE: edit button click result ->', res)
        short_sleep(1.2)

        # procurar campo editável em modal/página e preencher
        filled = False
        try:
            candidates = driver.find_elements(By.XPATH, "//div[@role='dialog']//*[@contenteditable='true' or @role='textbox' or name='description' or contains(@id,'description')] | //textarea[contains(@name,'description') or contains(@placeholder,'Descrição') or contains(@placeholder,'Description')] | //div[contains(@class,'about') or contains(@class,'overview')]//*[@contenteditable='true']")
            if not candidates:
                candidates = driver.find_elements(By.XPATH, "//*[@contenteditable='true' and (contains(@class,'description') or contains(@aria-label,'description') or contains(@placeholder,'Descrição'))] | //textarea[contains(@id,'description')]")
            for el in candidates:
                try:
                    if try_set_value_js(driver, el, ABOUT_TEXT):
                        filled = True
                        break
                except Exception:
                    continue
        except Exception:
            filled = False

        # tentar salvar
        saved = False
        try:
            for txt in ['Salvar','Save','Publicar','Publish','Done','Atualizar','Update']:
                try:
                    btn = driver.find_element(By.XPATH, f"//button[contains(translate(., 'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'), '{txt.lower()}')]")
                    btn.click()
                    saved = True
                    short_sleep(1.0)
                    break
                except Exception:
                    continue
        except Exception:
            pass

        # coletar logs de rede
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

        with open('/tmp/linkedin_network_rpa_mobile.json','w',encoding='utf-8') as f:
            json.dump({'edit_click_result': res, 'found_editable': bool(candidates), 'filled': filled, 'saved': saved, 'events': logs[-400:]}, f, ensure_ascii=False, indent=2)

        driver.save_screenshot('/tmp/selenium_linkedin_rpa_mobile.png')
        print('RPA-MOBILE: filled=', filled, 'saved=', saved)

    finally:
        try:
            driver.quit()
        except Exception:
            pass


if __name__ == '__main__':
    main()
