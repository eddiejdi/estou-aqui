"""
E2E Test: Grafana → Backend → Agent Bus → Homelab Agent
Validates the full alert pipeline end-to-end.
"""
import os
import time
import requests
import pytest


HOMELAB = os.environ.get("HOMELAB_HOST", "192.168.15.2")
BACKEND_PORT = os.environ.get("BACKEND_PORT", "3456")
BUS_PORT = os.environ.get("BUS_PORT", "8503")


def _backend_url(path: str) -> str:
    return f"http://{HOMELAB}:{BACKEND_PORT}{path}"


def _bus_url(path: str) -> str:
    return f"http://{HOMELAB}:{BUS_PORT}{path}"


@pytest.mark.integration
def test_grafana_webhook_publishes_to_bus():
    """POST Grafana webhook → backend processes → message appears on Agent Bus."""
    unique = f"E2E_Bus_{int(time.time())}"
    payload = {
        "title": unique,
        "ruleName": unique,
        "state": "alerting",
        "message": "E2E pipeline smoke test",
        "evalMatches": [
            {
                "metric": "cpu",
                "value": 99,
                "tags": {"instance": "homelab-e2e"},
                "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            }
        ],
        "tags": {"severity": "critical"},
        "ruleUrl": "http://grafana/alert/e2e",
    }

    # 1. Send Grafana webhook to backend
    r = requests.post(
        _backend_url("/api/alerts/grafana-webhook"),
        json=payload,
        timeout=10,
    )
    r.raise_for_status()
    body = r.json()
    assert body.get("status") == "received", f"Unexpected response: {body}"
    assert body.get("processed") == 1

    # 2. Wait for the alert to appear on the Agent Bus
    deadline = time.time() + 20
    found = False
    while time.time() < deadline:
        try:
            bus_r = requests.get(_bus_url("/communication/messages"), timeout=5)
            if bus_r.status_code == 200:
                messages = bus_r.json().get("messages", [])
                for m in messages:
                    content = m.get("content", "")
                    meta = m.get("metadata", {})
                    if unique in content or meta.get("alert_name") == unique:
                        found = True
                        break
        except requests.RequestException:
            pass
        if found:
            break
        time.sleep(1)

    assert found, f"Alert '{unique}' NOT found in Agent Bus messages after 20s"


@pytest.mark.integration
def test_direct_bus_publish_alert():
    """Publish alert directly to Agent Bus and verify it lands in /communication/messages."""
    unique = f"DirectBus_{int(time.time())}"
    msg = {
        "message_type": "ALERT",
        "source": "e2e-test",
        "target": "monitoring",
        "content": f"[CRITICAL] {unique}",
        "metadata": {
            "alert_name": unique,
            "severity": "critical",
            "instance": "e2e",
            "description": "direct bus publish test",
        },
    }

    r = requests.post(_bus_url("/communication/publish"), json=msg, timeout=10)
    r.raise_for_status()
    data = r.json()
    assert data.get("success") is True, f"Publish failed: {data}"

    # Verify it shows up in /communication/messages
    deadline = time.time() + 10
    found = False
    while time.time() < deadline:
        try:
            bus_r = requests.get(_bus_url("/communication/messages"), timeout=5)
            if bus_r.status_code == 200:
                for m in bus_r.json().get("messages", []):
                    if unique in m.get("content", ""):
                        found = True
                        break
        except requests.RequestException:
            pass
        if found:
            break
        time.sleep(1)

    assert found, f"Message '{unique}' NOT found in bus after publish"


@pytest.mark.integration
def test_backend_active_alerts():
    """Backend /api/alerts/active should expose previously sent alerts."""
    r = requests.get(_backend_url("/api/alerts/active"), timeout=10)
    r.raise_for_status()
    body = r.json()
    assert "alerts" in body, f"Missing 'alerts' key: {body.keys()}"
