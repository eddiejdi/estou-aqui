#!/usr/bin/env python3
"""
Estou Aqui — Screenshots profissionais para marketing/site.

Captura telas completas (full-page) em viewport mobile (412x915)
com tempo adequado para renderização Flutter CanvasKit.

Cada screenshot é full-page (scroll completo) ou viewport preciso.
"""

import os
import sys
import time
import json
import requests
from datetime import datetime

# ─── Config ───────────────────────────────────────────────
API_BASE = os.environ.get("API_BASE", "https://estouaqui.rpa4all.com/api")
WEB_URL = os.environ.get("WEB_URL", "http://localhost:8686")
SCREENSHOTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "marketing")
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

# Mobile viewport (Pixel 7 dimensions)
VIEWPORT_W = 412
VIEWPORT_H = 915
WAIT_RENDER = 10  # seconds for Flutter CanvasKit to fully render


def create_driver():
    """Chrome headless otimizado para Flutter CanvasKit."""
    from selenium import webdriver
    from selenium.webdriver.chrome.options import Options

    options = Options()
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--headless=new")
    options.add_argument("--enable-unsafe-swiftshader")
    options.add_argument(f"--window-size={VIEWPORT_W},{VIEWPORT_H}")
    options.add_argument("--force-device-scale-factor=2")  # Retina-like 2x
    options.add_argument("--hide-scrollbars")
    options.add_argument("--disable-gpu-sandbox")
    options.add_argument("--enable-webgl")
    options.add_argument("--use-gl=swiftshader")
    options.add_experimental_option("prefs", {
        "profile.default_content_setting_values.geolocation": 1,
    })

    d = webdriver.Chrome(options=options)

    # Simular geolocalização: Av. Paulista, São Paulo
    try:
        d.execute_cdp_cmd("Emulation.setGeolocationOverride", {
            "latitude": -23.5614,
            "longitude": -46.6558,
            "accuracy": 50,
        })
    except Exception:
        pass

    return d


def warmup_canvaskit(driver):
    """Warm up CanvasKit engine by loading a page and waiting for full render."""
    print("  ⏳ Warming up CanvasKit engine...")
    driver.get(f"{WEB_URL}/#/events")
    time.sleep(15)  # CanvasKit WASM download + compile + first render
    # Verify rendering started
    try:
        canvas = driver.execute_script(
            "return document.querySelector('flt-glass-pane') !== null || "
            "document.querySelector('canvas') !== null;"
        )
        print(f"  {'✅' if canvas else '⚠️'} Flutter canvas detected: {canvas}")
    except Exception:
        pass
    print("  ✅ CanvasKit ready")


def flutter_scroll_down(driver, amount=400):
    """Scroll Flutter CanvasKit down using wheel events (ActionChains)."""
    from selenium.webdriver.common.action_chains import ActionChains
    actions = ActionChains(driver)
    actions.scroll_by_amount(0, amount)
    actions.perform()
    time.sleep(1.5)


def flutter_scroll_to_top(driver):
    """Scroll Flutter back to top."""
    driver.execute_script("window.scrollTo(0, 0)")
    from selenium.webdriver.common.action_chains import ActionChains
    actions = ActionChains(driver)
    actions.scroll_by_amount(0, -5000)
    actions.perform()
    time.sleep(1)


def full_page_screenshot(driver, filepath):
    """Captura screenshot full-page usando CDP (sem corte)."""
    try:
        # Get full page height
        total_height = driver.execute_script(
            "return Math.max(document.body.scrollHeight, "
            "document.documentElement.scrollHeight, "
            "document.body.offsetHeight, "
            "document.documentElement.offsetHeight, "
            "document.body.clientHeight, "
            "document.documentElement.clientHeight);"
        )
        viewport_width = driver.execute_script("return window.innerWidth;")

        # Use CDP for full page screenshot (no clipping)
        result = driver.execute_cdp_cmd("Page.captureScreenshot", {
            "format": "png",
            "captureBeyondViewport": True,
            "clip": {
                "x": 0,
                "y": 0,
                "width": viewport_width,
                "height": total_height,
                "scale": 1,
            },
        })

        import base64
        with open(filepath, "wb") as f:
            f.write(base64.b64decode(result["data"]))

        size_kb = os.path.getsize(filepath) / 1024
        print(f"  📸 {os.path.basename(filepath)} ({size_kb:.0f} KB, {viewport_width}x{total_height})")
        return True
    except Exception as e:
        print(f"  ⚠️  Full-page falhou ({e}), usando save_screenshot")
        driver.save_screenshot(filepath)
        return True


def viewport_screenshot(driver, filepath):
    """Captura apenas o viewport atual (sem scroll)."""
    driver.save_screenshot(filepath)
    size_kb = os.path.getsize(filepath) / 1024
    print(f"  📸 {os.path.basename(filepath)} ({size_kb:.0f} KB, viewport)")


def api_call(method, path, token=None, json_data=None):
    """Helper para chamadas à API."""
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    url = f"{API_BASE}{path}"
    r = getattr(requests, method)(url, headers=headers, json=json_data, timeout=15)
    return r


def wait_for_flutter(driver, seconds=WAIT_RENDER):
    """Aguarda Flutter renderizar completamente."""
    time.sleep(seconds)
    # Tentar esperar JS ficar idle
    try:
        driver.execute_script("""
            return new Promise(resolve => {
                if (document.querySelector('flt-glass-pane')) {
                    resolve(true);
                } else {
                    setTimeout(() => resolve(true), 2000);
                }
            });
        """)
    except Exception:
        pass
    time.sleep(1)


def get_test_events():
    """Busca eventos existentes da API."""
    r = api_call("get", "/events")
    if r.status_code == 200:
        data = r.json()
        events = data.get("events", [])
        return events
    return []


def ensure_test_data():
    """Garante que existem dados de teste suficientes."""
    events = get_test_events()

    # Encontrar eventos por tipo
    result = {
        "manifestacao": None,
        "passeata": None,
        "protesto": None,
        "all_events": events,
    }

    for e in events:
        cat = e.get("category", "")
        if cat in ("manifestacao", "manifestação") and not result["manifestacao"]:
            result["manifestacao"] = e
        elif cat == "marcha" and not result["passeata"]:
            result["passeata"] = e
        elif cat == "protesto" and not result["protesto"]:
            result["protesto"] = e

    return result


def main():
    print("=" * 60)
    print("📸 ESTOU AQUI — Screenshots Profissionais para Marketing")
    print("=" * 60)
    print(f"  Web: {WEB_URL}")
    print(f"  API: {API_BASE}")
    print(f"  Viewport: {VIEWPORT_W}x{VIEWPORT_H} @2x")
    print(f"  Saída: {SCREENSHOTS_DIR}")
    print()

    # ─── Preparar dados ───────────────────────────────────
    print("🔍 Buscando dados de teste...")
    data = ensure_test_data()
    print(f"  Total de eventos: {len(data['all_events'])}")
    for key in ["manifestacao", "passeata", "protesto"]:
        e = data.get(key)
        if e:
            print(f"  {key}: {e['title'][:50]}... (ID: {e['id'][:8]})")
    print()

    # ─── Criar driver ─────────────────────────────────────
    print("🌐 Iniciando Chrome headless...")

    # ═══════════════════════════════════════════════════
    # 1. TELA INICIAL (Splash Screen) — cold start necessário
    # CanvasKit precisa carregar do zero para renderizar splash
    # antes do auto-redirect (2s)
    # ═══════════════════════════════════════════════════
    print("\n━━━ 1. Tela Inicial (Splash) ━━━")
    splash_driver = create_driver()
    try:
        splash_driver.get(WEB_URL)
        time.sleep(3.5)  # CanvasKit load + splash render, antes do redirect
        viewport_screenshot(splash_driver, os.path.join(SCREENSHOTS_DIR, "01_splash_screen.png"))
    finally:
        splash_driver.quit()

    # ─── Driver principal com warm-up ──────────────────
    driver = create_driver()

    try:
        # ─── WARM-UP: carregar CanvasKit engine ───
        warmup_canvaskit(driver)

        # ═══════════════════════════════════════════════════
        # 2. TELA DE LOGIN
        # ═══════════════════════════════════════════════════
        print("\n━━━ 2. Tela de Login ━━━")
        driver.get(f"{WEB_URL}/#/login")
        wait_for_flutter(driver, 6)
        viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "02_login_screen.png"))

        # ═══════════════════════════════════════════════════
        # 3. TELA DE REGISTRO
        # ═══════════════════════════════════════════════════
        print("\n━━━ 3. Tela de Registro ━━━")
        driver.get(f"{WEB_URL}/#/register")
        wait_for_flutter(driver, 6)
        viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "03_register_screen.png"))

        # ═══════════════════════════════════════════════════
        # 4. MAPA PRINCIPAL (com marcadores de eventos)
        # ═══════════════════════════════════════════════════
        print("\n━━━ 4. Mapa Principal ━━━")
        driver.get(f"{WEB_URL}/#/map")
        wait_for_flutter(driver, 12)  # Mapa precisa mais tempo para tiles
        viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "04_mapa_principal.png"))

        # ═══════════════════════════════════════════════════
        # 5. LISTA DE EVENTOS
        # ═══════════════════════════════════════════════════
        print("\n━━━ 5. Lista de Eventos ━━━")
        driver.get(f"{WEB_URL}/#/events")
        wait_for_flutter(driver, 8)
        viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "05a_lista_eventos_topo.png"))
        # Scroll para ver mais eventos
        flutter_scroll_down(driver, 500)
        viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "05b_lista_eventos_scroll.png"))

        # ═══════════════════════════════════════════════════
        # 6. DETALHE: MANIFESTAÇÃO (com CrowdGauge)
        # ═══════════════════════════════════════════════════
        print("\n━━━ 6. Detalhe: Manifestação ━━━")
        evt = data.get("manifestacao")
        if evt:
            driver.get(f"{WEB_URL}/#/event/{evt['id']}")
            wait_for_flutter(driver, 8)
            # Viewport: hero/header com gradiente + emoji
            viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "06a_manifestacao_hero.png"))
            # Scroll para mostrar CrowdGauge (estimativa de público)
            flutter_scroll_down(driver, 350)
            viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "06b_manifestacao_info.png"))
            # Scroll mais para CrowdGauge
            flutter_scroll_down(driver, 400)
            viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "06c_manifestacao_crowd_gauge.png"))
            # Scroll até botões de ação
            flutter_scroll_down(driver, 400)
            viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "06d_manifestacao_acoes.png"))
        else:
            print("  ⚠️  Nenhuma manifestação encontrada")

        # ═══════════════════════════════════════════════════
        # 7. DETALHE: PASSEATA/MARCHA (com percurso)
        # ═══════════════════════════════════════════════════
        print("\n━━━ 7. Detalhe: Passeata com Percurso ━━━")
        evt = data.get("passeata")
        if evt:
            driver.get(f"{WEB_URL}/#/event/{evt['id']}")
            wait_for_flutter(driver, 8)
            # Hero
            viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "07a_passeata_hero.png"))
            # Info + percurso
            flutter_scroll_down(driver, 350)
            viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "07b_passeata_info.png"))
            # Crowd gauge
            flutter_scroll_down(driver, 400)
            viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "07c_passeata_crowd_gauge.png"))
            # Ações
            flutter_scroll_down(driver, 400)
            viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "07d_passeata_acoes.png"))
        else:
            print("  ⚠️  Nenhuma passeata encontrada")

        # ═══════════════════════════════════════════════════
        # 8. DETALHE: PROTESTO (Rio de Janeiro)
        # ═══════════════════════════════════════════════════
        print("\n━━━ 8. Detalhe: Protesto RJ ━━━")
        evt = data.get("protesto")
        if evt:
            driver.get(f"{WEB_URL}/#/event/{evt['id']}")
            wait_for_flutter(driver, 8)
            viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "08a_protesto_rj_hero.png"))
            flutter_scroll_down(driver, 350)
            viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "08b_protesto_rj_info.png"))
            flutter_scroll_down(driver, 400)
            viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "08c_protesto_rj_crowd_gauge.png"))
        else:
            print("  ⚠️  Nenhum protesto encontrado")

        # ═══════════════════════════════════════════════════
        # 9. FORMULÁRIO DE CRIAÇÃO DE EVENTO
        # ═══════════════════════════════════════════════════
        print("\n━━━ 9. Criar Evento ━━━")
        driver.get(f"{WEB_URL}/#/event/create")
        wait_for_flutter(driver, 6)
        # Topo do formulário
        viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "09a_criar_evento_topo.png"))
        # Scroll meio
        flutter_scroll_down(driver, 500)
        viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "09b_criar_evento_meio.png"))
        # Scroll final
        flutter_scroll_down(driver, 500)
        viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "09c_criar_evento_final.png"))

        # ═══════════════════════════════════════════════════
        # 10. TELA DE NOTIFICAÇÕES
        # ═══════════════════════════════════════════════════
        print("\n━━━ 10. Notificações ━━━")
        driver.get(f"{WEB_URL}/#/notifications")
        wait_for_flutter(driver, 6)
        viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "10_notificacoes.png"))

        # ═══════════════════════════════════════════════════
        # 11. TELA DE PERFIL
        # ═══════════════════════════════════════════════════
        print("\n━━━ 11. Perfil ━━━")
        driver.get(f"{WEB_URL}/#/profile")
        wait_for_flutter(driver, 6)
        viewport_screenshot(driver, os.path.join(SCREENSHOTS_DIR, "11_perfil.png"))

        # ═══════════════════════════════════════════════════
        # QUALITY CHECK
        # ═══════════════════════════════════════════════════
        print("\n━━━ Verificação de qualidade ━━━")
        check_screenshot_quality()

        # ═══════════════════════════════════════════════════
        # GERAR GIFs
        # ═══════════════════════════════════════════════════
        print("\n━━━ Gerando GIFs ━━━")
        generate_gifs()

    finally:
        driver.quit()

    # ─── Relatório final ──────────────────────────────────
    print_report()


def check_screenshot_quality():
    """Verifica qualidade dos screenshots (diversidade de cores em múltiplas regiões)."""
    import glob
    try:
        from PIL import Image
        import numpy as np
    except ImportError:
        print("  ⚠️  PIL/numpy não disponível, skip quality check")
        return

    pngs = sorted(glob.glob(os.path.join(SCREENSHOTS_DIR, "*.png")))
    issues = []
    for png in pngs:
        img = Image.open(png)
        arr = np.array(img)
        h, w = arr.shape[:2]
        # Sample multiple vertical regions (top 1/4, center, bottom 1/4)
        max_unique = 0
        for y_frac in [0.2, 0.4, 0.5, 0.6, 0.8]:
            cy = int(h * y_frac)
            cx = w // 2
            size = min(50, h // 8, w // 8)
            region = arr[max(0, cy - size):cy + size, max(0, cx - size):cx + size]
            unique = len(set(map(tuple, region.reshape(-1, 3))))
            max_unique = max(max_unique, unique)

        status = "✅" if max_unique > 20 else ("⚠️" if max_unique > 3 else "❌")
        basename = os.path.basename(png)
        kb = os.path.getsize(png) // 1024
        print(f"  {status} {basename:45s} {kb:>5}KB  max_colors={max_unique}")
        if max_unique <= 3:
            issues.append(basename)

    if issues:
        print(f"\n  ⚠️  {len(issues)} screenshot(s) possivelmente em branco: {', '.join(issues)}")
    else:
        print(f"\n  ✅ Todos os screenshots têm conteúdo visual adequado!")


def generate_gifs():
    """Gera GIFs animados por cenário."""
    try:
        import imageio.v3 as iio
    except ImportError:
        try:
            import imageio as iio
        except ImportError:
            print("  ⚠️  imageio não disponível, GIFs não gerados")
            return

    import glob

    gif_groups = {
        "manifestacao": ["06a_", "06b_", "06c_", "06d_"],
        "passeata": ["07a_", "07b_", "07c_", "07d_"],
        "protesto_rj": ["08a_", "08b_", "08c_"],
        "criar_evento": ["09a_", "09b_", "09c_"],
        "fluxo_completo": ["01_", "02_", "04_", "05a_", "06a_", "07a_", "08a_", "09a_", "10_", "11_"],
    }

    all_pngs = sorted(glob.glob(os.path.join(SCREENSHOTS_DIR, "*.png")))

    for gif_name, prefixes in gif_groups.items():
        frames = []
        for png in all_pngs:
            basename = os.path.basename(png)
            if any(basename.startswith(p) for p in prefixes):
                try:
                    img = iio.imread(png)
                    frames.append(img)
                except Exception:
                    pass

        if len(frames) >= 2:
            gif_path = os.path.join(SCREENSHOTS_DIR, f"gif_{gif_name}.gif")
            try:
                # Resize all frames to same dimensions (use first frame as reference)
                ref_shape = frames[0].shape
                resized = []
                for f in frames:
                    if f.shape != ref_shape:
                        # Crop or pad to match
                        from PIL import Image
                        import numpy as np
                        img = Image.fromarray(f)
                        img = img.resize((ref_shape[1], ref_shape[0]), Image.LANCZOS)
                        resized.append(np.array(img))
                    else:
                        resized.append(f)

                iio.imwrite(gif_path, resized, duration=2000, loop=0)
                size_kb = os.path.getsize(gif_path) / 1024
                print(f"  🎬 {os.path.basename(gif_path)} ({len(resized)} frames, {size_kb:.0f} KB)")
            except Exception as e:
                print(f"  ⚠️  GIF {gif_name} falhou: {e}")

    # GIF master com todas as viewport screenshots
    viewport_pngs = [p for p in all_pngs if "viewport" in os.path.basename(p)
                     or not any(x in os.path.basename(p) for x in ["completo", "full"])]
    # Filter to only viewport-sized images (not full-page)
    master_frames = []
    for png in sorted(all_pngs):
        basename = os.path.basename(png)
        # Skip full-page screenshots (they have different dimensions)
        if "completo" in basename:
            continue
        try:
            img = iio.imread(png)
            master_frames.append(img)
        except Exception:
            pass

    if len(master_frames) >= 3:
        # Resize all to same dimensions
        ref_shape = master_frames[0].shape
        resized_master = []
        for f in master_frames[:25]:
            if f.shape == ref_shape:
                resized_master.append(f)
            else:
                try:
                    from PIL import Image
                    import numpy as np
                    img = Image.fromarray(f)
                    img = img.resize((ref_shape[1], ref_shape[0]), Image.LANCZOS)
                    resized_master.append(np.array(img))
                except Exception:
                    pass

        if resized_master:
            gif_path = os.path.join(SCREENSHOTS_DIR, "gif_TOUR_COMPLETO.gif")
            try:
                iio.imwrite(gif_path, resized_master, duration=1500, loop=0)
                size_kb = os.path.getsize(gif_path) / 1024
                print(f"  🎬 {os.path.basename(gif_path)} ({len(resized_master)} frames, {size_kb:.0f} KB)")
            except Exception as e:
                print(f"  ⚠️  GIF master falhou: {e}")


def print_report():
    """Relatório final com inventário."""
    import glob

    pngs = sorted(glob.glob(os.path.join(SCREENSHOTS_DIR, "*.png")))
    gifs = sorted(glob.glob(os.path.join(SCREENSHOTS_DIR, "*.gif")))

    print(f"\n{'═' * 60}")
    print(f"📊 RELATÓRIO — Screenshots para Marketing")
    print(f"{'═' * 60}")

    total_png_size = sum(os.path.getsize(f) for f in pngs)
    total_gif_size = sum(os.path.getsize(f) for f in gifs)

    print(f"\n📸 Screenshots: {len(pngs)} ({total_png_size / 1024 / 1024:.1f} MB)")
    for f in pngs:
        size_kb = os.path.getsize(f) / 1024
        print(f"   • {os.path.basename(f):50s} {size_kb:>6.0f} KB")

    print(f"\n🎬 GIFs: {len(gifs)} ({total_gif_size / 1024 / 1024:.1f} MB)")
    for f in gifs:
        size_kb = os.path.getsize(f) / 1024
        print(f"   • {os.path.basename(f):50s} {size_kb:>6.0f} KB")

    print(f"\n📁 Diretório: {SCREENSHOTS_DIR}")
    print(f"{'═' * 60}")


if __name__ == "__main__":
    main()
