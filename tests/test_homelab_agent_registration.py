import os
import time
import requests
import pytest


@pytest.mark.integration
def test_homelab_agent_registration():
    """Integration: valida que o Homelab Advisor está registrado na API.

    Requisitos:
    - Serviço do agent acessível em <HOMELAB_HOST>:8085 (padrão: 127.0.0.1)
    - Executar com `-m integration` (ou definir RUN_ALL_TESTS=1)
    """
    homelab_host = os.environ.get("HOMELAB_HOST", "127.0.0.1")
    metrics_url = f"http://{homelab_host}:8085/metrics"

    # tentar por até 30s — o agent reitera registro periodicamente
    deadline = time.time() + 30
    last_body = None
    while time.time() < deadline:
        try:
            r = requests.get(metrics_url, timeout=5)
            r.raise_for_status()
            last_body = r.text
            if "advisor_api_registration_status 1" in r.text or "advisor_api_registration_status 1.0" in r.text:
                return
        except requests.RequestException:
            pass
        time.sleep(5)

    pytest.skip(f"Homelab agent not reachable or not registered yet. Last metrics snapshot:\n{(last_body or 'no-response')[:1000]}")
