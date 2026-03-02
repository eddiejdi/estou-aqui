#!/usr/bin/env python3
"""
Capture screenshots of Estou Aqui web app using Chrome headless.
Routes captured:
  1. Splash (/)
  2. Login (/login)
  3. Register (/register)
  4. Events list (/events)
  5. Coalitions list (/coalitions)
  6. Profile (/profile)
  7. Event detail (/event/demo-1)
  8. Coalition detail (/coalition/demo-1)
  9. Blue check (/blue-check)
  10. Notifications (/notifications)
"""
import subprocess
import time
import os

BASE_URL = "http://localhost:8099"
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "prints")
os.makedirs(OUT_DIR, exist_ok=True)

ROUTES = [
    ("01_splash", "/"),
    ("02_login", "/login"),
    ("03_register", "/register"),
    ("04_events_list", "/events"),
    ("05_coalitions_list", "/coalitions"),
    ("06_profile", "/profile"),
    ("07_event_detail", "/event/demo-1"),
    ("08_coalition_detail", "/coalition/demo-1"),
    ("09_blue_check", "/blue-check"),
    ("10_notifications", "/notifications"),
]

# Flutter web uses hash routing by default
for name, route in ROUTES:
    url = f"{BASE_URL}/#" + route
    out_file = os.path.join(OUT_DIR, f"{name}.png")
    
    cmd = [
        "google-chrome",
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        "--disable-dev-shm-usage",
        "--force-device-scale-factor=2",
        f"--screenshot={out_file}",
        "--window-size=390,844",
        f"--virtual-time-budget=8000",
        url,
    ]
    
    print(f"Capturing {name} ({route})...")
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    
    if os.path.exists(out_file):
        size = os.path.getsize(out_file)
        print(f"  -> {out_file} ({size:,} bytes)")
    else:
        print(f"  -> FAILED: {result.stderr[-200:] if result.stderr else 'no output'}")

print(f"\nDone! Screenshots saved to {OUT_DIR}")
print(f"Total files: {len(os.listdir(OUT_DIR))}")
