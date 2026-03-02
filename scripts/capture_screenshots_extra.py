#!/usr/bin/env python3
"""
Capture additional screenshots of Estou Aqui app:
- Individual addon screens (scrolling)
- Desktop viewport for comparison
"""
import os
import time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager

BASE_URL = "http://localhost:8099"
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "prints")
os.makedirs(OUT_DIR, exist_ok=True)


def create_driver(width=390, height=844):
    opts = Options()
    opts.add_argument("--headless=new")
    opts.add_argument("--no-sandbox")
    opts.add_argument("--disable-dev-shm-usage")
    opts.add_argument("--disable-gpu")
    opts.add_argument(f"--window-size={width},{height}")
    opts.add_argument("--force-device-scale-factor=2")
    opts.add_argument("--hide-scrollbars")
    service = Service(ChromeDriverManager().install())
    return webdriver.Chrome(service=service, options=opts)


def capture(driver, name, route, wait=5):
    url = f"{BASE_URL}/#{route}"
    out_file = os.path.join(OUT_DIR, f"{name}.png")
    print(f"Capturing {name} ({route})...")
    driver.get(url)
    time.sleep(wait)
    driver.save_screenshot(out_file)
    size = os.path.getsize(out_file)
    print(f"  -> {size:,} bytes")
    return size


def main():
    # Mobile screenshots - longer waits
    print("=== Mobile viewport (390x844) ===")
    driver = create_driver(390, 844)
    try:
        # Init load
        driver.get(f"{BASE_URL}/#/login")
        time.sleep(8)

        # Core screens with longer waits
        capture(driver, "11_login_full", "/login", wait=6)
        capture(driver, "12_events_full", "/events", wait=6)
        capture(driver, "13_coalitions_full", "/coalitions", wait=6)
        capture(driver, "14_profile_full", "/profile", wait=6)
        capture(driver, "15_blue_check_full", "/blue-check", wait=6)
        capture(driver, "16_notifications_full", "/notifications", wait=6)

        # Scroll events list page
        driver.get(f"{BASE_URL}/#/events")
        time.sleep(6)
        driver.execute_script("window.scrollTo(0, 500)")
        time.sleep(2)
        out_file = os.path.join(OUT_DIR, "17_events_scrolled.png")
        driver.save_screenshot(out_file)
        print(f"17_events_scrolled -> {os.path.getsize(out_file):,} bytes")

    finally:
        driver.quit()

    # Desktop screenshots
    print("\n=== Desktop viewport (1280x800) ===")
    driver = create_driver(1280, 800)
    try:
        driver.get(f"{BASE_URL}/#/login")
        time.sleep(8)

        capture(driver, "18_desktop_login", "/login", wait=6)
        capture(driver, "19_desktop_events", "/events", wait=6)
        capture(driver, "20_desktop_coalitions", "/coalitions", wait=6)
        capture(driver, "21_desktop_profile", "/profile", wait=6)
        capture(driver, "22_desktop_blue_check", "/blue-check", wait=6)

    finally:
        driver.quit()

    total = len([f for f in os.listdir(OUT_DIR) if f.endswith('.png')])
    print(f"\nDone! {total} total screenshots in {OUT_DIR}")


if __name__ == "__main__":
    main()
