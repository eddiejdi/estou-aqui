from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
import requests
import json


def create_driver(geolocation=None, headless=False):
    options = webdriver.ChromeOptions()
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    if headless:
        options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_experimental_option("prefs", {"profile.default_content_setting_values.geolocation": 1})

    driver = webdriver.Chrome(options=options)

    if geolocation:
        try:
            driver.execute_cdp_cmd("Emulation.setGeolocationOverride", {
                "latitude": geolocation[0],
                "longitude": geolocation[1],
                "accuracy": geolocation[2] if len(geolocation) > 2 else 100,
            })
        except Exception:
            pass

    wait = WebDriverWait(driver, 20)
    return driver, wait


def click_by_text(wait, text):
    el = wait.until(EC.element_to_be_clickable((By.XPATH, f"//*[contains(text(),'{text}')]")))
    el.click()
    return el


def fill_input_by_placeholder(driver, wait, placeholder, value, tag='input'):
    try:
        el = wait.until(EC.presence_of_element_located((By.XPATH, f"//{tag}[contains(@placeholder, '{placeholder}')]")))
        el.clear()
        el.send_keys(value)
        return True
    except Exception:
        return False


def find_text(driver, text):
    try:
        return driver.find_element(By.XPATH, f"//*[contains(text(),'{text}')]")
    except Exception:
        return None


def short_sleep(t=1.0):
    time.sleep(t)


def register_and_login(api_base: str, name: str, email: str, password: str):
    """Register a new user (or login if already exists) and return (token, user_dict).

    `api_base` should be like http://localhost:3000/api
    """
    headers = {"Content-Type": "application/json"}
    payload = {"name": name, "email": email, "password": password}

    # Try register
    try:
        r = requests.post(f"{api_base}/auth/register", json=payload, headers=headers, timeout=5)
    except Exception as e:
        raise RuntimeError(f"API register request failed: {e}")

    if r.status_code == 201:
        data = r.json()
        return data.get('token'), data.get('user')

    # If conflict or other, try login
    try:
        r2 = requests.post(f"{api_base}/auth/login", json={"email": email, "password": password}, headers=headers, timeout=5)
    except Exception as e:
        raise RuntimeError(f"API login request failed: {e}")

    if r2.status_code == 200:
        data = r2.json()
        return data.get('token'), data.get('user')

    raise RuntimeError(f"Auth failed (register/login). register_status={r.status_code}, login_status={r2.status_code}")
