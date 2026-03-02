#!/usr/bin/env python3
"""
Testes de Contrato para LLM-Optimizer v2.3

Valida que o proxy responde corretamente aos 3 casos críticos:
1. Content string simples
2. Content array multimodal (gatilho do bug 'type' undefined)
3. Role tool/function (CLINE tool-calling)

Uso:
    python3 scripts/test_llm_optimizer_contract.py
    
    # Com URL customizada
    OPTIMIZER_URL=http://192.168.15.2:8512 python3 scripts/test_llm_optimizer_contract.py
"""

import json
import os
import sys
from typing import Dict, Any

import requests

# Configuração
OPTIMIZER_URL = os.environ.get("OPTIMIZER_URL", "http://localhost:8512")
TIMEOUT = 120  # 2 minutos por teste

# Cores para output
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
RESET = "\033[0m"

def print_test(name: str, passed: bool, details: str = ""):
    """Imprime resultado de teste."""
    status = f"{GREEN}✓ PASS{RESET}" if passed else f"{RED}✗ FAIL{RESET}"
    print(f"{status} {name}")
    if details:
        print(f"     {details}")

def validate_openai_schema(response: Dict[str, Any]) -> tuple[bool, str]:
    """
    Valida que resposta segue schema OpenAI Chat Completion.
    
    Campos obrigatórios:
    - choices (list, len > 0)
    - choices[0].message (dict)
    - choices[0].message.role (str)
    - choices[0].message.content (str ou None se tool_calls presente)
    - model (str)
    - created (int)
    - object (str)
    """
    if not isinstance(response, dict):
        return False, f"Resposta não é dict: {type(response)}"
    
    # Valida choices
    if "choices" not in response:
        return False, "Campo 'choices' ausente"
    
    if not isinstance(response["choices"], list):
        return False, f"'choices' não é list: {type(response['choices'])}"
    
    if len(response["choices"]) == 0:
        return False, "'choices' vazio"
    
    # Valida message
    choice = response["choices"][0]
    
    if "message" not in choice:
        return False, "Campo 'message' ausente em choices[0]"
    
    msg = choice["message"]
    
    if "role" not in msg:
        return False, "Campo 'role' ausente em message"
    
    if not isinstance(msg["role"], str):
        return False, f"'role' não é string: {type(msg['role'])}"
    
    # content pode ser null se tool_calls presente
    if "content" not in msg:
        return False, "Campo 'content' ausente em message"
    
    if msg["content"] is not None and not isinstance(msg["content"], str):
        return False, f"'content' não é string nem null: {type(msg['content'])}"
    
    # Valida campos de metadata
    if "model" not in response:
        return False, "Campo 'model' ausente"
    
    if "created" not in response:
        return False, "Campo 'created' ausente"
    
    if "object" not in response:
        return False, "Campo 'object' ausente"
    
    return True, "Schema válido"

def test_simple_content():
    """Teste 1: Content como string simples."""
    print(f"\n{YELLOW}Teste 1: Content string simples{RESET}")
    
    payload = {
        "model": "qwen3:4b",
        "messages": [
            {"role": "user", "content": "Responda apenas: pong"}
        ],
    }
    
    try:
        resp = requests.post(
            f"{OPTIMIZER_URL}/v1/chat/completions",
            json=payload,
            timeout=TIMEOUT,
        )
        
        print_test(
            "HTTP Status 200",
            resp.status_code == 200,
            f"Status: {resp.status_code}",
        )
        
        if resp.status_code != 200:
            print(f"     Body: {resp.text[:500]}")
            return False
        
        data = resp.json()
        
        # Valida schema
        valid, msg = validate_openai_schema(data)
        print_test("Schema OpenAI válido", valid, msg)
        
        if not valid:
            print(f"     Response: {json.dumps(data, indent=2)[:500]}")
            return False
        
        # Valida conteúdo
        content = data["choices"][0]["message"]["content"]
        has_content = content is not None and len(content) > 0
        print_test("Resposta com conteúdo", has_content, f"Length: {len(content) if content else 0}")
        
        return valid and has_content
        
    except requests.Timeout:
        print_test("Timeout", False, f"Excedeu {TIMEOUT}s")
        return False
    except Exception as e:
        print_test("Exception", False, str(e))
        return False

def test_multimodal_content():
    """Teste 2: Content como array (multimodal) - gatilho do bug."""
    print(f"\n{YELLOW}Teste 2: Content array multimodal (gatilho do bug){RESET}")
    
    payload = {
        "model": "qwen3:4b",
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "Descreva esta imagem."},
                    {"type": "image_url", "image_url": {"url": "data:image/png;base64,iVBORw0KGgo="}},
                ],
            }
        ],
    }
    
    try:
        resp = requests.post(
            f"{OPTIMIZER_URL}/v1/chat/completions",
            json=payload,
            timeout=TIMEOUT,
        )
        
        print_test(
            "HTTP Status 200",
            resp.status_code == 200,
            f"Status: {resp.status_code}",
        )
        
        if resp.status_code != 200:
            print(f"     Body: {resp.text[:500]}")
            return False
        
        data = resp.json()
        
        # Valida schema
        valid, msg = validate_openai_schema(data)
        print_test("Schema OpenAI válido", valid, msg)
        
        if not valid:
            print(f"     Response: {json.dumps(data, indent=2)[:500]}")
            return False
        
        # Valida que não houve erro de 'type' undefined
        content = data["choices"][0]["message"]["content"]
        no_type_error = "undefined" not in content.lower() and "cannot read" not in content.lower()
        print_test(
            "Sem erro de 'type' undefined",
            no_type_error,
            f"Content: {content[:100] if content else 'null'}",
        )
        
        return valid and no_type_error
        
    except requests.Timeout:
        print_test("Timeout", False, f"Excedeu {TIMEOUT}s")
        return False
    except Exception as e:
        print_test("Exception", False, str(e))
        return False

def test_tool_role():
    """Teste 3: Role 'tool' (CLINE tool-calling)."""
    print(f"\n{YELLOW}Teste 3: Role 'tool' (CLINE tool-calling){RESET}")
    
    payload = {
        "model": "qwen3:4b",
        "messages": [
            {"role": "user", "content": "List files in current directory"},
            {
                "role": "assistant",
                "content": None,
                "tool_calls": [
                    {
                        "id": "call_123",
                        "type": "function",
                        "function": {
                            "name": "list_files",
                            "arguments": '{"path": "."}',
                        },
                    }
                ],
            },
            {
                "role": "tool",
                "tool_call_id": "call_123",
                "content": "file1.txt\nfile2.py",
            },
        ],
    }
    
    try:
        resp = requests.post(
            f"{OPTIMIZER_URL}/v1/chat/completions",
            json=payload,
            timeout=TIMEOUT,
        )
        
        print_test(
            "HTTP Status 200",
            resp.status_code == 200,
            f"Status: {resp.status_code}",
        )
        
        if resp.status_code != 200:
            print(f"     Body: {resp.text[:500]}")
            return False
        
        data = resp.json()
        
        # Valida schema
        valid, msg = validate_openai_schema(data)
        print_test("Schema OpenAI válido", valid, msg)
        
        if not valid:
            print(f"     Response: {json.dumps(data, indent=2)[:500]}")
            return False
        
        # Valida que role 'tool' foi normalizado sem erro
        content = data["choices"][0]["message"]["content"]
        no_error = content is not None and "error" not in content.lower()[:50]
        print_test(
            "Role 'tool' processado sem erro",
            no_error,
            f"Content: {content[:100] if content else 'null'}",
        )
        
        return valid and no_error
        
    except requests.Timeout:
        print_test("Timeout", False, f"Excedeu {TIMEOUT}s")
        return False
    except Exception as e:
        print_test("Exception", False, str(e))
        return False

def test_health():
    """Teste 0: Health check."""
    print(f"\n{YELLOW}Teste 0: Health check{RESET}")
    
    try:
        resp = requests.get(f"{OPTIMIZER_URL}/health", timeout=10)
        
        print_test("HTTP Status 200", resp.status_code == 200)
        
        if resp.status_code != 200:
            return False
        
        data = resp.json()
        
        has_version = "version" in data
        print_test("Versão presente", has_version, data.get("version", "N/A"))
        
        is_v23 = data.get("version", "").startswith("2.3")
        print_test("Versão 2.3.x", is_v23, data.get("version", "N/A"))
        
        return has_version and is_v23
        
    except Exception as e:
        print_test("Exception", False, str(e))
        return False

def main():
    """Executa todos os testes."""
    print(f"\n{'='*70}")
    print(f"LLM-Optimizer Contract Tests")
    print(f"URL: {OPTIMIZER_URL}")
    print(f"{'='*70}")
    
    results = {
        "Health": test_health(),
        "Simple Content": test_simple_content(),
        "Multimodal Content": test_multimodal_content(),
        "Tool Role": test_tool_role(),
    }
    
    # Summary
    print(f"\n{'='*70}")
    print(f"SUMMARY")
    print(f"{'='*70}")
    
    passed = sum(results.values())
    total = len(results)
    
    for name, result in results.items():
        status = f"{GREEN}✓{RESET}" if result else f"{RED}✗{RESET}"
        print(f"{status} {name}")
    
    print(f"\n{passed}/{total} testes passaram")
    
    if passed == total:
        print(f"{GREEN}✓ TODOS OS TESTES PASSARAM{RESET}")
        return 0
    else:
        print(f"{RED}✗ ALGUNS TESTES FALHARAM{RESET}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
