#!/usr/bin/env python3
"""Regression test — ensure no Storage / JS null-check runtime errors
are emitted in browser console on startup (prevents WebView gray screen).
"""
import time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options


def test_no_localstorage_null_errors():
    options = Options()
    options.set_capability("goog:loggingPrefs", {"browser": "ALL"})
    driver = webdriver.Chrome(options=options)
    try:
        driver.get('http://localhost:8081/')
        time.sleep(2)
        logs = driver.get_log('browser')
        messages = '\n'.join([l['message'] for l in logs])
        assert 'Null check operator used on a null value' not in messages
        assert 'Uncaught SyntaxError' not in messages
    finally:
        driver.quit()
