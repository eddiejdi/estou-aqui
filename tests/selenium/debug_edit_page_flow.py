#!/usr/bin/env python3
"""Diagnóstico rápido: login -> clicar 'Editar Page' (id org-menu-EDIT) -> capturar URL/DOM/screenshot
Uso:
  LINKEDIN_PASSWORD="..." python3 tests/selenium/debug_edit_page_flow.py
"""
import os
import time
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC

from selenium_helpers import create_driver, short_sleep

COMPANY_ADMIN_URL = "https://www.linkedin.com/company/37873425/"
EMAIL = "edenilson.adm@gmail.com"

ABOUT_TEXT = (
    "RPA4ALL — Automação inteligente, observabilidade e IA aplicada para operações críticas. "
    "Transformamos processos manuais em fluxos auditáveis e escaláveis, integrando RPA, agentes de IA e dashboards de observabilidade.\n\n"
    "Somos os criadores do 'Estou Aqui' — app para monitoramento e estimativa de movimentos sociais em tempo real: check‑ins, estimativas de público, chat e notificações. "
    "Oferecemos consultoria, integração com ERPs e governança com trilhas de auditoria para garantir conformidade.\n\n"
    "Visite https://www.rpa4all.com para cases, soluções e contato."
)


def main():
    pwd = os.environ.get('LINKEDIN_PASSWORD')
    if not pwd:
        raise RuntimeError('LINKEDIN_PASSWORD env var not set')

    driver, wait = create_driver(headless=False)
    try:
        driver.get('https://www.linkedin.com/login')
        wait.until(lambda d: d.find_element(By.ID, 'username')).send_keys(EMAIL)
        driver.find_element(By.ID, 'password').send_keys(pwd)
        driver.find_element(By.XPATH, "//button[@type='submit']").click()
        short_sleep(3)
        driver.save_screenshot('/tmp/diagnose_linkedin_after_login.png')

        # abrir a página da empresa com view admin
        driver.get(COMPANY_ADMIN_URL)
        short_sleep(2)
        driver.save_screenshot('/tmp/diagnose_linkedin_company_page.png')

        # tentar localizar o link lateral 'Editar Page' (id org-menu-EDIT) e clicar
        clicked = False
        try:
            el = driver.find_element(By.ID, 'org-menu-EDIT')
            driver.execute_script('arguments[0].click();', el)
            clicked = True
            print('CLICK: org-menu-EDIT clicked')
        except Exception as e:
            print('CLICK: org-menu-EDIT not found:', e)

        # fallback: procurar texto exato visível
        if not clicked:
            try:
                a = driver.find_element(By.XPATH, "//span[contains(., 'Editar Page')]/ancestor::a[1]")
                driver.execute_script('arguments[0].click();', a)
                clicked = True
                print('CLICK: anchor with text "Editar Page" clicked')
            except Exception as e:
                print('CLICK fallback not found:', e)

        short_sleep(3)
        print('CURRENT URL AFTER CLICK ->', driver.current_url)
        driver.save_screenshot('/tmp/diagnose_linkedin_after_edit_click.png')

        # salvar page source
        with open('/tmp/linkedin_page_source_after_editclick.html', 'w', encoding='utf-8') as f:
            f.write(driver.page_source)

        ps = driver.page_source.lower()
        tokens = ['about', 'overview', 'description', 'company-description', 'page-info', 'overviewtext', 'descriptioncontainer']
        found = [t for t in tokens if t in ps]
        print('PAGE TOKENS FOUND ->', found)

        # procurar elementos editáveis visíveis
        cand_selectors = [
            "//div[@role='dialog']//*[@contenteditable='true']",
            "//div[@role='dialog']//*[@role='textbox']",
            "//textarea[contains(@name,'description') or contains(@id,'description')]",
            "//*[@contenteditable='true' and contains(.,'Sobre') or contains(.,'About')]",
            "//*[@role='textbox']",
        ]
        for xp in cand_selectors:
            try:
                els = driver.find_elements(By.XPATH, xp)
                if els:
                    print(f"FOUND {len(els)} elements for XPath: {xp}")
                    for i,e in enumerate(els[:5]):
                        txt = e.text or e.get_attribute('innerText') or e.get_attribute('value') or ''
                        print('  -> element', i, 'len(text)=', len(txt), 'snippet=', txt[:120].replace('\n',' '))
            except Exception:
                pass

        # === APLICAR: preencher textarea de descrição e salvar ===
        try:
            ta = driver.find_element(By.XPATH, "//textarea[contains(@name,'description') or contains(@id,'description') or contains(@placeholder,'Descrição')]")
            driver.execute_script(
                "arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input',{bubbles:true})); arguments[0].dispatchEvent(new Event('change',{bubbles:true}));",
                ta, ABOUT_TEXT
            )
            short_sleep(0.8)
            print('APPLY: textarea updated in DOM (about)')

            # clicar botão Salvar / Save (várias alternativas)
            saved = False
            for txt in ['Salvar','Save','Publicar','Publish','Done','Atualizar','Update']:
                try:
                    btn = driver.find_element(By.XPATH, f"//button[contains(., '{txt}')]")
                    driver.execute_script('arguments[0].click();', btn)
                    short_sleep(2)
                    print('APPLY: clicked save ->', txt)
                    saved = True
                    break
                except Exception:
                    continue

            driver.save_screenshot('/tmp/diagnose_linkedin_after_save.png')

            # confirmar valor atualizado no DOM
            try:
                ta2 = driver.find_element(By.XPATH, "//textarea[contains(@name,'description') or contains(@id,'description')]")
                val = ta2.get_attribute('value') or ta2.get_attribute('innerText') or ta2.text
                print('VERIFY: len(new description)=', len(val))
                if 'RPA4ALL' in val or 'rpa4all.com' in val:
                    print('VERIFY: update appears successful')
                else:
                    print('VERIFY: update not present (check modal/save behavior)')
            except Exception:
                print('VERIFY: could not read textarea after save')

        except Exception as e:
            print('APPLY: failed to update textarea or save:', e)

    finally:
        try:
            driver.quit()
        except Exception:
            pass


if __name__ == '__main__':
    main()
