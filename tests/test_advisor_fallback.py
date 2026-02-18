import os
import time
import requests
import pytest

HOMELAB = os.environ.get("HOMELAB_HOST", "192.168.15.2")
BUS_PORT = os.environ.get("BUS_PORT", "8503")


def _bus_url(path: str) -> str:
    return f"http://{HOMELAB}:{BUS_PORT}{path}"


@pytest.mark.integration
def test_advisor_fallback_publishes_when_ipc_offline():
    """Quando o IPC está offline o `homelab-advisor` deve responder via bus (fallback)."""
    unique = f"AdvisorFallback_{int(time.time())}"
    msg = {
        "message_type": "request",
        "source": "e2e-test-fallback",
        "target": "homelab-advisor",
        "content": f"Teste fallback: {unique}",
        "metadata": {"test": "advisor-fallback"},
    }

    r = requests.post(_bus_url("/communication/publish"), json=msg, timeout=10)
    r.raise_for_status()

    deadline = time.time() + 15
    found = False
    while time.time() < deadline:
        try:
            bus_r = requests.get(_bus_url("/communication/messages"), timeout=5)
            if bus_r.status_code == 200:
                for m in bus_r.json().get("messages", []):
                    if m.get("source") == "homelab-advisor" and unique in m.get("content", ""):
                        found = True
                        break
        except requests.RequestException:
            pass
        if found:
            break
        time.sleep(1)

    assert found, "Advisor não publicou fallback no bus quando IPC offline" 
