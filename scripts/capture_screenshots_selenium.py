#!/usr/bin/env python3
"""
Capture screenshots of Estou Aqui Flutter web app using Selenium.
Waits for Flutter to finish loading before capturing.
"""
import os
import sys
import time

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager

BASE_URL = "http://localhost:8099"
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "prints")
os.makedirs(OUT_DIR, exist_ok=True)

# Flutter web uses hash-based routing
ROUTES = [
    ("01_splash",           "/"),
    ("02_login",            "/login"),
    ("03_register",         "/register"),
    ("04_events_list",      "/events"),
    ("05_coalitions_list",  "/coalitions"),
    ("06_profile",          "/profile"),
    ("07_event_detail",     "/event/demo-1"),
    ("08_coalition_detail", "/coalition/demo-1"),
    ("09_blue_check",       "/blue-check"),
    ("10_notifications",    "/notifications"),
]


def create_driver():
    opts = Options()
    opts.add_argument("--headless=new")
    opts.add_argument("--no-sandbox")
    opts.add_argument("--disable-dev-shm-usage")
    opts.add_argument("--disable-gpu")
    opts.add_argument("--window-size=390,844")
    opts.add_argument("--force-device-scale-factor=2")
    opts.add_argument("--hide-scrollbars")

    service = Service(ChromeDriverManager().install())
    return webdriver.Chrome(service=service, options=opts)


def wait_for_flutter(driver, timeout=20):
    """Wait until Flutter finishes rendering (flt-glass-pane or canvas present)."""
    try:
        WebDriverWait(driver, timeout).until(
            lambda d: d.execute_script(
                "return document.querySelector('flt-glass-pane') !== null "
                "|| document.querySelector('flutter-view') !== null "
                "|| document.querySelector('canvas') !== null"
            )
        )
        # Extra wait for rendering to complete
        time.sleep(3)
    except Exception:
        print("  [warn] Flutter load timeout, capturing anyway")
        time.sleep(2)


def main():
    print("Starting Chrome WebDriver...")
    driver = create_driver()

    try:
        # First load — let Flutter initialize fully
        print("Loading Flutter app (initial)...")
        driver.get(f"{BASE_URL}/#/login")
        wait_for_flutter(driver, timeout=30)
        # Extra time for first load
        time.sleep(5)

        for name, route in ROUTES:
            url = f"{BASE_URL}/#{route}"
            out_file = os.path.join(OUT_DIR, f"{name}.png")

            print(f"Capturing {name} ({route})...")
            driver.get(url)
            time.sleep(4)  # Wait for route transition + render

            driver.save_screenshot(out_file)

            size = os.path.getsize(out_file)
            print(f"  -> {out_file} ({size:,} bytes)")

    finally:
        driver.quit()

    print(f"\nDone! {len(os.listdir(OUT_DIR))} screenshots in {OUT_DIR}")


if __name__ == "__main__":
    main()
