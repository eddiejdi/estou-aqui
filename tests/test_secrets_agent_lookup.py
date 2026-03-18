import importlib
import sys


def _fake_secrets_response():
    return [
        {
            "name": "homelab-copilot-agent",
            "data": {"DATABASE_URL": "postgresql://postgres:secret@eddie-postgres:5432/postgres"}
        }
    ]


def test_secrets_agent_populates_database_url(monkeypatch):
    # ensure DATABASE_URL is not set via env
    monkeypatch.delenv("DATABASE_URL", raising=False)

    # set SECRETS_AGENT envs so the advisor will try to fetch
    monkeypatch.setenv("SECRETS_AGENT_URL", "http://localhost:8088")
    monkeypatch.setenv("SECRETS_AGENT_API_KEY", "dummy-key")

    # Monkeypatch httpx.Client.get to return a fake response
    class DummyResp:
        def __init__(self, payload):
            self._payload = payload

        def raise_for_status(self):
            return None

        def json(self):
            return self._payload

    def fake_get(self, url, *args, **kwargs):
        return DummyResp(_fake_secrets_response())

    monkeypatch.setattr("httpx.Client.get", fake_get, raising=False)

    # Import em módulo limpo para evitar métricas Prometheus duplicadas no registry global.
    sys.modules.pop("advisor_agent_patch", None)
    advisor_module = importlib.import_module("advisor_agent_patch")
    adv = advisor_module.advisor

    assert adv.database_url is not None
    assert "secret@eddie-postgres" in adv.database_url
