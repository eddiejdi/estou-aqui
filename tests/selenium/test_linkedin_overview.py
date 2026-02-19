import os
import pytest
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC

from selenium_helpers import create_driver, short_sleep

EMAIL = "edenilson.adm@gmail.com"
ABOUT_SNIPPET = "rpa4all.com"
COMPANY_ADMIN_DASHBOARD_EDIT = "https://www.linkedin.com/company/37873425/admin/dashboard/?editPage=true"


@pytest.mark.selenium
def test_linkedin_page_overview_contains_rpa4all():
    """Verifica que a seção "Sobre" da Page contém o texto do site RPA4ALL.

    - Requisitos: variável de ambiente `LINKEDIN_PASSWORD` (conta admin).
    - Não altera a Page; apenas valida o conteúdo do `textarea` de descrição.
    """
    password = os.environ.get("LINKEDIN_PASSWORD")
    if not password:
        pytest.skip("LINKEDIN_PASSWORD not set — skipping LinkedIn integration test")

    driver, wait = create_driver(headless=False)
    try:
        # Login
        driver.get("https://www.linkedin.com/login")
        wait.until(EC.presence_of_element_located((By.ID, "username"))).send_keys(EMAIL)
        driver.find_element(By.ID, "password").send_keys(password)
        driver.find_element(By.XPATH, "//button[@type='submit']").click()
        short_sleep(3)

        # Abrir editor (admin dashboard + editPage=true) — espera o textarea de descrição
        driver.get(COMPANY_ADMIN_DASHBOARD_EDIT)
        short_sleep(2)

        ta = wait.until(
            EC.presence_of_element_located((By.XPATH, "//textarea[contains(@name,'description') or contains(@id,'description') or contains(@placeholder,'Descrição')]") )
        )

        # ler valor atual e validar
        val = ta.get_attribute('value') or ta.get_attribute('innerText') or ta.text
        driver.save_screenshot('/tmp/selenium_linkedin_overview_test.png')

        assert val and len(val) > 10, "description textarea is empty or too short"
        assert ABOUT_SNIPPET in val.lower() or 'estou aqui' in val.lower() or 'rpa4all' in val.lower(), (
            "expected overview text (rpa4all/estou aqui) not found in company description"
        )

    finally:
        try:
            driver.quit()
        except Exception:
            pass
