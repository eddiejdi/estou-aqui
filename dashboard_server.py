#!/usr/bin/env python3
"""
Multi-Agent Dashboard Server para integração com Open WebUI
Expõe um painel inteligente que sincroniza com o Coordinator API
"""

import os
import sys
import json
import logging
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any
from functools import wraps
import asyncio

try:
    from fastapi import FastAPI, HTTPException, Request
    from fastapi.responses import FileResponse, JSONResponse, HTMLResponse
    from fastapi.staticfiles import StaticFiles
    from fastapi.middleware.cors import CORSMiddleware
    import uvicorn
except ImportError:
    print("❌ FastAPI não está instalado. Execute: pip install fastapi uvicorn")
    sys.exit(1)

# ==================== CONFIGURAÇÃO ====================
PORT = int(os.getenv("DASHBOARD_PORT", "8504"))
HOST = os.getenv("DASHBOARD_HOST", "0.0.0.0")
COORDINATOR_URL = os.getenv("COORDINATOR_URL", "http://192.168.15.2:8503")
OPEN_WEBUI_URL = os.getenv("OPEN_WEBUI_URL", "http://192.168.15.2:8080")

# Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("MultiAgentDashboard")

# FastAPI App
app = FastAPI(
    title="Multi-Agent Dashboard",
    description="Dashboard inteligente para monitorar agentes e Communication Bus",
    version="1.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==================== ROTAS ====================

@app.get("/", response_class=HTMLResponse)
async def root():
    """Serve o dashboard HTML principal"""
    dashboard_path = Path(__file__).parent / "dashboards" / "multi_agent_dashboard.html"
    
    if dashboard_path.exists():
        return dashboard_path.read_text(encoding="utf-8")
    
    return """
    <html>
        <head>
            <title>Multi-Agent Dashboard</title>
            <style>
                body { 
                    font-family: Arial, sans-serif; 
                    background: #1f2937; 
                    color: #fff;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                }
                .error { text-align: center; }
                code { background: #374151; padding: 4px 8px; border-radius: 4px; }
            </style>
        </head>
        <body>
            <div class="error">
                <h1>🤖 Multi-Agent Dashboard</h1>
                <p>Dashboard disponível para integração com Open WebUI</p>
                <p>Coordinator API: <code>{}</code></p>
            </div>
        </body>
    </html>
    """.format(COORDINATOR_URL)


@app.get("/api/config")
async def get_config():
    """Retorna configuração do dashboard"""
    return {
        "coordinator_url": COORDINATOR_URL,
        "open_webui_url": OPEN_WEBUI_URL,
        "port": PORT,
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat(),
    }


@app.get("/api/status")
async def get_status():
    """Status geral do sistema"""
    try:
        import httpx
        async with httpx.AsyncClient(timeout=5.0) as client:
            health = await client.get(f"{COORDINATOR_URL}/health")
            return health.json()
    except Exception as e:
        logger.error(f"Erro ao conectar com Coordinator: {e}")
        raise HTTPException(status_code=503, detail="Coordinator indisponível")


@app.get("/api/agents")
async def get_agents():
    """Lista de agentes conectados"""
    try:
        import httpx
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{COORDINATOR_URL}/agents/status")
            return response.json()
    except Exception as e:
        logger.error(f"Erro ao obter agentes: {e}")
        return {"agents": [], "error": str(e)}


@app.get("/api/tasks")
async def get_tasks():
    """Tarefas em execução"""
    try:
        import httpx
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{COORDINATOR_URL}/tasks/running")
            return response.json()
    except Exception as e:
        logger.error(f"Erro ao obter tarefas: {e}")
        return {"tasks": [], "error": str(e)}


@app.get("/api/metrics")
async def get_metrics():
    """Métricas do sistema"""
    try:
        import httpx
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{COORDINATOR_URL}/metrics")
            return response.json()
    except Exception as e:
        logger.error(f"Erro ao obter métricas: {e}")
        return {"error": str(e)}


@app.get("/api/bus/stats")
async def get_bus_stats():
    """Estatísticas do Communication Bus"""
    try:
        import httpx
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{COORDINATOR_URL}/bus/stats")
            return response.json()
    except Exception as e:
        logger.error(f"Erro ao obter bus stats: {e}")
        return {
            "total_messages": 0,
            "queue_size": 0,
            "active_agents": 0,
            "error": str(e)
        }


@app.get("/api/health", response_class=JSONResponse)
async def health_check():
    """Health check do dashboard"""
    return {
        "status": "healthy",
        "service": "MultiAgentDashboard",
        "version": "1.0.0",
        "coordinator_connected": True,
        "timestamp": datetime.utcnow().isoformat(),
        "coordinator_url": COORDINATOR_URL,
        "open_webui_url": OPEN_WEBUI_URL,
    }


@app.post("/api/task/submit")
async def submit_task(request: Request):
    """Submeter nova tarefa ao Coordinator"""
    try:
        payload = await request.json()
        
        import httpx
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                f"{COORDINATOR_URL}/tasks/submit",
                json=payload
            )
            return response.json()
    except Exception as e:
        logger.error(f"Erro ao submeter tarefa: {e}")
        raise HTTPException(status_code=400, detail=str(e))


@app.get("/docs/integration")
async def integration_guide():
    """Guia de integração para Open WebUI"""
    return {
        "title": "Integração Multi-Agent Dashboard com Open WebUI",
        "description": "Como integrar o dashboard inteligente com Open WebUI",
        "steps": [
            {
                "number": 1,
                "title": "Acessar Open WebUI",
                "url": OPEN_WEBUI_URL,
                "instruction": "Abra o Open WebUI em seu navegador"
            },
            {
                "number": 2,
                "title": "Ir para Settings → Functions",
                "instruction": "Navegue até a seção de Funções Customizadas"
            },
            {
                "number": 3,
                "title": "Criar Nova Função",
                "instruction": "Clique em 'Create New Function' e selecione 'Web Interface'"
            },
            {
                "number": 4,
                "title": "Adicionar URL do Dashboard",
                "url": f"http://192.168.15.2:{PORT}",
                "instruction": "Cole a URL do dashboard como frame externo"
            },
            {
                "number": 5,
                "title": "Salvar e Usar",
                "instruction": "Salve a função e acesse via chat ou menu lateral"
            }
        ],
        "direct_access": f"http://192.168.15.2:{PORT}",
        "api_endpoints": {
            "status": f"http://192.168.15.2:{PORT}/api/status",
            "agents": f"http://192.168.15.2:{PORT}/api/agents",
            "tasks": f"http://192.168.15.2:{PORT}/api/tasks",
            "metrics": f"http://192.168.15.2:{PORT}/api/metrics",
            "health": f"http://192.168.15.2:{PORT}/api/health",
        }
    }


# ==================== MAIN ====================

def main():
    logger.info(f"🚀 Iniciando Multi-Agent Dashboard Server")
    logger.info(f"📡 Coordinator: {COORDINATOR_URL}")
    logger.info(f"🌐 Open WebUI: {OPEN_WEBUI_URL}")
    logger.info(f"🎯 Dashboard: http://{HOST}:{PORT}")
    logger.info(f"📚 Docs: http://{HOST}:{PORT}/docs/integration")
    
    uvicorn.run(
        app,
        host=HOST,
        port=PORT,
        log_level="info",
        access_log=True,
    )


if __name__ == "__main__":
    main()
