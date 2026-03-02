#!/usr/bin/env python3
"""Apply full Company Page edits via Selenium (Name, Vanity, Slogan, Website, About).
Usage:
  LINKEDIN_PASSWORD="..." python3 tests/selenium/update_linkedin_company_apply_all.py
"""
import os
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC

from selenium_helpers import create_driver, short_sleep, wait_for_human_challenge

COMPANY_ADMIN_URL = "https://www.linkedin.com/company/37873425/"
EMAIL = "edenilson.adm@gmail.com"

ABOUT_TEXT = (
    "RPA4ALL — Automação inteligente, observabilidade e IA aplicada para operações críticas. "
    "Transformamos processos manuais em fluxos auditáveis e escaláveis, integrando RPA, agentes de IA e dashboards de observabilidade.\n\n"
    "Somos os criadores do 'Estou Aqui' — app para monitoramento e estimativa de movimentos sociais em tempo real: check‑ins, estimativas de público, chat e notificações. "
    "Oferecemos consultoria, integração com ERPs e governança com trilhas de auditoria para garantir conformidade.\n\n"
    "Visite https://www.rpa4all.com para cases, soluções e contato."
)

PAGE_NAME = "RPA4All"
PAGE_VANITY = "rpa4all"
PAGE_SLOGAN = "Inserindo Automação na vida de todos."
PAGE_WEBSITE = "https://www.rpa4all.com"


from selenium.webdriver.common.keys import Keys


def set_input(driver, xp, value, commit_keys=None):
    try:
        el = driver.find_element(By.XPATH, xp)
        driver.execute_script("arguments[0].focus(); arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input',{bubbles:true})); arguments[0].dispatchEvent(new Event('change',{bubbles:true}));", el, value)
        short_sleep(0.4)
        try:
            driver.execute_script('arguments[0].blur();', el)
        except Exception:
            pass
        # optionally send a key to trigger validation (vanity availability checks, etc.)
        if commit_keys:
            try:
                if commit_keys == 'ENTER':
                    el.send_keys(Keys.ENTER)
                elif commit_keys == 'TAB':
                    el.send_keys(Keys.TAB)
            except Exception:
                pass
        return True
    except Exception:
        return False


def set_textarea_or_contenteditable(driver, xp, value):
    try:
        el = driver.find_element(By.XPATH, xp)
        tag = el.tag_name.lower()
        if tag in ('textarea','input'):
            driver.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input',{bubbles:true})); arguments[0].dispatchEvent(new Event('change',{bubbles:true}));", el, value)
        else:
            driver.execute_script("arguments[0].innerText = arguments[1]; arguments[0].dispatchEvent(new Event('input',{bubbles:true})); arguments[0].dispatchEvent(new Event('change',{bubbles:true}));", el, value)
        short_sleep(0.4)
        return True
    except Exception:
        return False


def try_set_value(driver, el, value):
    """Robust setter for inputs/textarea/contentEditable — sends keys, dispatches events and blurs.
    Returns True if the attempt did not raise an exception.
    """
    try:
        driver.execute_script('arguments[0].scrollIntoView({block: "center"});', el)
        driver.execute_script('arguments[0].focus();', el)
        tag = el.tag_name.lower()
        if tag in ('textarea', 'input'):
            try:
                el.clear()
            except Exception:
                pass
            # prefer send_keys for controlled React inputs
            el.send_keys(value)
            driver.execute_script("arguments[0].dispatchEvent(new Event('input', { bubbles: true })); arguments[0].dispatchEvent(new Event('change', { bubbles: true }));", el)
            try:
                driver.execute_script('arguments[0].blur();', el)
            except Exception:
                pass
            return True

        if el.get_attribute('contenteditable') == 'true' or el.get_attribute('role') == 'textbox':
            driver.execute_script("arguments[0].innerText = arguments[1]; arguments[0].dispatchEvent(new Event('input',{bubbles:true})); arguments[0].dispatchEvent(new Event('change',{bubbles:true})); arguments[0].blur();", el, value)
            return True

        # fallback: set value via JS
        driver.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true })); arguments[0].dispatchEvent(new Event('change', { bubbles: true }));", el, value)
        try:
            driver.execute_script('arguments[0].blur();', el)
        except Exception:
            pass
        return True
    except Exception:
        return False

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

        driver.get(COMPANY_ADMIN_URL)
        short_sleep(2)
        # detect anti-bot / reCAPTCHA and pause for manual solve if present
        if not wait_for_human_challenge(driver, timeout=300, poll_interval=2):
            print('Aborting: captcha not solved within timeout')
            try:
                driver.save_screenshot('/tmp/selenium_linkedin_captcha_timeout.png')
            except Exception:
                pass
            return

        # Click Edit Page (sidebar id) — reliable path
        try:
            el = driver.find_element(By.ID, 'org-menu-EDIT')
            driver.execute_script('arguments[0].click();', el)
            short_sleep(1.2)
        except Exception:
            # fallback: link text
            try:
                a = driver.find_element(By.XPATH, "//span[contains(., 'Editar Page')]/ancestor::a[1]")
                driver.execute_script('arguments[0].click();', a)
                short_sleep(1.2)
            except Exception:
                pass

        # First: try the diagnostic-proven sequence — set the About textarea immediately
        # after opening the modal (this flow has proven to persist reliably).
        try:
            ta = driver.find_element(By.XPATH, "//textarea[contains(@name,'description') or contains(@id,'description') or contains(@placeholder,'Descrição')]")
            driver.execute_script(
                "arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input',{bubbles:true})); arguments[0].dispatchEvent(new Event('change',{bubbles:true}));",
                ta, ABOUT_TEXT
            )
            short_sleep(0.8)
            print('Applied ABOUT_TEXT immediately after opening modal (diagnostic sequence)')
        except Exception:
            # not fatal — continue and we'll attempt other strategies later
            pass

        # Fill visible fields in the modal
        # Name
        set_input(driver, "//div[@role='dialog']//input[contains(@placeholder,'Nome') or contains(@aria-label,'Name') or contains(@name,'name') or contains(@id,'name') ]", PAGE_NAME)
        # Vanity — set and press ENTER to trigger availability/validation
        set_input(driver, "//div[@role='dialog']//input[contains(@placeholder,'company') or contains(@name,'vanity') or contains(@id,'vanity') or contains(@aria-label,'Vanity')]", PAGE_VANITY, commit_keys='ENTER')
        # Slogan / tagline
        set_textarea_or_contenteditable(driver, "//div[@role='dialog']//textarea[contains(@placeholder,'Slogan') or contains(@aria-label,'Slogan') or contains(@name,'tagline') or contains(@id,'slogan')]", PAGE_SLOGAN)
        # Website
        set_input(driver, "//div[@role='dialog']//input[contains(@placeholder,'website') or contains(@name,'website') or contains(@aria-label,'Website') or contains(@id,'website')]", PAGE_WEBSITE)

        # Ensure 'Sobre' section visible then set description using a robust setter (try_set_value)
        try:
            # click side menu 'Sobre' if present
            try:
                btn = driver.find_element(By.XPATH, "//div[@role='dialog']//a[contains(., 'Sobre') or contains(., 'About')]")
                driver.execute_script('arguments[0].click();', btn)
                short_sleep(0.6)
            except Exception:
                pass

            desc_xpaths = [
                "//div[@role='dialog']//textarea[contains(@name,'description') or contains(@id,'description') or contains(@placeholder,'Descrição')]",
                "//textarea[contains(@name,'description') or contains(@id,'description') or contains(@placeholder,'Descrição') ]",
                "//*[@contenteditable='true' and (contains(@class,'description') or contains(@aria-label,'description') or contains(@placeholder,'Descrição') or contains(@role,'textbox'))]",
                "//div[@role='textbox' and @contenteditable='true']",
            ]

            desc_updated = False
            for dx in desc_xpaths:
                try:
                    el = driver.find_element(By.XPATH, dx)
                    if try_set_value(driver, el, ABOUT_TEXT):
                        short_sleep(0.8)
                        # verify immediate readback
                        val = el.get_attribute('value') or el.get_attribute('innerText') or el.text
                        if val and (len(val) > 20 and ('rpa4all' in val.lower() or 'rpa4all.com' in val.lower())):
                            desc_updated = True
                            break
                except Exception:
                    continue

            # final attempt: JS assignment + dispatch to any textarea/contentEditable found
            if not desc_updated:
                for dx in desc_xpaths:
                    try:
                        el = driver.find_element(By.XPATH, dx)
                        try:
                            driver.execute_script(
                                "arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input',{bubbles:true})); arguments[0].dispatchEvent(new Event('change',{bubbles:true})); arguments[0].blur();",
                                el, ABOUT_TEXT
                            )
                            short_sleep(0.6)
                            val = el.get_attribute('value') or el.get_attribute('innerText') or el.text
                            if val and ('rpa4all' in val.lower() or 'rpa4all.com' in val.lower()):
                                desc_updated = True
                                break
                        except Exception:
                            continue
                    except Exception:
                        continue

            if not desc_updated:
                print('WARNING: description field could not be reliably updated in-modal; will still attempt to save and verify afterwards')
        except Exception:
            pass

        # Click Save / Salvar — try several lookup strategies (global first like diagnostic)
        saved = False
        save_texts = ['Salvar','Save','Publicar','Publish','Done','Atualizar','Update']
        for txt in save_texts:
            try:
                # 1) global button with text/aria-label
                btn = driver.find_element(By.XPATH, f"//button[contains(., '{txt}') or contains(@aria-label, '{txt}')]")
                driver.execute_script('arguments[0].click();', btn)
                short_sleep(2)
                saved = True
                break
            except Exception:
                pass
            try:
                # 2) any element with role=button containing the text (covers portal/menus)
                btn2 = driver.find_element(By.XPATH, f"//*[@role='button' and contains(., '{txt}')]")
                driver.execute_script('arguments[0].click();', btn2)
                short_sleep(2)
                saved = True
                break
            except Exception:
                pass
            try:
                # 3) dialog-scoped button
                btn3 = driver.find_element(By.XPATH, f"//div[@role='dialog']//button[contains(., '{txt}') or contains(@aria-label, '{txt}')]")
                driver.execute_script('arguments[0].click();', btn3)
                short_sleep(2)
                saved = True
                break
            except Exception:
                pass
        # last-resort: trigger Enter on focused element (some dialogs save on Enter)
        if not saved:
            try:
                driver.execute_script('document.activeElement && document.activeElement.dispatchEvent(new KeyboardEvent("keydown", {key: "Enter"}));')
                short_sleep(1.0)
                saved = True
            except Exception:
                pass

        driver.save_screenshot('/tmp/selenium_linkedin_apply_all_after_save.png')

        # Quick verification: look for ABOUT_TEXT present in page source (post-save)
        short_sleep(1.5)
        driver.get(COMPANY_ADMIN_URL)
        short_sleep(2)
        driver.save_screenshot('/tmp/selenium_linkedin_apply_all_confirm.png')

        # Re-open edit modal and read back the fields to verify persistence (same logic as verify script)
        def read_value_local(xp):
            try:
                el = driver.find_element(By.XPATH, xp)
                return (el.get_attribute('value') or el.get_attribute('innerText') or el.text or '').strip()
            except Exception:
                return None

        try:
            # open edit modal again
            try:
                el = driver.find_element(By.ID, 'org-menu-EDIT')
                driver.execute_script('arguments[0].click();', el)
                short_sleep(1.2)
            except Exception:
                try:
                    a = driver.find_element(By.XPATH, "//span[contains(., 'Editar Page')]/ancestor::a[1]")
                    driver.execute_script('arguments[0].click();', a)
                    short_sleep(1.2)
                except Exception:
                    pass

            fields = {
                'Name': "//div[@role='dialog']//input[contains(@placeholder,'Nome') or contains(@aria-label,'Name') or contains(@name,'name') or contains(@id,'name') ]",
                'Vanity': "//div[@role='dialog']//input[contains(@placeholder,'company') or contains(@name,'vanity') or contains(@id,'vanity') or contains(@aria-label,'Vanity')]",
                'Slogan': "//div[@role='dialog']//textarea[contains(@placeholder,'Slogan') or contains(@aria-label,'Slogan') or contains(@name,'tagline') or contains(@id,'slogan')]",
                'Website': "//div[@role='dialog']//input[contains(@placeholder,'website') or contains(@name,'website') or contains(@aria-label,'Website') or contains(@id,'website')]",
                'About': "//textarea[contains(@name,'description') or contains(@id,'description') or contains(@placeholder,'Descrição')] | //*[@contenteditable='true' and (contains(@class,'description') or contains(@aria-label,'description') or contains(@placeholder,'Descrição') or contains(@role,'textbox'))]",
            }
            print('\n--- verification (modal readback) ---')
            current = {}
            for k,xp in fields.items():
                v = read_value_local(xp)
                current[k] = v
                print(f"{k}:", repr(v)[:400])
            driver.save_screenshot('/tmp/selenium_linkedin_apply_all_verify_modal.png')

            # If About or Vanity didn't persist, attempt focused retries (set + save) up to 2 times
            def looks_like_about_ok(s):
                return bool(s and len(s) > 20 and ('rpa4all' in s.lower() or 'rpa4all.com' in s.lower()))

            about_ok = looks_like_about_ok(current.get('About'))
            vanity_ok = bool(current.get('Vanity') and len(current.get('Vanity').strip()) > 0)

            if not (about_ok and vanity_ok):
                print('Detected incomplete persistence — retrying focused updates (About/Vanity)')
            retry = 0
            while retry < 2 and not (about_ok and vanity_ok):
                retry += 1
                print(f'Retry attempt {retry} — fixing missing fields')

                # attempt to set Vanity again if missing
                if not vanity_ok:
                    try:
                        vxp = fields['Vanity']
                        if set_input(driver, vxp, PAGE_VANITY, commit_keys='ENTER'):
                            short_sleep(1.0)
                    except Exception:
                        pass

                # attempt to set About again if missing
                if not about_ok:
                    try:
                        # open About section
                        try:
                            btn = driver.find_element(By.XPATH, "//div[@role='dialog']//a[contains(., 'Sobre') or contains(., 'About')]")
                            driver.execute_script('arguments[0].click();', btn)
                            short_sleep(0.6)
                        except Exception:
                            pass

                        desc_xpaths = [
                            "//div[@role='dialog']//textarea[contains(@name,'description') or contains(@id,'description') or contains(@placeholder,'Descrição')]",
                            "//textarea[contains(@name,'description') or contains(@id,'description') or contains(@placeholder,'Descrição') ]",
                            "//*[@contenteditable='true' and (contains(@class,'description') or contains(@aria-label,'description') or contains(@placeholder,'Descrição') or contains(@role,'textbox'))]",
                        ]
                        for dx in desc_xpaths:
                            try:
                                el = driver.find_element(By.XPATH, dx)
                                if try_set_value(driver, el, ABOUT_TEXT):
                                    short_sleep(0.6)
                                    break
                            except Exception:
                                continue
                    except Exception:
                        pass

                # click Save after corrections
                try:
                    for txt in ['Salvar','Save','Publicar','Publish','Done','Atualizar','Update']:
                        try:
                            btn = driver.find_element(By.XPATH, f"//div[@role='dialog']//button[contains(., '{txt}')]")
                            driver.execute_script('arguments[0].click();', btn)
                            short_sleep(2)
                            break
                        except Exception:
                            continue
                except Exception:
                    pass

                # re-open modal and re-read values
                short_sleep(1.5)
                try:
                    el = driver.find_element(By.ID, 'org-menu-EDIT')
                    driver.execute_script('arguments[0].click();', el)
                    short_sleep(1.2)
                except Exception:
                    try:
                        a = driver.find_element(By.XPATH, "//span[contains(., 'Editar Page')]/ancestor::a[1]")
                        driver.execute_script('arguments[0].click();', a)
                        short_sleep(1.2)
                    except Exception:
                        pass

                for k,xp in fields.items():
                    try:
                        current[k] = (driver.find_element(By.XPATH, xp).get_attribute('value') or driver.find_element(By.XPATH, xp).get_attribute('innerText') or driver.find_element(By.XPATH, xp).text or '').strip()
                    except Exception:
                        current[k] = None

                about_ok = looks_like_about_ok(current.get('About'))
                vanity_ok = bool(current.get('Vanity') and len(current.get('Vanity').strip()) > 0)
                print('Post-retry status -> about_ok=', about_ok, 'vanity_ok=', vanity_ok)
                driver.save_screenshot(f'/tmp/selenium_linkedin_apply_all_retry_{retry}.png')

        except Exception:
            pass

        print('Completed — saved=', saved)

    finally:
        try:
            driver.quit()
        except Exception:
            pass


if __name__ == '__main__':
    main()
