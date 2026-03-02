import sys
import os

# Add current directory to path so local imports work
sys.path.insert(0, os.path.dirname(__file__))

# Setup ChromeDriver via webdriver-manager
try:
    from webdriver_manager.chrome import ChromeDriverManager
    from selenium.webdriver.chrome.service import Service
    os.environ.setdefault("CHROMEDRIVER_PATH", ChromeDriverManager().install())
except Exception:
    pass
