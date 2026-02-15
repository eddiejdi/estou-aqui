#!/usr/bin/env python3
from selenium_helpers import create_driver, short_sleep, click_by_text, find_text


def run(url: str, headless: bool = False):
    driver, wait = create_driver(geolocation=(-23.5505, -46.6333), headless=headless)
    try:
        driver.get(url)
        short_sleep(2)

        # Open first event if any
        el = find_text(driver, 'Eventos Próximos')
        short_sleep(1)
        # Attempt to click first 'Entrar' or check-in button if present
        try:
            btn = wait.until(lambda d: d.find_element('xpath', "//button[contains(., 'Check-in') or contains(., 'Entrar') or contains(., 'Confirmar')]"))
            btn.click()
            short_sleep(1)
            # check for success or presence of checkout
            if find_text(driver, 'Check-out') or find_text(driver, 'Você está dentro'):
                print('Checkin OK')
            else:
                print('Checkin attempted; UI may differ')
        except Exception:
            print('Nenhum botão de check-in encontrado — pulei')

    finally:
        driver.quit()


if __name__ == '__main__':
    run('http://localhost:34951/#/events', headless=False)
