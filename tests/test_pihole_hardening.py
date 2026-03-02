import re

def test_hardening_doc_contains_bypass_section():
    """Assegura que o documento de hardening lista a prevenção de bypass."""
    text = open('docs/PIHOLE_HARDENING.md').read()
    assert 'Prevenção de bypass' in text
    assert 'redirecionar todo o restante' in text


def test_healthcheck_checks_bypass():
    content = open('scripts/homelab-health-check.sh').read()
    assert 'Block 8.8.8.8' in content
    assert 'iptables -t nat -C PREROUTING' in content
