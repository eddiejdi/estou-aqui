#!/usr/bin/env python3
import time
import random
import json
import requests
from selenium_helpers import create_driver, short_sleep, find_text, register_and_login


def run(url: str, headless: bool = False):
    driver, wait = create_driver(headless=headless)
    try:
        # Use API to register/login, then set localStorage so the web app is authenticated
        api_base = 'http://localhost:3000/api'
        name = f'TestUser{random.randint(1000,9999)}'
        email = f'{name.lower()}@example.com'
        password = 'password123'
        token, user = register_and_login(api_base, name, email, password)

        # verify auth by calling /api/auth/me
        r = requests.get(f"http://localhost:3000/api/auth/me", headers={'Authorization': f'Bearer {token}'}, timeout=5)
        if r.status_code == 200:
            print('Auth flow OK (API)')
        else:
            raise AssertionError(f'Auth flow failed (me): {r.status_code} {r.text}')

    finally:
        driver.quit()


if __name__ == '__main__':
    run('http://localhost:34951/#/events', headless=False)
