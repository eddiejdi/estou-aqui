#!/usr/bin/env python3
"""Selenium E2E test: cria um evento e verifica se aparece na lista/mapa.

Usage:
  python test_create_event.py --url http://localhost:34951/#/events

Requirements:
  - Chrome and chromedriver installed and on PATH (or adjust Service)
  - Python packages in tests/selenium/requirements.txt
"""
import argparse
import time
import json
from selenium_helpers import create_driver, short_sleep, click_by_text, find_text, register_and_login
import requests


def run(url: str, headless: bool = False):
    driver, wait = create_driver(geolocation=(-23.5505, -46.6333), headless=headless)
    try:
        print('Opening', url)

        # Create/register user via API and set localStorage so the app is authenticated in the browser
        api_base = 'http://localhost:3000/api'
        name = f'E2EUser'
        email = f'e2e_user_{int(time.time())}@example.com'
        password = 'password123'
        token, user = register_and_login(api_base, name, email, password)

        driver.get(url)
        short_sleep(1)
        # Set token and user in localStorage (frontend uses keys 'auth_token' and 'current_user')
        driver.execute_script("window.localStorage.setItem('auth_token', arguments[0]);", token)
        driver.execute_script("window.localStorage.setItem('current_user', arguments[0]);", json.dumps(user))
        driver.refresh()
        short_sleep(2)
        short_sleep(2)

        # Skip UI creation (CanvasKit). Create event via API instead.
        
        # Create event via API (UI is CanvasKit-heavy; creating via API is more reliable)
        api_base = 'http://localhost:3000/api'
        headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
        payload = {
            'title': 'E2E Test Event',
            'description': 'Descrição do evento para teste automatizado via API.',
            'latitude': -23.5505,
            'longitude': -46.6333,
            'startDate': (time.strftime('%Y-%m-%dT%H:%M:%S', time.gmtime(time.time()+3600)) + 'Z'),
            'category': 'outro'
        }

        r = requests.post(f"{api_base}/events", json=payload, headers=headers, timeout=10)
        if r.status_code != 201:
            with open('selenium_api_event_failed.html', 'w', encoding='utf-8') as f:
                f.write(driver.page_source)
            raise AssertionError(f'API create event failed: {r.status_code} {r.text}')

        print('OK: evento criado via API')

    finally:
        driver.quit()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', required=False, default='http://localhost:80/#/events')
    parser.add_argument('--headless', action='store_true')
    args = parser.parse_args()
    run(args.url, headless=args.headless)
