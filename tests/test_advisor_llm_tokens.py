import sys
import types
import asyncio
import pytest

# Skip test when httpx (async client) is not available in the environment
pytest.importorskip('httpx')

# Inject minimal stubs for heavy imports so module can be imported in CI/test env
if 'fastapi' not in sys.modules:
    fake_fastapi = types.SimpleNamespace(FastAPI=lambda *a, **k: None, HTTPException=Exception, Request=object)
    sys.modules['fastapi'] = fake_fastapi
    # also provide fastapi.responses.Response
    mod_responses = types.SimpleNamespace(Response=lambda *a, **k: None)
    sys.modules['fastapi.responses'] = mod_responses

# Stub pydantic if missing in the test env
if 'pydantic' not in sys.modules:
    sys.modules['pydantic'] = types.SimpleNamespace(BaseModel=object)

import advisor_agent_patch as adv_mod


def test_advisor_llm_tokens_metric(monkeypatch):
    # Monkeypatch AsyncClient.post to return a predictable response
    class DummyResp:
        def raise_for_status(self):
            return None

        def json(self):
            return {"response": "This is a short LLM reply for testing."}

    async def fake_post(self, url, json=None, *args, **kwargs):
        return DummyResp()

    monkeypatch.setattr("httpx.AsyncClient.post", fake_post, raising=False)

    # Execute the async call
    res = asyncio.get_event_loop().run_until_complete(adv_mod.advisor.call_llm("Test prompt for tokens", max_tokens=40))
    assert isinstance(res, str)

    # Export metrics text and verify token counters were incremented
    metrics_text = adv_mod.generate_latest().decode("utf-8")
    assert "advisor_llm_tokens_total" in metrics_text
    # ensure the labeled metrics are present
    assert "advisor_llm_tokens_total{type=\"prompt\"}" in metrics_text
    assert "advisor_llm_tokens_total{type=\"response\"}" in metrics_text
    assert "advisor_llm_tokens_total{type=\"total\"}" in metrics_text
