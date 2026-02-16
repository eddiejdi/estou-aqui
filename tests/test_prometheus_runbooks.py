import os
import time
import requests
import pytest


@pytest.mark.integration
def test_prometheus_rules_include_runbook_urls():
    """Verifica que as regras do grupo `homelab-advisor.rules` contenham `runbook_url` nas anotações."""
    homelab = os.environ.get("HOMELAB_HOST", "127.0.0.1")
    url = f"http://{homelab}:9090/api/v1/rules"

    r = requests.get(url, timeout=5)
    r.raise_for_status()
    data = r.json().get("data", {})
    groups = data.get("groups", [])

    for g in groups:
        if g.get("name") == "homelab-advisor.rules":
            rules = g.get("rules", [])
            assert len(rules) > 0, "Nenhuma regra encontrada em homelab-advisor.rules"
            for rule in rules:
                ann = rule.get("annotations") or {}
                assert "runbook_url" in ann and ann.get("runbook_url"), f"Regra {rule.get('name')} sem runbook_url"
            return

    pytest.skip("Grupo de regras 'homelab-advisor.rules' não encontrado no Prometheus")
