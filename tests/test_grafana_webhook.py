import os
import time
import requests
import pytest


@pytest.mark.integration
def test_grafana_webhook_to_estou_aqui():
    """E2E smoke: postar payload no endpoint Grafana-webhook do backend e validar processamento."""
    homelab = os.environ.get("HOMELAB_HOST", "127.0.0.1")

    payload = {
        "title": "Smoke test - Grafana webhook",
        "ruleName": "SmokeGrafanaWebhookCI",
        "state": "alerting",
        "message": "CI smoke test payload",
        "evalMatches": [
            {
                "metric": "memory_total",
                "value": 99,
                "tags": {"instance": "homelab-ci"},
                "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            }
        ],
        "tags": {"severity": "critical"},
        "ruleUrl": "http://grafana/alert/ci-smoke"
    }

    url = f"http://{homelab}:3456/api/alerts/grafana-webhook"
    r = requests.post(url, json=payload, timeout=5)
    r.raise_for_status()

    # Aguarda até que o backend exponha o alerta em /api/alerts/active
    deadline = time.time() + 20
    active_url_candidates = [f"http://{homelab}:3456/api/alerts/active", f"http://{homelab}:3000/api/alerts/active"]

    while time.time() < deadline:
        for au in active_url_candidates:
            try:
                res = requests.get(au, timeout=5)
            except requests.RequestException:
                continue

            if 'application/json' not in res.headers.get('Content-Type', ''):
                continue

            body = res.json()
            names = [a.get('name') for a in body.get('alerts', [])]
            if 'SmokeGrafanaWebhookCI' in names:
                return
        time.sleep(1)

    pytest.fail('Grafana webhook smoke failed: alert not found in /api/alerts/active')
