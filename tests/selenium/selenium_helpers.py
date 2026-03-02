from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
import requests
import json


def create_driver(geolocation=None, headless=False, enable_performance=False):
    """Create a Chrome WebDriver.

    - enable_performance: when True, enables DevTools "performance" logging (useful to capture XHR/fetch events).
    """
    options = webdriver.ChromeOptions()
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    if headless:
        options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_experimental_option("prefs", {"profile.default_content_setting_values.geolocation": 1})

    if enable_performance:
        # enable performance logging (Chrome DevTools Protocol)
        options.set_capability("goog:loggingPrefs", {"performance": "ALL"})

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


def wait_for_human_challenge(driver, timeout=300, poll_interval=2):
    """Detecta um desafio anti-bot (reCAPTCHA / hCaptcha / mensagens de verificação) e pausa
    até que o usuário resolva manualmente ou até expirar o timeout.

    Retorna True se nenhum desafio detectado ou se resolvido dentro do timeout; False se expirou.
    """
    import time as _time
    from selenium.common.exceptions import WebDriverException

    def _challenge_present():
        try:
            # iframes usados por reCAPTCHA / hCaptcha
            if driver.find_elements(By.CSS_SELECTOR, "iframe[src*='recaptcha']"):
                return True
            if driver.find_elements(By.CSS_SELECTOR, "iframe[src*='hcaptcha']"):
                return True
            # common container classes / ids
            if driver.find_elements(By.CSS_SELECTOR, ".g-recaptcha, .h-captcha, [id*='captcha'], [class*='captcha']"):
                return True
            # textual indicators
            src = (driver.page_source or '').lower()
            for token in ['prove you are not a robot', 'recaptcha', 'confirme que você não é um robô', 'verificação de segurança', 'captcha', 'please verify']:
                if token in src:
                    return True
        except WebDriverException:
            return False
        return False

    # quick check
    if not _challenge_present():
        return True

    # challenge present — save evidence and wait for manual solve
    try:
        driver.save_screenshot('/tmp/selenium_captcha_detected.png')
    except Exception:
        pass
    start = _time.time()
    print('\n⚠️ Anti-bot detected (reCAPTCHA/hCaptcha). Pausing for manual resolution.')
    print("-> screenshot saved to /tmp/selenium_captcha_detected.png — please solve the challenge in the browser window.")

    while _time.time() - start < timeout:
        _time.sleep(poll_interval)
        try:
            if not _challenge_present():
                print('✅ Challenge cleared — resuming automation')
                try:
                    driver.save_screenshot('/tmp/selenium_captcha_solved.png')
                except Exception:
                    pass
                return True
        except Exception:
            pass
    print('⛔ Timeout waiting for human to solve captcha')
    return False


# ------------------ Image / OCR helpers ------------------
from io import BytesIO
try:
    from PIL import Image
except Exception:
    Image = None

try:
    import numpy as _np
    import cv2 as _cv2
except Exception:
    _np = None
    _cv2 = None

try:
    import pytesseract as _pytesseract
    from pytesseract import Output as _PT_OUTPUT
except Exception:
    _pytesseract = None
    _PT_OUTPUT = None


def _get_page_screenshot_pil(driver):
    """Return PIL.Image of the current viewport screenshot."""
    if Image is None:
        raise RuntimeError('PIL not available')
    png = driver.get_screenshot_as_png()
    return Image.open(BytesIO(png)).convert('RGB')


def find_text_via_ocr(driver, text, lang='por'):
    """Locate visible occurrences of `text` (case-insensitive) using OCR on a page screenshot.
    Returns list of bounding boxes (x, y, w, h) in viewport coordinates.
    Requires tesseract + pytesseract available; otherwise returns [].
    """
    if _pytesseract is None or Image is None:
        return []
    img = _get_page_screenshot_pil(driver)
    try:
        data = _pytesseract.image_to_data(img, output_type=_PT_OUTPUT, lang=lang)
    except Exception:
        # fallback to default language if specific lang not available
        try:
            data = _pytesseract.image_to_data(img, output_type=_PT_OUTPUT)
        except Exception:
            return []
    boxes = []
    for i, word in enumerate(data.get('text', [])):
        try:
            if not word:
                continue
            if text.lower() in word.lower():
                x, y, w, h = int(data['left'][i]), int(data['top'][i]), int(data['width'][i]), int(data['height'][i])
                boxes.append((x, y, w, h))
        except Exception:
            continue
    return boxes


def click_text_via_ocr(driver, text, lang='por'):
    """Find the `text` visually and click its center. Returns True if clicked."""
    boxes = find_text_via_ocr(driver, text, lang=lang)
    if not boxes:
        return False
    x, y, w, h = boxes[0]
    cx, cy = x + w // 2, y + h // 2
    # click via elementFromPoint (viewport coords)
    driver.execute_script('window.scrollTo(0,0);')
    try:
        driver.execute_script('var el = document.elementFromPoint(arguments[0], arguments[1]); if(el){ el.click(); }', int(cx), int(cy))
        return True
    except Exception:
        return False


def find_template_on_screenshot(driver, template_path, threshold=0.78):
    """Template-match `template_path` in the current viewport screenshot.
    Returns (cx, cy, score) or None. Requires OpenCV (cv2).
    """
    if _cv2 is None or _np is None or Image is None:
        return None
    try:
        tpl = _cv2.imread(template_path, _cv2.IMREAD_UNCHANGED)
        if tpl is None:
            return None
        # screenshot -> numpy BGR
        pil = _get_page_screenshot_pil(driver)
        arr = _np.array(pil)[:, :, ::-1].copy()
        res = _cv2.matchTemplate(arr, tpl, _cv2.TM_CCOEFF_NORMED)
        min_val, max_val, min_loc, max_loc = _cv2.minMaxLoc(res)
        if max_val >= threshold:
            th, tw = tpl.shape[:2]
            top_left = max_loc
            cx = int(top_left[0] + tw / 2)
            cy = int(top_left[1] + th / 2)
            return (cx, cy, float(max_val))
        return None
    except Exception:
        return None


def click_template(driver, template_path, threshold=0.78):
    m = find_template_on_screenshot(driver, template_path, threshold=threshold)
    if not m:
        return False
    cx, cy, _ = m
    try:
        driver.execute_script('window.scrollTo(0,0);');
        driver.execute_script('var el=document.elementFromPoint(arguments[0], arguments[1]); if(el) el.click();', int(cx), int(cy))
        return True
    except Exception:
        return False


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
