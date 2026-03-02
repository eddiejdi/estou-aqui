#!/usr/bin/env python3
"""Brute-force RPA: dentro do contexto autenticado, tenta muitas variações de endpoints / GraphQL / payloads
para encontrar um que atualize a descrição da Page.
Salva resultado em /tmp/linkedin_bruteforce_result.json
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
COMPANY_URL = "https://www.linkedin.com/company/37873425/"


def main():
    pw = os.environ.get('LINKEDIN_PASSWORD')
    if not pw:
        raise RuntimeError('LINKEDIN_PASSWORD env var not set')

    driver, wait = create_driver(headless=False, enable_performance=True)
    try:
        driver.get('https://www.linkedin.com/login')
        wait.until(EC.presence_of_element_located((By.ID, 'username'))).send_keys(EMAIL)
        driver.find_element(By.ID, 'password').send_keys(pw)
        driver.find_element(By.XPATH, "//button[@type='submit']").click()
        short_sleep(3)

        driver.get(COMPANY_URL)
        short_sleep(2)

        # execute an aggressive in-page brute-force (runs in browser context so cookies+CSRF apply)
        js_bruteforce = '''
        (async function(about){
          function getCookie(name){ const m=document.cookie.match('(^|;)\\s*'+name+'\\s*=\\s*([^;]+)'); return m?m.pop():undefined; }
          const csrf = (getCookie('JSESSIONID')||getCookie('jsessionid')||getCookie('csrfToken')||'').replace(/^\"|\"$/g,'');
          const headersBase = {'content-type':'application/json'}; if(csrf) headersBase['csrf-token']=csrf; headersBase['x-restli-protocol-version']='2.0.0';

          const pageHtml = document.body.innerHTML;
          const found = Array.from(new Set((pageHtml.match(/\\/voyager\\/api\\/[a-zA-Z0-9_\\/:-]+/g)||[]))).slice(0,200);
          const candidates = found.concat(['/voyager/api/pages/organizationPage','/voyager/api/organizationPage','/voyager/api/pages','/voyager/api/graphql','/voyager/api/organizationalPage','/voyager/api/organization']).slice(0,300);

          const bodies = [];
          bodies.push({organization: null, description: about});
          bodies.push({description: about});
          bodies.push({overviewText: about});
          bodies.push({about: about});
          bodies.push({description:{text:about}});
          bodies.push({localizedDescription:{'pt_BR': about}});
          bodies.push({patch:[{op:'replace', path:'/description', value:about}]});
          // also try smaller test marker so we can detect
          bodies.push({description: about + ' [RPA TEST]'});

          const tried = [];
          for(const ep of candidates){
            for(const b of bodies){
              try{
                const url = ep.startsWith('http')? ep : (location.origin + ep);
                // try POST
                const r = await fetch(url, {method:'POST', headers: headersBase, body: JSON.stringify(b), credentials:'include'}).catch(()=>null);
                if(r && (r.status===200||r.status===201||r.status===204)) return {ok:true, endpoint:url, method:'POST', status:r.status, body: (await r.text()).slice(0,500)};
                // try PATCH
                const r2 = await fetch(url, {method:'PATCH', headers: headersBase, body: JSON.stringify(b), credentials:'include'}).catch(()=>null);
                if(r2 && (r2.status===200||r2.status===201||r2.status===204)) return {ok:true, endpoint:url, method:'PATCH', status:r2.status};
                tried.push({ep:url, body:b, status:r? r.status : (r2? r2.status : null)});
              }catch(e){ tried.push({ep:ep, err: String(e)}); }
            }
          }

          // GraphQL queryId brute-force using plausible names + some from page
          const pageQueryIds = Array.from(new Set((pageHtml.match(/queryId=([a-zA-Z0-9_\.\-]+)/g)||[]).map(x=>x.replace('queryId=',''))));
          const qCandidates = ['pagesUpdateOrganization','pagesUpdateOrganizationMutation','voyagerPagesUpdateOrganization','voyagerOrganizationUpdate','organizationUpdate','updateOrganizationPage','organizationEdit','updateOrganization','pageEdit','pagesEditOrganization'].concat(pageQueryIds).slice(0,200);
          for(const q of qCandidates){
            try{
              const gqlUrl = location.origin + '/voyager/api/graphql';
              const vars = {organization: (document.body.innerHTML.match(/urn:li:fsd_organizationalPage:\\d+/)||[null])[0], description: about};
              const payload = {queryId: q, variables: vars};
              const res = await fetch(gqlUrl, {method:'POST', headers: headersBase, body: JSON.stringify(payload), credentials:'include'}).catch(()=>null);
              if(res && (res.status===200||res.status===201)){
                const txt = await res.text().catch(()=>'');
                return {ok:true, endpoint:gqlUrl, queryId:q, status:res.status, body: txt.slice(0,1000)};
              }
            }catch(e){/*ignore*/}
          }

          return {ok:false, tried: tried.slice(0,80), qCandidates: qCandidates.slice(0,40)};
        })(arguments[0]);'''

        res = driver.execute_script(js_bruteforce, ABOUT_TEXT)
        with open('/tmp/linkedin_bruteforce_result.json','w',encoding='utf-8') as f:
            json.dump({'result': res}, f, ensure_ascii=False, indent=2)
        print('BRUTEFORCE result ->', (res if res else 'no-result'))

    finally:
        try:
            driver.quit()
        except Exception:
            pass


if __name__ == '__main__':
    main()
