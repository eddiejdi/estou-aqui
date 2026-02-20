#!/usr/bin/env python3
"""Open company admin edit modal and print current values for Name, Vanity, Slogan, Website, About."""
import os
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium_helpers import create_driver, short_sleep

EMAIL = 'edenilson.adm@gmail.com'
COMPANY_ADMIN_URL = 'https://www.linkedin.com/company/37873425/'


def read_value(driver, xp):
    try:
        el = driver.find_element(By.XPATH, xp)
        val = el.get_attribute('value') or el.get_attribute('innerText') or el.text
        return val.strip()
    except Exception:
        return None


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
        # open edit modal
        try:
            el = driver.find_element(By.ID, 'org-menu-EDIT')
            driver.execute_script('arguments[0].click();', el)
            short_sleep(1.2)
        except Exception:
            pass

        # now read fields
        fields = {
            'Name': "//div[@role='dialog']//input[contains(@placeholder,'Nome') or contains(@aria-label,'Name') or contains(@name,'name') or contains(@id,'name') ]",
            'Vanity': "//div[@role='dialog']//input[contains(@placeholder,'company') or contains(@name,'vanity') or contains(@id,'vanity') or contains(@aria-label,'Vanity')]",
            'Slogan': "//div[@role='dialog']//textarea[contains(@placeholder,'Slogan') or contains(@aria-label,'Slogan') or contains(@name,'tagline') or contains(@id,'slogan')]",
            'Website': "//div[@role='dialog']//input[contains(@placeholder,'website') or contains(@name,'website') or contains(@aria-label,'Website') or contains(@id,'website')]",
            'About': "//textarea[contains(@name,'description') or contains(@id,'description') or contains(@placeholder,'Descrição')]",
        }
        for k,xp in fields.items():
            v = read_value(driver, xp)
            print(f'{k}:', repr(v)[:400])
        driver.save_screenshot('/tmp/selenium_linkedin_verify_fields.png')
    finally:
        try:
            driver.quit()
        except Exception:
            pass


if __name__ == '__main__':
    main()
