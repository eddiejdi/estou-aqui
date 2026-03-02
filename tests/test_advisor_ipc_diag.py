import importlib
import os
import pytest

fastapi = pytest.importorskip("fastapi")
from fastapi.testclient import TestClient


def test_health_includes_ipc_diag_when_database_unreachable(monkeypatch):
    # Set an intentionally unreachable DATABASE_URL to trigger diagnostics
    monkeypatch.setenv("DATABASE_URL", "postgresql://postgres:wrongpass@10.255.255.1:5432/postgres")

    # Reload the advisor module so the singleton picks up the env var
    import advisor_agent_patch as advisor_module
    importlib.reload(advisor_module)

    client = TestClient(advisor_module.app)
    resp = client.get("/health")
    assert resp.status_code == 200
    body = resp.json()

    assert body["ipc_available"] is False
    assert "ipc_diag" in body
    diag = body["ipc_diag"]
    # The original host from DATABASE_URL should be present in candidates
    assert "10.255.255.1" in diag.get("candidates", {})
    # There should be an 'error' explaining the failure
    assert "error" in diag and diag["error"] is not None
