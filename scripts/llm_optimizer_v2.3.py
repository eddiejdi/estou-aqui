#!/usr/bin/env python3
"""
LLM-Optimizer v2.3 — OpenAI-compatible Proxy para Ollama

Correções v2.3:
- Guards defensivos para acesso a .type em content arrays
- Validação de schema OpenAI na saída
- Fallback para payloads malformados
- Logging estruturado de erros de schema
- Preservação de tool definitions em truncamento

Porta: 8512
Host: 0.0.0.0
"""

import asyncio
import hashlib
import json
import logging
import os
import re
import time
from collections import defaultdict
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import httpx
from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse
from prometheus_client import Counter, Gauge, Histogram, generate_latest
from pydantic import BaseModel, Field

# ══════════════════════════════════════════════════════════════════════════
# Configuração
# ══════════════════════════════════════════════════════════════════════════

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
PORT = int(os.environ.get("LLM_OPTIMIZER_PORT", "8512"))
HOST = os.environ.get("LLM_OPTIMIZER_HOST", "0.0.0.0")
TIMEOUT_EACH = int(os.environ.get("TIMEOUT_EACH", "1200"))  # 20min por request

# Modelos
MODEL_FAST = "qwen3:4b"
MODEL_LIGHTER = "qwen3:0.6b"

# Thresholds de estratégia (em tokens estimados)
STRATEGY_A_MAX = 2000
STRATEGY_B_MAX = 6000

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("llm-optimizer")

# ══════════════════════════════════════════════════════════════════════════
# Métricas Prometheus
# ══════════════════════════════════════════════════════════════════════════

requests_total = Counter(
    "llm_optimizer_requests_total",
    "Total de requisições por estratégia",
    ["strategy"],
)
errors_total = Counter("llm_optimizer_errors_total", "Total de erros")
tokens_saved = Counter("llm_optimizer_tokens_saved_total", "Tokens economizados")
tool_calls_detected = Counter("llm_optimizer_tool_call_detected_total", "Tool calls detectados")
smart_truncations = Counter("llm_optimizer_smart_truncations_total", "Smart truncations executadas")
schema_errors = Counter("llm_optimizer_schema_errors_total", "Erros de schema detectados", ["error_type"])
duration_histogram = Histogram(
    "llm_optimizer_duration_seconds",
    "Duração de requisições",
    ["strategy"],
)
service_up = Gauge("llm_optimizer_up", "Service status")

# In-flight cache (dedup)
_inflight_cache: Dict[str, asyncio.Event] = {}
_inflight_results: Dict[str, Any] = {}
dedup_hits = Counter("llm_optimizer_dedup_hits_total", "Cache hits em in-flight requests")

# ══════════════════════════════════════════════════════════════════════════
# FastAPI App
# ══════════════════════════════════════════════════════════════════════════

app = FastAPI(title="LLM-Optimizer", version="2.3.0")

# ══════════════════════════════════════════════════════════════════════════
# Models
# ══════════════════════════════════════════════════════════════════════════

class Message(BaseModel):
    role: str
    content: Any  # pode ser str ou list de dict
    name: Optional[str] = None
    tool_call_id: Optional[str] = None
    tool_calls: Optional[List[Dict[str, Any]]] = None

class ChatCompletionRequest(BaseModel):
    model: str
    messages: List[Message]
    temperature: Optional[float] = 0.7
    max_tokens: Optional[int] = None
    stream: Optional[bool] = False
    tools: Optional[List[Dict[str, Any]]] = None

# ══════════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════════

def estimate_tokens(text: str) -> int:
    """Estimativa rápida de tokens (4 chars ≈ 1 token)."""
    return len(text) // 4

def hash_messages(messages: List[Dict]) -> str:
    """Gera hash de mensagens para dedup."""
    content = json.dumps(messages, sort_keys=True)
    return hashlib.sha256(content.encode()).hexdigest()[:16]

def safe_get_content_text(content: Any) -> str:
    """
    Extrai texto de content de forma segura.
    
    CORREÇÃO v2.3: Valida item['type'] com guard antes de acessar.
    """
    if isinstance(content, str):
        return content
    
    if isinstance(content, list):
        parts = []
        for item in content:
            # ✅ GUARD: verifica se item é dict e tem 'type' antes de acessar
            if not isinstance(item, dict):
                logger.warning(f"Item em content array não é dict: {type(item)}")
                continue
                
            if "type" not in item:
                logger.warning(f"Item em content array sem 'type': {item.keys()}")
                continue
            
            # Agora sim é seguro acessar item['type']
            if item["type"] == "text" and "text" in item:
                parts.append(item["text"])
            elif item["type"] == "image_url":
                parts.append("[IMAGE]")
        return " ".join(parts)
    
    # Fallback para qualquer outro tipo
    return str(content)

def sanitize_messages(messages: List[Dict]) -> List[Dict]:
    """
    Sanitiza mensagens para formato Ollama-compatible.
    
    CORREÇÃO v2.3:
    - Usa safe_get_content_text para evitar erro em .type
    - Normaliza roles inválidos
    - Remove campos extras
    """
    sanitized = []
    for msg in messages:
        role = msg.get("role", "user")
        
        # Normaliza roles inválidos
        if role in ("tool", "function"):
            role = "user"
        
        # Extrai content de forma segura
        content = safe_get_content_text(msg.get("content", ""))
        
        # Remove mensagens vazias
        if not content.strip():
            continue
        
        sanitized.append({
            "role": role,
            "content": content,
        })
    
    return sanitized

def smart_truncate_system_prompt(content: str, max_tokens: int = 2000) -> str:
    """
    Truncamento inteligente que preserva tool definitions.
    
    Estratégia:
    1. Preserva início (40% do budget) - identidade
    2. Preserva tool definitions (30% do budget)
    3. Preserva fim (30% do budget) - instruções de saída
    """
    tokens = estimate_tokens(content)
    if tokens <= max_tokens:
        return content
    
    smart_truncations.inc()
    
    # Detectar blocos de tools
    tool_patterns = [
        r'<tool_name>.*?</tool_name>',
        r'## Tools.*?(?=##|\Z)',
        r'<tools>.*?</tools>',
        r'execute_command|read_file|write_to_file|list_files',
    ]
    
    tool_blocks = []
    for pattern in tool_patterns:
        matches = re.finditer(pattern, content, re.DOTALL | re.IGNORECASE)
        tool_blocks.extend([m.span() for m in matches])
    
    # Remove duplicatas e ordena
    tool_blocks = sorted(set(tool_blocks))
    
    # Extrai texto dos blocos
    tool_text = ""
    for start, end in tool_blocks:
        tool_text += content[start:end] + "\n\n"
    
    # Budget de caracteres
    max_chars = max_tokens * 4
    budget_start = int(max_chars * 0.4)
    budget_tools = int(max_chars * 0.3)
    budget_end = int(max_chars * 0.3)
    
    # Trunca tool_text se necessário
    if len(tool_text) > budget_tools:
        tool_text = tool_text[:budget_tools] + "\n...[tools truncated]"
    
    # Monta resultado
    start_part = content[:budget_start]
    end_part = content[-budget_end:]
    
    result = f"{start_part}\n\n[...truncated...]\n\n{tool_text}\n\n[...truncated...]\n\n{end_part}"
    
    logger.info(f"Smart truncation: {tokens} tokens → {estimate_tokens(result)} tokens (preservando {len(tool_blocks)} tool blocks)")
    return result

def validate_openai_response(data: Dict) -> Dict:
    """
    Valida e normaliza resposta para schema OpenAI Chat Completion.
    
    CORREÇÃO v2.3: Garante campos obrigatórios sempre presentes.
    """
    if not isinstance(data, dict):
        schema_errors.labels(error_type="not_dict").inc()
        logger.error(f"Resposta não é dict: {type(data)}")
        return create_fallback_response("Internal error: invalid response type")
    
    # Valida choices
    if "choices" not in data or not isinstance(data["choices"], list):
        schema_errors.labels(error_type="missing_choices").inc()
        logger.error(f"Resposta sem 'choices' válido: {data.keys()}")
        return create_fallback_response("Internal error: missing choices")
    
    if len(data["choices"]) == 0:
        schema_errors.labels(error_type="empty_choices").inc()
        logger.error("Resposta com choices vazio")
        return create_fallback_response("Internal error: empty choices")
    
    # Valida message em cada choice
    for i, choice in enumerate(data["choices"]):
        if "message" not in choice:
            schema_errors.labels(error_type="missing_message").inc()
            logger.error(f"Choice {i} sem 'message'")
            choice["message"] = {"role": "assistant", "content": "[erro: resposta inválida]"}
        
        msg = choice["message"]
        
        # Garante role
        if "role" not in msg:
            schema_errors.labels(error_type="missing_role").inc()
            msg["role"] = "assistant"
        
        # Garante content (pode ser null em tool_calls)
        if "content" not in msg:
            schema_errors.labels(error_type="missing_content").inc()
            if "tool_calls" not in msg:
                msg["content"] = ""
            else:
                msg["content"] = None
    
    # Garante campos de metadata
    if "model" not in data:
        data["model"] = MODEL_FAST
    
    if "created" not in data:
        data["created"] = int(time.time())
    
    if "object" not in data:
        data["object"] = "chat.completion"
    
    return data

def create_fallback_response(error_message: str) -> Dict:
    """Cria resposta de fallback válida em caso de erro."""
    return {
        "id": f"fallback-{int(time.time())}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": MODEL_FAST,
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": f"[LLM-Optimizer Error] {error_message}",
                },
                "finish_reason": "stop",
            }
        ],
        "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
    }

async def call_ollama(model: str, messages: List[Dict], timeout: int = TIMEOUT_EACH) -> Dict:
    """Chama Ollama chat endpoint."""
    payload = {
        "model": model,
        "messages": messages,
        "stream": False,
        "options": {"temperature": 0.7},
    }
    
    async with httpx.AsyncClient(timeout=timeout) as client:
        try:
            resp = await client.post(
                f"{OLLAMA_HOST}/api/chat",
                json=payload,
            )
            resp.raise_for_status()
            data = resp.json()
            
            # Converte formato Ollama → OpenAI
            if "message" in data:
                content = data["message"].get("content", "")
                return {
                    "id": f"ollama-{int(time.time())}",
                    "object": "chat.completion",
                    "created": int(time.time()),
                    "model": model,
                    "choices": [
                        {
                            "index": 0,
                            "message": {
                                "role": "assistant",
                                "content": content,
                            },
                            "finish_reason": "stop",
                        }
                    ],
                    "usage": {
                        "prompt_tokens": data.get("prompt_eval_count", 0),
                        "completion_tokens": data.get("eval_count", 0),
                        "total_tokens": data.get("prompt_eval_count", 0) + data.get("eval_count", 0),
                    },
                }
            else:
                schema_errors.labels(error_type="ollama_no_message").inc()
                logger.error(f"Resposta Ollama sem 'message': {data.keys()}")
                return create_fallback_response("Ollama returned invalid format")
                
        except httpx.TimeoutException as e:
            logger.error(f"Timeout ao chamar Ollama ({timeout}s): {e}")
            errors_total.inc()
            return create_fallback_response(f"Timeout after {timeout}s")
        except httpx.HTTPError as e:
            logger.error(f"HTTP error Ollama: {e}")
            errors_total.inc()
            return create_fallback_response(f"Ollama HTTP error: {e}")
        except Exception as e:
            logger.error(f"Erro inesperado Ollama: {e}")
            errors_total.inc()
            return create_fallback_response(f"Unexpected error: {e}")

# ══════════════════════════════════════════════════════════════════════════
# Estratégias
# ══════════════════════════════════════════════════════════════════════════

async def strategy_a(messages: List[Dict]) -> Dict:
    """Strategy A: < 2K tokens → direto qwen3:4b."""
    requests_total.labels(strategy="A").inc()
    logger.info("Strategy A: direto qwen3:4b")
    
    with duration_histogram.labels(strategy="A").time():
        result = await call_ollama(MODEL_FAST, messages)
    
    return validate_openai_response(result)

async def strategy_b(messages: List[Dict]) -> Dict:
    """Strategy B: 2-6K tokens → qwen3:0.6b (mais rápido)."""
    requests_total.labels(strategy="B").inc()
    logger.info("Strategy B: qwen3:0.6b")
    
    with duration_histogram.labels(strategy="B").time():
        result = await call_ollama(MODEL_LIGHTER, messages)
    
    return validate_openai_response(result)

async def strategy_c(messages: List[Dict]) -> Dict:
    """Strategy C: > 6K tokens → Map-Reduce paralelo."""
    requests_total.labels(strategy="C").inc()
    logger.info("Strategy C: Map-Reduce")
    
    # Divide mensagens em chunks (3-5 mensagens por chunk)
    chunk_size = 4
    chunks = [messages[i:i+chunk_size] for i in range(0, len(messages), chunk_size)]
    
    logger.info(f"Map-Reduce: {len(chunks)} chunks")
    
    # MAP: sumariza cada chunk em paralelo com modelo leve
    with duration_histogram.labels(strategy="C-MAP").time():
        map_tasks = []
        for i, chunk in enumerate(chunks):
            summary_prompt = [
                {"role": "system", "content": "Summarize this conversation concisely."},
                *chunk,
            ]
            map_tasks.append(call_ollama(MODEL_LIGHTER, summary_prompt))
        
        summaries = await asyncio.gather(*map_tasks)
    
    # REDUCE: sintetiza com modelo principal
    reduce_messages = [
        {"role": "system", "content": "You are a helpful assistant. Based on the following conversation summaries, provide a final response."},
    ]
    
    for i, summary in enumerate(summaries):
        if "choices" in summary and len(summary["choices"]) > 0:
            content = summary["choices"][0]["message"].get("content", "")
            reduce_messages.append({
                "role": "user",
                "content": f"Summary {i+1}: {content}",
            })
    
    # Última mensagem do usuário (contexto imediato)
    if messages:
        last_msg = messages[-1]
        reduce_messages.append({
            "role": "user",
            "content": f"Current request: {safe_get_content_text(last_msg.get('content', ''))}",
        })
    
    with duration_histogram.labels(strategy="C-REDUCE").time():
        result = await call_ollama(MODEL_FAST, reduce_messages)
    
    # Salva tokens
    original_tokens = sum(estimate_tokens(safe_get_content_text(m.get("content", ""))) for m in messages)
    reduced_tokens = sum(estimate_tokens(m["content"]) for m in reduce_messages)
    saved = max(0, original_tokens - reduced_tokens)
    tokens_saved.inc(saved)
    logger.info(f"Map-Reduce salvou ~{saved} tokens")
    
    return validate_openai_response(result)

# ══════════════════════════════════════════════════════════════════════════
# Endpoints
# ══════════════════════════════════════════════════════════════════════════

@app.get("/health")
async def health():
    """Health check."""
    service_up.set(1)
    return {
        "status": "ok",
        "version": "2.3.0",
        "ollama_host": OLLAMA_HOST,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

@app.get("/metrics")
async def metrics():
    """Prometheus metrics."""
    return Response(content=generate_latest(), media_type="text/plain")

@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    """
    OpenAI-compatible chat completions endpoint.
    
    CORREÇÃO v2.3:
    - Sanitização robusta com guards
    - Validação de schema na saída
    - Fallback para erros
    """
    try:
        body = await request.json()
    except json.JSONDecodeError as e:
        logger.error(f"JSON inválido: {e}")
        errors_total.inc()
        return JSONResponse(
            status_code=400,
            content={"error": "Invalid JSON"},
        )
    
    # Parse request
    try:
        req = ChatCompletionRequest(**body)
    except Exception as e:
        logger.error(f"Request inválido: {e}")
        errors_total.inc()
        return JSONResponse(
            status_code=400,
            content={"error": f"Invalid request: {e}"},
        )
    
    # Detecta tool calling
    if req.tools or any("tool" in msg.role for msg in req.messages):
        tool_calls_detected.inc()
    
    # Converte para dict e sanitiza
    messages_raw = [msg.dict() for msg in req.messages]
    
    # Aplica smart truncation no system prompt se necessário
    for msg in messages_raw:
        if msg.get("role") == "system":
            content = safe_get_content_text(msg.get("content", ""))
            tokens = estimate_tokens(content)
            if tokens > STRATEGY_A_MAX:
                msg["content"] = smart_truncate_system_prompt(content)
    
    # Sanitiza mensagens
    messages = sanitize_messages(messages_raw)
    
    if not messages:
        logger.error("Todas as mensagens foram filtradas na sanitização")
        return JSONResponse(
            status_code=400,
            content={"error": "No valid messages after sanitization"},
        )
    
    # Estima tokens
    total_text = " ".join(safe_get_content_text(m.get("content", "")) for m in messages)
    tokens = estimate_tokens(total_text)
    
    logger.info(f"Request: {len(messages)} msgs, ~{tokens} tokens")
    
    # Dedup (in-flight cache)
    cache_key = hash_messages(messages)
    
    if cache_key in _inflight_cache:
        logger.info("Dedup: aguardando request em andamento")
        dedup_hits.inc()
        await _inflight_cache[cache_key].wait()
        result = _inflight_results.get(cache_key)
        if result:
            return JSONResponse(content=result)
    
    # Registra request em andamento
    _inflight_cache[cache_key] = asyncio.Event()
    
    try:
        # Escolhe estratégia
        if tokens < STRATEGY_A_MAX:
            result = await strategy_a(messages)
        elif tokens < STRATEGY_B_MAX:
            result = await strategy_b(messages)
        else:
            result = await strategy_c(messages)
        
        # Valida resultado
        result = validate_openai_response(result)
        
        # Armazena em cache
        _inflight_results[cache_key] = result
        _inflight_cache[cache_key].set()
        
        # Cleanup cache após 60s
        asyncio.create_task(cleanup_cache(cache_key))
        
        return JSONResponse(content=result)
        
    except Exception as e:
        logger.error(f"Erro durante processamento: {e}", exc_info=True)
        errors_total.inc()
        
        # Libera waiters com fallback
        fallback = create_fallback_response(f"Processing error: {e}")
        _inflight_results[cache_key] = fallback
        _inflight_cache[cache_key].set()
        
        return JSONResponse(
            status_code=500,
            content=fallback,
        )

async def cleanup_cache(key: str):
    """Remove entrada do cache após delay."""
    await asyncio.sleep(60)
    _inflight_cache.pop(key, None)
    _inflight_results.pop(key, None)

# ══════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    import uvicorn
    
    logger.info(f"LLM-Optimizer v2.3 iniciando em {HOST}:{PORT}")
    logger.info(f"Ollama: {OLLAMA_HOST}")
    logger.info(f"Timeout por request: {TIMEOUT_EACH}s")
    
    service_up.set(1)
    
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")
