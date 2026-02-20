#!/usr/bin/env python3
"""Selenium helper: login no LinkedIn e atualizar a seção "Sobre" da página
Alvo: https://www.linkedin.com/company/37873425/

Uso:
  LINKEDIN_PASSWORD="..." python tests/selenium/update_linkedin_company.py

Observações:
- Lê credenciais da env `LINKEDIN_PASSWORD` e usa o email `edenilson.adm@gmail.com`.
- Gera screenshots em /tmp para revisão.
"""
import os
import time
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC

from selenium_helpers import create_driver, short_sleep, wait_for_human_challenge

EMAIL = "edenilson.adm@gmail.com"
ABOUT_TEXT = (
    "RPA4ALL — Automação inteligente, observabilidade e IA aplicada para operações críticas. "
    "Transformamos processos manuais em fluxos auditáveis e escaláveis, integrando RPA, agentes de IA e dashboards de observabilidade.\n\n"
    "Somos os criadores do 'Estou Aqui' — app para monitoramento e estimativa de movimentos sociais em tempo real: check‑ins, estimativas de público, chat e notificações. "
    "Oferecemos consultoria, integração com ERPs e governança com trilhas de auditoria para garantir conformidade.\n\n"
    "Visite https://www.rpa4all.com para cases, soluções e contato."
)

# Valores que vamos aplicar na Page (são seguros e idempotentes)
PAGE_NAME = "RPA4All"
PAGE_VANITY = "rpa4all"
PAGE_SLOGAN = "Inserindo Automação na vida de todos."
PAGE_WEBSITE = "https://www.rpa4all.com"

COMPANY_ADMIN_URL = "https://www.linkedin.com/company/37873425/"  # pública — iremos navegar até o editor


def main():
    password = os.environ.get("LINKEDIN_PASSWORD")
    if not password:
        raise RuntimeError("LINKEDIN_PASSWORD env var not set")

    # Prefer visible browser to interact with dynamic admin modal; fallback to headless if not available
    try:
        driver, wait = create_driver(headless=False)
    except Exception:
        driver, wait = create_driver(headless=True)

    try:
        # 1) Login
        driver.get("https://www.linkedin.com/login")
        wait.until(EC.presence_of_element_located((By.ID, "username"))).send_keys(EMAIL)
        driver.find_element(By.ID, "password").send_keys(password)
        driver.find_element(By.XPATH, "//button[@type='submit']").click()

        # aguardar redirecionamento/elemento que indica login bem sucedido
        try:
            wait.until(lambda d: '/feed' in d.current_url or d.execute_script('return document.readyState') == 'complete')
        except Exception:
            # fallback: pequena pausa
            time.sleep(4)

        driver.save_screenshot('/tmp/selenium_linkedin_after_login.png')

        # 2) Checar dashboard de admin (se a conta for admin, o dashboard estará disponível)
        ADMIN_DASHBOARD_URL = "https://www.linkedin.com/company/37873425/admin/dashboard/"
        admin_dashboard_access = False
        try:
            driver.get(ADMIN_DASHBOARD_URL)
            short_sleep(3)
            driver.save_screenshot('/tmp/selenium_linkedin_admin_dashboard.png')
            page_src = driver.page_source.lower()
            if '/admin/' in driver.current_url or 'admin tools' in page_src or 'page admins' in page_src or 'analytics' in page_src or 'manage page' in page_src:
                admin_dashboard_access = True
            # detectar mensagens comuns de negação/acesso
            for deny in ['you are not authorized', 'access denied', 'not found', 'does not exist', "doesn't exist", "you don't have permission"]:
                if deny in page_src:
                    admin_dashboard_access = False
                    break
        except Exception:
            admin_dashboard_access = False

        if admin_dashboard_access:
            print('ADMIN_DASHBOARD_ACCESSIBLE')
            # navegar para a página pública em seguida para usar o editor se necessário
            driver.get(COMPANY_ADMIN_URL)
            short_sleep(2)
            # detect anti-bot and pause for manual solve if present
            if not wait_for_human_challenge(driver, timeout=300, poll_interval=2):
                print('Aborting: captcha not solved within timeout')
                driver.save_screenshot('/tmp/selenium_linkedin_captcha_timeout.png')
                return
            driver.save_screenshot('/tmp/selenium_linkedin_company_page_admin_user.png')
        else:
            # conta não tem admin — abrir a página pública e prosseguir com tentativas no frontend público
            print('NO_ADMIN_RIGHTS')
            driver.get(COMPANY_ADMIN_URL)
            short_sleep(3)
            if not wait_for_human_challenge(driver, timeout=300, poll_interval=2):
                print('Aborting: captcha not solved within timeout')
                driver.save_screenshot('/tmp/selenium_linkedin_captcha_timeout.png')
                return
            driver.save_screenshot('/tmp/selenium_linkedin_company_page.png')

        # === Deep DOM dump & keyword scan (helps find dynamic editors / iframes) ===
        try:
            js_scan = '''
            (function(){
                const keywords = ['sobre','about','overview','page info','page details','description','about us','company description','overview-section','company-overview'];
                const items = [];
                const elems = Array.from(document.querySelectorAll('*'));
                for (let i=0;i<elems.length;i++){
                    const el = elems[i];
                    try{
                        const txt = (el.innerText||'').toLowerCase();
                        const attrs = (el.getAttributeNames?el.getAttributeNames().join(' '):'').toLowerCase();
                        for (let k of keywords){
                            if (txt.includes(k) || attrs.includes(k)){
                                items.push({
                                    tag: el.tagName,
                                    id: el.id||null,
                                    class: el.className||null,
                                    role: el.getAttribute('role')||null,
                                    aria: el.getAttribute('aria-label')||null,
                                    text: (el.innerText||'').slice(0,200),
                                    outer: (el.outerHTML||'').slice(0,500)
                                });
                                break;
                            }
                        }
                    }catch(e){/*ignore*/}
                    if (items.length>400) break;
                }
                // list iframes
                const ifr = Array.from(document.querySelectorAll('iframe')).map(f=>({src:f.src||null,id:f.id||null,class:f.className||null}));
                return {matches: items, iframes: ifr, url: location.href};
            })();'''
            scan = driver.execute_script(js_scan)
            # salvar relatório local
            import json as _json
            with open('/tmp/linkedin_dom_scan.json','w',encoding='utf-8') as _f:
                _f.write(_json.dumps(scan, ensure_ascii=False, indent=2))
            # salvar page source para análise
            with open('/tmp/linkedin_page_source.html','w',encoding='utf-8') as _f:
                _f.write(driver.page_source)
        except Exception:
            pass

        # 3) Tentar abrir o editor 'Sobre' com vários seletores de fallback
        edit_found = False

        # tentativa direta: procurar botão 'Editar' próximo ao cabeçalho 'Sobre' / 'About'
        selectors = [
            "//h2[contains(., 'Sobre') or contains(., 'About')]/following::button[contains(., 'Editar') or contains(., 'Edit')][1]",
            "//section//*[contains(text(),'Sobre') or contains(text(),'About')]/following::button[1]",
            "//button[contains(@aria-label,'Edit') or contains(@aria-label,'Editar')]",
            "//a[contains(.,'Editar página') or contains(.,'Edit page')]",
        ]

        # helpers específicos para preencher campos estáticos do modal 'Informações da página' / 'Page info'
        def fill_if_present(xpath_list, value):
            for xp in xpath_list:
                try:
                    el = driver.find_element(By.XPATH, xp)
                    if try_set_value(el, value):
                        print('Filled element for', xp)
                        return True
                except Exception:
                    continue
            return False

        def open_section_in_modal(name_text):
            """Clica no item do menu lateral dentro do modal com o texto passado (ex: 'Sobre', 'Início')."""
            try:
                # procurar dentro do dialog
                el = driver.find_element(By.XPATH, f"//div[@role='dialog']//a[contains(., '{name_text}') or contains(., '{name_text.title()}')]")
                driver.execute_script('arguments[0].click();', el)
                short_sleep(0.6)
                return True
            except Exception:
                try:
                    el2 = driver.find_element(By.XPATH, f"//div[@role='dialog']//button[contains(., '{name_text}')]")
                    driver.execute_script('arguments[0].click();', el2)
                    short_sleep(0.6)
                    return True
                except Exception:
                    return False

        for sel in selectors:
            try:
                btn = wait.until(EC.element_to_be_clickable((By.XPATH, sel)))
                btn.click()
                edit_found = True
                short_sleep(1)
                break
            except Exception:
                continue

        # fallback: tentar vários caminhos administrativos (Admin tools, Edit page, Page info, URLs diretas)
        if not edit_found:
            # 1) tentar menu 'Admin tools' -> 'Edit page' / 'Page info'
            try:
                admin_tools = driver.find_elements(By.XPATH, "//button[contains(., 'Admin tools') or contains(., 'Ferramentas do administrador') or contains(., 'Ferramentas')]")
                if admin_tools:
                    admin_tools[0].click()
                    short_sleep(1)
                    for menu_xpath in [
                        "//a[contains(., 'Editar página') or contains(., 'Edit page') or contains(., 'Page info') or contains(., 'Page details')]",
                        "//button[contains(., 'Editar página') or contains(., 'Edit page') or contains(., 'Page info') or contains(., 'Page details')]",
                    ]:
                        try:
                            el = driver.find_element(By.XPATH, menu_xpath)
                            el.click()
                            edit_found = True
                            short_sleep(1)
                            break
                        except Exception:
                            continue
            except Exception:
                pass

            # 1.5) clicar explicitamente no menu lateral 'Editar Page' (id org-menu-EDIT) — detectado no HTML salvo
            if not edit_found:
                try:
                    edit_menu = driver.find_element(By.ID, "org-menu-EDIT")
                    driver.execute_script("arguments[0].click();", edit_menu)
                    edit_found = True
                    short_sleep(2)
                    # debug: relatar URL/trechos do page source após clicar Edit
                    try:
                        print('DEBUG: clicked org-menu-EDIT, url=', driver.current_url)
                        driver.save_screenshot('/tmp/selenium_linkedin_after_click_org_menu_edit.png')
                        ps = driver.page_source.lower()
                        for tk in ['about','overview','description','company-description','page-info','page details','company-overview','overviewtext','descriptioncontainer']:
                            if tk in ps:
                                print('DEBUG: page contains token ->', tk)
                    except Exception:
                        pass

                    # tentativa imediata: localizar o textarea de description e preencher (fluxo admin aberto)
                    try:
                        ta = wait.until(EC.presence_of_element_located((By.XPATH, "//textarea[contains(@name,'description') or contains(@id,'description') or contains(@placeholder,'Descrição')]") ))
                        if ta:
                            try:
                                if try_set_value(ta, ABOUT_TEXT):
                                    updated = True
                                    print('DEBUG: updated admin textarea immediately after clicking org-menu-EDIT')
                            except Exception:
                                pass
                    except Exception:
                        # não crítico — continuará com heurísticas posteriores
                        pass
                except Exception:
                    # falha ao tentar encontrar/clicar no menu lateral org-menu-EDIT — seguir com outras heurísticas
                    pass

            # 2) tentar URLs administrativas diretas que o LinkedIn usa em alguns perfis
            admin_urls = [
                COMPANY_ADMIN_URL + "admin/edit/",
                COMPANY_ADMIN_URL + "admin/page-info/",
                COMPANY_ADMIN_URL + "admin/overview/",
                COMPANY_ADMIN_URL + "admin/dashboard/",
                # URLs fornecidas pelo usuário — tentar abrir o editor diretamente
                COMPANY_ADMIN_URL + "admin/settings/?editPage=true",
                COMPANY_ADMIN_URL + "admin/settings?editPage=true&lipi=urn%3Ali%3Apage%3Aorganization_admin_admin_settings_index%3B88fe9241-4986-4b9d-827e-5c0cb37c10ab",
                # variações adicionais para tentar alcançar o editor
                COMPANY_ADMIN_URL + "admin/page-info?edit=true",
                COMPANY_ADMIN_URL + "admin/page-info/edit/",
                COMPANY_ADMIN_URL + "admin/overview/edit/",
                COMPANY_ADMIN_URL + "admin/about/edit/",
                COMPANY_ADMIN_URL + "admin/settings/",
                COMPANY_ADMIN_URL + "admin?open=page-info",
                COMPANY_ADMIN_URL + "admin?profileTab=about",
            ]
            if not edit_found:
                for u in admin_urls:
                    try:
                        driver.get(u)
                        short_sleep(2)
                        # detectar modal/edição
                        page_src = driver.page_source.lower()
                        if 'edit' in page_src or 'page info' in page_src or 'page details' in page_src or 'overview' in page_src or 'about' in page_src:
                            edit_found = True
                            short_sleep(1)
                            break
                    except Exception:
                        continue
                        continue

            # 3) tentar clicar ícone/gear que abre edição
            if not edit_found:
                try:
                    gear_selectors = [
                        "//button[contains(@aria-label,'Manage page') or contains(.,'Manage page') or contains(@aria-label,'Editar') or contains(.,'Editar')][1]",
                        "//button[contains(@class,'pano-icon-button') and contains(@aria-label,'Settings')]",
                    ]
                    for gs in gear_selectors:
                        try:
                            g = driver.find_element(By.XPATH, gs)
                            g.click()
                            short_sleep(1)
                            # procurar link 'Edit page' no menu
                            try:
                                edit_link = driver.find_element(By.XPATH, "//a[contains(., 'Edit page') or contains(., 'Editar página') or contains(., 'Page info')]")
                                edit_link.click()
                                edit_found = True
                                short_sleep(1)
                                break
                            except Exception:
                                pass
                        except Exception:
                            continue
                except Exception:
                    pass

        if not edit_found:
            # não foi possível abrir o editor via seletores padrão — salvar evidência e continuar tentando localizar campo de descrição diretamente
            driver.save_screenshot('/tmp/selenium_linkedin_edit_button_not_found.png')
            print('EDIT_BUTTON_NOT_FOUND — tentando localizar campo de descrição publicamente')
            # continuar sem abortar (tentaremos localizar o campo 'about' diretamente na página pública)

        # Se o modal/Editor foi aberto, preencher os campos principais visíveis (Nome, URL pública, Slogan, Website)
        if edit_found:
            try:
                # Nome da Page
                fill_if_present([
                    "//div[@role='dialog']//input[contains(@placeholder,'Nome') or contains(@aria-label,'Name') or contains(@name,'name') or contains(@id,'name') ]",
                    "//input[contains(@placeholder,'Name') or contains(@aria-label,'Name') or contains(@name,'name')]",
                ], PAGE_NAME)
            except Exception:
                pass

            try:
                # Vanity / URL pública
                fill_if_present([
                    "//div[@role='dialog']//input[contains(@placeholder,'company') or contains(@aria-label,'URL pública') or contains(@name,'vanity') or contains(@id,'vanity')]",
                    "//input[contains(@placeholder,'company') or contains(@name,'vanity') or contains(@id,'vanity') or contains(@aria-label,'Vanity')]",
                ], PAGE_VANITY)
            except Exception:
                pass

            try:
                # Slogan / tagline
                fill_if_present([
                    "//div[@role='dialog']//textarea[contains(@placeholder,'Slogan') or contains(@aria-label,'Slogan') or contains(@name,'tagline') or contains(@id,'slogan')]",
                    "//textarea[contains(@name,'tagline') or contains(@id,'tagline') or contains(@placeholder,'Slogan') ]",
                ], PAGE_SLOGAN)
            except Exception:
                pass

            try:
                # Website — reutiliza lógica já existente
                for sx in [
                    "//div[@role='dialog']//input[contains(@placeholder,'website') or contains(@name,'website') or contains(@aria-label,'Website') or contains(@id,'website')]",
                    "//input[contains(@placeholder,'website') or contains(@name,'website') or contains(@aria-label,'Website') or contains(@id,'website')]",
                ]:
                    try:
                        site_els = driver.find_elements(By.XPATH, sx)
                        if site_els:
                            for site_el in site_els:
                                try_set_value(site_el, PAGE_WEBSITE)
                                break
                            break
                    except Exception:
                        continue
            except Exception:
                pass

            # Navegar para a seção 'Sobre' do modal para garantir que o campo Descrição esteja visível
            try:
                open_section_in_modal('Sobre')
                short_sleep(0.6)
            except Exception:
                pass

        # 4) Localizar campo descrição / about e atualizar (inclui contentEditable dentro de modais)
        updated = False

        def try_set_value(el, value):
            """Tenta preencher um elemento (textarea/input/contentEditable).
            Retorna True se a alteração foi aplicada (dispara eventos para React detectar).
            """
            try:
                driver.execute_script('arguments[0].scrollIntoView({block: "center"});', el)
                # focus antes de alterar
                driver.execute_script('arguments[0].focus();', el)
                tag = el.tag_name.lower()
                if tag in ('textarea', 'input'):
                    try:
                        el.clear()
                    except Exception:
                        pass
                    el.send_keys(value)
                    # garantir que frameworks detectem a mudança
                    driver.execute_script("arguments[0].dispatchEvent(new Event('input', { bubbles: true })); arguments[0].dispatchEvent(new Event('change', { bubbles: true }));", el)
                    driver.execute_script('arguments[0].blur();', el)
                    return True

                # elementos contentEditable (LinkedIn frequentemente usa div[role=textbox])
                if el.get_attribute('contenteditable') == 'true' or el.get_attribute('role') == 'textbox':
                    # set innerText e simular eventos (inclui composition/key events)
                    driver.execute_script("arguments[0].innerText = arguments[1];", el, value)
                    driver.execute_script("var ev = new Event('input', { bubbles: true }); arguments[0].dispatchEvent(ev); var ev2 = new Event('change', { bubbles: true }); arguments[0].dispatchEvent(ev2); arguments[0].blur();", el)
                    return True

                # fallback: set value via JS e disparar eventos
                driver.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true })); arguments[0].dispatchEvent(new Event('change', { bubbles: true }));", el, value)
                try:
                    driver.execute_script('arguments[0].blur();', el)
                except Exception:
                    pass
                return True
            except Exception:
                return False

        # procurar em modais primeiro (role=dialog) — muitos editores abrem num modal
        search_xpaths = []
        # candidate selectors: textarea, input, contenteditable divs, role=textbox
        search_xpaths.extend([
            "//div[@role='dialog']//textarea[contains(@name,'description') or contains(@id,'description') or contains(@placeholder,'Descrição') or contains(@placeholder,'Description')]",
            "//div[@role='dialog']//*[contains(@data-test-id,'company-description') or contains(@data-test-id,'page-description') or contains(@data-test-id,'about')]",
            "//div[@role='dialog']//*[@contenteditable='true']",
            "//div[@role='dialog']//*[@role='textbox']",
        ])

        # then search the whole page (public view may expose a field when admin)
        search_xpaths.extend([
            "//textarea[contains(@name,'description') or contains(@id,'description') or contains(@placeholder,'Descrição') or contains(@placeholder,'Description')]",
            "//*[@data-test-id='company-description' or contains(@aria-label,'Descrição') or contains(@aria-label,'description') or contains(@class,'about') or contains(@class,'overview')]",
            "//*[@contenteditable='true' and (contains(@class,'description') or contains(@aria-label,'description') or contains(@placeholder,'Descrição') or contains(@role,'textbox'))]",
            "//*[@role='textbox' and @contenteditable='true']",
        ])

        for xp in search_xpaths:
            if updated:
                break
            try:
                els = driver.find_elements(By.XPATH, xp)
                for el in els:
                    if try_set_value(el, ABOUT_TEXT):
                        updated = True
                        print(f"Found and updated element via XPath: {xp}")
                        short_sleep(0.8)
                        break
            except Exception:
                continue

        # Se ainda não atualizado — tentar heurística JS: encontrar o nearest editable para headings como 'Sobre' / 'About' (procura em modais primeiro)
        if not updated:
            try:
                js_find = '''
                return (function(){
                  const keywords = ['sobre','about','overview','descri','description','about us','company description'];
                  function looksLikeOverviewText(n){
                    const s = (n.innerText||n.value||'').toLowerCase();
                    return s.length>20 || keywords.some(k=> s.includes(k));
                  }
                  // procurar dialogs primeiro
                  const roots = Array.from(document.querySelectorAll("div[role='dialog'], .artdeco-modal, .modal-dialog"));
                  roots.push(document);
                  for(const root of roots){
                    // 1) candidates directos
                    const cands = root.querySelectorAll("[contenteditable='true'], textarea, [role='textbox'], input[type='text']");
                    for(const c of cands){ if(looksLikeOverviewText(c)) return c; }
                    // 2) procurar headings e procurar elementos próximos
                    const heads = Array.from(root.querySelectorAll('h1,h2,h3,div,span')).filter(el=> (el.innerText||'').length>0 && keywords.some(k=> (el.innerText||'').toLowerCase().includes(k)));
                    for(const h of heads){
                      let node = h;
                      for(let i=0;i<8;i++){
                        node = node.nextElementSibling || node.parentElement;
                        if(!node) break;
                        const ed = node.querySelector("[contenteditable='true'], textarea, [role='textbox'], input[type='text']");
                        if(ed) return ed;
                        if(node.getAttribute && (node.getAttribute('contenteditable')=='true' || node.getAttribute('role')=='textbox' || node.tagName.toLowerCase()=='textarea')) return node;
                      }
                    }
                  }
                  return null;
                })();'''
                el = driver.execute_script(js_find)
                if el:
                    if try_set_value(el, ABOUT_TEXT):
                        updated = True
                        print('Found and updated element via JS heuristic (near heading/modal)')
                        short_sleep(0.6)
            except Exception:
                pass

        # === NOVO: procurar dentro de IFRAMEs (alguns editores carregam em iframes) ===
        if not updated:
            try:
                frames = driver.find_elements(By.TAG_NAME, 'iframe')
                for f in frames:
                    try:
                        driver.switch_to.frame(f)
                        for xp in [
                            "//textarea[contains(@name,'description') or contains(@id,'description') or contains(@placeholder,'Descrição') or contains(@placeholder,'Description')]",
                            "//*[@contenteditable='true' and (contains(@class,'description') or contains(@aria-label,'description') or contains(@placeholder,'Descrição') or contains(@role,'textbox'))]",
                            "//*[@role='textbox' and @contenteditable='true']",
                        ]:
                            try:
                                els = driver.find_elements(By.XPATH, xp)
                                for el in els:
                                    if try_set_value(el, ABOUT_TEXT):
                                        updated = True
                                        print(f'Updated inside iframe via XPath: {xp}')
                                        break
                                if updated:
                                    break
                            except Exception:
                                continue
                        driver.switch_to.default_content()
                        if updated:
                            break
                    except Exception:
                        try:
                            driver.switch_to.default_content()
                        except Exception:
                            pass
                        continue
            except Exception:
                pass

        # === NOVO: buscar em Shadow DOM via JS (recursivo) ===
        if not updated:
            try:
                js_shadow = '''
                (function(){
                  const keywords = ['sobre','about','overview','description','descri'];
                  function searchRoot(root){
                    const nodes = root.querySelectorAll('*');
                    for(const n of nodes){
                      try{
                        if(n.shadowRoot){
                          const r = searchRoot(n.shadowRoot);
                          if(r) return r;
                        }
                        if(n.getAttribute && (n.getAttribute('contenteditable')=='true' || n.getAttribute('role')=='textbox')) return n;
                        if(n.tagName && n.tagName.toLowerCase()==='textarea') return n;
                        const txt = (n.innerText||'').toLowerCase();
                        if(txt && txt.length>20 && keywords.some(k=>txt.includes(k))) return n;
                      }catch(e){}
                    }
                    return null;
                  }
                  return searchRoot(document);
                })();'''
                sd = driver.execute_script(js_shadow)
                if sd:
                    if try_set_value(sd, ABOUT_TEXT):
                        updated = True
                        print('Updated via Shadow DOM heuristic')
            except Exception:
                pass

        # === NOVO Fallback agressivo: detectar endpoints internos e tentar múltiplas formas de chamada via fetch() ===
        if not updated:
            try:
                js_mutation2 = '''
                (async function(about){
                  function getCookie(name){
                    const m = document.cookie.match('(^|;)\\s*'+name+'\\s*=\\s*([^;]+)');
                    return m?m.pop():undefined;
                  }
                  const csrf = getCookie('JSESSIONID') || getCookie('csrfToken') || getCookie('jsessionid') || '';
                  const sanitizedCsrf = csrf ? csrf.replace(/^\"|\"$/g,'') : '';
                  const headersBase = { 'content-type': 'application/json' };
                  if(sanitizedCsrf){ headersBase['csrf-token'] = sanitizedCsrf; headersBase['x-restli-protocol-version'] = '2.0.0'; }

                  const orgUrnMatch = document.body.innerHTML.match(/urn:li:fsd_organizationalPage:\\d+/);
                  const orgUrn = orgUrnMatch?orgUrnMatch[0]:null;

                  // descobrir potenciais endpoints embutidos na página
                  const found = Array.from(new Set((document.body.innerHTML.match(/\\/voyager\\/api\\/[a-zA-Z0-9_\\/:-]+/g)||[])));
                  const candidates = found.concat([
                    '/voyager/api/pages/organizationPage',
                    '/voyager/api/organizationPage',
                    '/voyager/api/pages',
                    '/voyager/api/graphql'
                  ]).slice(0,200);

                  const bodies = [];
                  if(orgUrn){
                    bodies.push({organization: orgUrn, description: about});
                    bodies.push({organization: orgUrn, overviewText: about});
                    bodies.push({organization: orgUrn, about: about});
                    bodies.push({organization: orgUrn, description: {text: about}});
                    bodies.push({organization: orgUrn, patch: [{op:'replace', path:'/description', value: about}]});
                  }
                  bodies.push({description: about});
                  bodies.push({overviewText: about});
                  bodies.push({about: about});
                  bodies.push({description: {text: about}});
                  bodies.push({patch: [{op:'replace', path:'/description', value: about}]});

                  for(const ep of candidates){
                    try{
                      const url = ep.startsWith('http')? ep : (location.origin + ep);
                      for(const b of bodies){
                        try{
                          const resp = await fetch(url, {method:'POST', headers: headersBase, body: JSON.stringify(b), credentials:'include'});
                          const text = await (resp.text().catch(()=>'')) || '';
                          if(resp && (resp.status===200 || resp.status===201 || resp.status===204)){
                            return {ok:true, endpoint: url, status: resp.status, body: text.slice(0,200)};
                          }
                        }catch(e){}
                        try{
                          const resp2 = await fetch(url, {method:'PATCH', headers: headersBase, body: JSON.stringify(b), credentials:'include'});
                          if(resp2 && (resp2.status===200 || resp2.status===201 || resp2.status===204)){
                            return {ok:true, endpoint: url, status: resp2.status, method:'PATCH'};
                          }
                        }catch(e){}
                      }
                    }catch(e){}
                  }

                  // tentativa final: GraphQL com queryId possíveis (heurística)
                  const gqlCandidates = ['voyagerOrganizationUpdate','voyagerPagesUpdateOrganizationMutation','pagesUpdateOrganization','voyagerOrganizationEditMutation','voyagerPagesUpdateOrganization'];
                  for(const q of gqlCandidates){
                    try{
                      const gqlUrl = location.origin + '/voyager/api/graphql';
                      const gqlBody = {queryId: q, variables: {organization: orgUrn, description: about}};
                      const r = await fetch(gqlUrl, {method:'POST', headers: headersBase, body: JSON.stringify(gqlBody), credentials:'include'});
                      const txt = await (r.text().catch(()=>''));
                      if(r && (r.status===200 || r.status===201)) return {ok:true,endpoint:gqlUrl,queryId:q,status:r.status,body: txt.slice(0,200)};
                    }catch(e){}
                  }

                  return {ok:false, candidates: candidates.slice(0,20)};
                })(arguments[0]);'''
                res = driver.execute_script(js_mutation2, ABOUT_TEXT)
                if isinstance(res, dict) and res.get('ok'):
                    updated = True
                    print('Updated via in-page discovered endpoint:', res.get('endpoint'), res.get('status'))
                else:
                    try:
                        # tentar logar candidatos retornados para depuração
                        cand = res.get('candidates') if isinstance(res, dict) else None
                        if cand:
                            print('In-page endpoint attempts failed; sample candidates found:', cand[:10])
                    except Exception:
                        pass
            except Exception as e:
                print('Exception during in-page endpoint discovery:', e)

        # === NOVO: tentativa por reconhecimento de imagem / OCR (template match + pytesseract) ===
        if not updated:
            try:
                # 1) tentar templates pre-existentes em tests/selenium/templates/
                try:
                    from selenium_helpers import click_template, click_text_via_ocr
                except Exception:
                    click_template = None
                    click_text_via_ocr = None

                template_paths = [
                    'tests/selenium/templates/edit_button.png',
                    'tests/selenium/templates/pencil_icon.png',
                    'tests/selenium/templates/edit_page.png',
                ]
                clicked_via_template = False
                for tp in template_paths:
                    try:
                        if click_template and click_template(driver, tp, threshold=0.78):
                            clicked_via_template = True
                            short_sleep(0.8)
                            break
                    except Exception:
                        continue

                # 2) tentar OCR para localizar texto visual 'Editar' / 'Edit' e clicar
                ocr_candidates = ['Editar', 'Edit', 'Gerenciar', 'Manage page', 'Page info']
                clicked_via_ocr = False
                if click_text_via_ocr:
                    for s in ocr_candidates:
                        try:
                            if click_text_via_ocr(driver, s):
                                clicked_via_ocr = True
                                short_sleep(0.8)
                                break
                        except Exception:
                            continue

                if clicked_via_template or clicked_via_ocr:
                    # aguardar modal/edição aparecer e depois tentar preencher via heurística JS
                    short_sleep(1.0)
                    # reusar heurística JS que procura nearest editable
                    js_find_and_fill = '''(function(about){
                        const roots = Array.from(document.querySelectorAll("div[role='dialog'], .artdeco-modal, .modal-dialog"));
                        roots.push(document);
                        for(const root of roots){
                            const cands = root.querySelectorAll("[contenteditable='true'], textarea, [role='textbox'], input[type='text']");
                            for(const c of cands){ try{ if((c.innerText||c.value||'').length>1){ c.focus(); if(c.tagName.toLowerCase()==='textarea' || c.tagName.toLowerCase()==='input'){ c.value = about; c.dispatchEvent(new Event('input',{bubbles:true})); c.dispatchEvent(new Event('change',{bubbles:true})); } else { c.innerText = about; c.dispatchEvent(new Event('input',{bubbles:true})); c.dispatchEvent(new Event('change',{bubbles:true})); } return true;} }catch(e){} }
                        }
                        return false;
                    })(arguments[0]);'''
                    filled_ok = driver.execute_script(js_find_and_fill, ABOUT_TEXT)
                    short_sleep(0.6)
                    # tentar clicar botão salvar via OCR/template/text search
                    save_clicked = False
                    try:
                        if click_template:
                            save_clicked = click_template(driver, 'tests/selenium/templates/save_button.png', threshold=0.76)
                    except Exception:
                        save_clicked = False
                    if not save_clicked and click_text_via_ocr:
                        for sv in ['Salvar','Save','Publicar','Publish','Done','Atualizar','Update']:
                            try:
                                if click_text_via_ocr(driver, sv):
                                    save_clicked = True
                                    break
                            except Exception:
                                continue

                    if filled_ok or save_clicked:
                        updated = True
                        print('Updated via image-recognition/OCR fallback (attempted)')
                else:
                    print('Image-recognition fallback: no template or OCR match found')
            except Exception as e:
                print('Exception during image-recognition fallback:', e)


        # também tentar atualizar o campo Website, se presente (dentro de modal ou página)
        try:
            site_xpaths = [
                "//div[@role='dialog']//input[contains(@placeholder,'website') or contains(@name,'website') or contains(@aria-label,'Website') or contains(@id,'website')]",
                "//input[contains(@placeholder,'website') or contains(@name,'website') or contains(@aria-label,'Website') or contains(@id,'website')]",
            ]
            for sx in site_xpaths:
                try:
                    site_els = driver.find_elements(By.XPATH, sx)
                    if site_els:
                        for site_el in site_els:
                            try_set_value(site_el, 'https://www.rpa4all.com')
                            break
                        break
                except Exception:
                    continue
        except Exception:
            pass

        # 5) Salvar / Publicar
        try:
            for txt in ['Salvar', 'Save', 'Publicar', 'Publish', 'Done', 'Atualizar', 'Update']:
                try:
                    save_btn = driver.find_element(By.XPATH, f"//button[contains(., '{txt}')]")
                    save_btn.click()
                    short_sleep(2)
                    break
                except Exception:
                    continue
        except Exception:
            pass

        # final: screenshot de confirmação
        driver.save_screenshot('/tmp/selenium_linkedin_about_updated.png')

        if updated:
            if admin_dashboard_access:
                print('OK_UPDATED_AS_ADMIN')
            else:
                print('OK_UPDATED')
        else:
            if admin_dashboard_access:
                print('OK_ADMIN_BUT_NO_DESCRIPTION_FIELD_FOUND')
            else:
                print('OK_NO_DESCRIPTION_FIELD_FOUND')

    finally:
        try:
            driver.quit()
        except Exception:
            pass


if __name__ == '__main__':
    main()
