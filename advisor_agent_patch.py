#!/usr/bin/env python3
"""
Homelab Advisor Agent
Consultor especialista para o servidor homelab conectado ao barramento.
Integrado com: IPC (PostgreSQL), Scheduler periódico, API principal (8503).
"""
import os
import sys
import asyncio
import json
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, Optional, List, Any
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
from pydantic import BaseModel
import httpx
import psutil
import subprocess
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

# Adicionar path para imports do projeto principal
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("homelab-advisor")

try:
    from specialized_agents.agent_communication_bus import get_communication_bus, MessageType
    BUS_AVAILABLE = True
except ImportError:
    BUS_AVAILABLE = False
    logger.warning("Bus in-memory não disponível")

try:
    from tools.agent_ipc import publish_request, poll_response, fetch_pending, respond, init_table
    IPC_AVAILABLE = True
except ImportError:
    IPC_AVAILABLE = False
    logger.warning("IPC module não disponível")

try:
    from rag import ServerKnowledgeRAG
    RAG_AVAILABLE = True
except ImportError:
    RAG_AVAILABLE = False
    logger.warning("RAG module não disponível")


app = FastAPI(title="Homelab Advisor Agent", version="1.1.0")

# ==================== Prometheus Metrics ====================
http_requests_total = Counter(
    "http_requests_total",
    "Total de requisições HTTP",
    ["endpoint", "method", "status"]
)

http_request_duration_seconds = Histogram(
    "http_request_duration_seconds",
    "Duração das requisições HTTP em segundos",
    ["endpoint", "method"],
    buckets=(0.01, 0.05, 0.1, 0.5, 1.0, 2.0, 5.0, 10.0)
)

advisor_analysis_total = Counter(
    "advisor_analysis_total",
    "Total de análises completadas",
    ["scope"]
)

advisor_analysis_duration_seconds = Histogram(
    "advisor_analysis_duration_seconds",
    "Duração das análises em segundos",
    ["scope"],
    buckets=(0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0)
)

advisor_agents_trained_total = Counter(
    "advisor_agents_trained_total",
    "Total de agentes treinados",
    ["agent_name"]
)

advisor_ipc_pending_requests = Gauge(
    "advisor_ipc_pending_requests",
    "Número de requisições IPC pendentes"
)

# indica se o IPC (Postgres) está disponível para o agente (1 = disponível, 0 = não)
advisor_ipc_ready = Gauge(
    "advisor_ipc_ready",
    "1 se o IPC (Postgres) estiver disponível para o advisor, 0 caso contrário"
)

advisor_llm_calls_total = Counter(
    "advisor_llm_calls_total",
    "Total de chamadas ao LLM",
    ["status"]
)

advisor_llm_duration_seconds = Histogram(
    "advisor_llm_duration_seconds",
    "Duração das chamadas ao LLM em segundos",
    buckets=(0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0, 90.0)
)

# --- Métricas Scheduler ---
advisor_scheduler_runs_total = Counter(
    "advisor_scheduler_runs_total",
    "Total de execuções do scheduler",
    ["scope"]
)

advisor_scheduler_errors_total = Counter(
    "advisor_scheduler_errors_total",
    "Total de erros do scheduler",
    ["scope"]
)

advisor_scheduler_last_run_timestamp = Gauge(
    "advisor_scheduler_last_run_timestamp",
    "Timestamp da última execução do scheduler",
    ["scope"]
)

# --- Métricas API Integration ---
advisor_api_reports_total = Counter(
    "advisor_api_reports_total",
    "Total de relatórios enviados à API principal",
    ["status"]
)

advisor_api_registration_status = Gauge(
    "advisor_api_registration_status",
    "Status de registro na API principal (1=registrado, 0=não)"
)

advisor_ipc_messages_processed_total = Counter(
    "advisor_ipc_messages_processed_total",
    "Total de mensagens IPC processadas",
    ["result"]
)

# --- Heartbeat metric (used to detect agent liveness in logs/alerts)
advisor_heartbeat_timestamp = Gauge(
    "advisor_heartbeat_timestamp",
    "Unix timestamp of last advisor heartbeat"
)

# --- RAG metrics ---
advisor_rag_documents_indexed = Gauge(
    "advisor_rag_documents_indexed",
    "Number of documents indexed in RAG"
)

advisor_rag_queries_total = Counter(
    "advisor_rag_queries_total",
    "Total RAG queries",
    ["result"]
)

advisor_rag_reindex_total = Counter(
    "advisor_rag_reindex_total",
    "Total RAG re-index operations"
)


class GenerateRequest(BaseModel):
    prompt: str
    max_tokens: Optional[int] = 256
    model: Optional[str] = None


class AnalysisRequest(BaseModel):
    scope: str  # "performance", "security", "safeguards", "architecture"
    context: Optional[Dict[str, Any]] = None


class TrainingRequest(BaseModel):
    agent_name: str
    task_description: str
    solution: str
    metadata: Optional[Dict[str, Any]] = None


# ==================== HTTP Middleware ====================
@app.middleware("http")
async def http_middleware(request: Request, call_next):
    """Middleware para registrar requisições HTTP com Prometheus"""
    start_time = time.time()
    endpoint = request.url.path
    method = request.method
    
    try:
        response = await call_next(request)
        status = response.status_code
    except Exception as exc:
        status = 500
        raise
    finally:
        duration = time.time() - start_time
        http_requests_total.labels(endpoint=endpoint, method=method, status=status).inc()
        http_request_duration_seconds.labels(endpoint=endpoint, method=method).observe(duration)
    
    return response


class HomelabAdvisor:
    """Consultor especializado no ambiente homelab"""
    
    def __init__(self):
        self.ollama_host = os.environ.get("OLLAMA_HOST", "http://192.168.15.2:11434")
        self.ollama_model = os.environ.get("OLLAMA_MODEL", "eddie-homelab:latest")
        self.database_url = os.environ.get("DATABASE_URL")
        self.api_base_url = os.environ.get("API_BASE_URL", "http://127.0.0.1:8503")
        self.bus_poll_interval = int(os.environ.get("BUS_POLL_INTERVAL_SEC", "5"))
        
        # Intervalos do scheduler (minutos)
        self.perf_interval = int(os.environ.get("SCHEDULER_PERFORMANCE_INTERVAL", "30"))
        self.sec_interval = int(os.environ.get("SCHEDULER_SECURITY_INTERVAL", "120"))
        self.arch_interval = int(os.environ.get("SCHEDULER_ARCHITECTURE_INTERVAL", "360"))
        
        # Último resultado de cada análise (cache para consultas rápidas)
        self.last_results: Dict[str, Dict] = {}
        
        # Bus in-memory (somente se estiver dentro do mesmo processo)
        self.bus = None
        if BUS_AVAILABLE:
            try:
                self.bus = get_communication_bus()
                self.bus.subscribe(self.handle_bus_message)
                logger.info("✅ Subscribed to communication bus")
            except Exception as e:
                logger.warning(f"Bus init failed: {e}")

        # Remote bus polling state (para consumir mensagens publicadas em /communication/messages)
        self._processed_message_ids = set()
        self._last_bus_check = None
        
        # IPC via PostgreSQL
        self.ipc_ready = False
        # diagnostic info for health checks when IPC is not available
        self.ipc_init_error: Optional[str] = None
        self.ipc_diag: Dict[str, Any] = {}

        def _tcp_check(host: str, port: int, timeout: float = 0.8) -> bool:
            import socket
            try:
                with socket.create_connection((host, port), timeout=timeout):
                    return True
            except Exception:
                return False

        if IPC_AVAILABLE and self.database_url:
            try:
                init_table()
                self.ipc_ready = True
                advisor_ipc_ready.set(1)
                logger.info("✅ IPC table initialized (PostgreSQL)")
            except Exception as e:
                # collect diagnostics and keep IPC disabled
                self.ipc_ready = False
                advisor_ipc_ready.set(0)
                self.ipc_init_error = str(e)
                logger.warning(f"IPC init failed: {e}")

                # try to detect reachable candidate hosts to help troubleshooting
                try:
                    from urllib.parse import urlparse
                    parsed = urlparse(self.database_url)
                    host = parsed.hostname
                    port = parsed.port or 5432
                except Exception:
                    host = None
                    port = 5432

                candidates = []
                if host:
                    candidates.append(host)
                candidates.extend([
                    os.environ.get('DB_HOST'),
                    'eddie-postgres',
                    'postgres',
                    '172.17.0.1',
                    '127.0.0.1',
                    'localhost'
                ])
                seen = set()
                diag = {}
                for h in candidates:
                    if not h or h in seen:
                        continue
                    seen.add(h)
                    reachable = _tcp_check(h, port)
                    diag[h] = {'port': port, 'reachable': reachable}
                self.ipc_diag = {'error': self.ipc_init_error, 'candidates': diag}
        else:
            # If DATABASE_URL not configured, try to build from DB_* env vars
            db_host = os.environ.get('DB_HOST') or os.environ.get('POSTGRES_HOST')
            db_port = int(os.environ.get('DB_PORT') or os.environ.get('POSTGRES_PORT') or 5432)
            db_name = os.environ.get('DB_NAME') or os.environ.get('POSTGRES_DB')
            db_user = os.environ.get('DB_USER') or os.environ.get('POSTGRES_USER')
            db_pass = os.environ.get('DB_PASSWORD') or os.environ.get('POSTGRES_PASSWORD')

            if IPC_AVAILABLE and db_host and db_user and db_pass and db_name:
                constructed = f"postgresql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"
                logger.info(f"DATABASE_URL not set; attempting to initialize IPC using DB_HOST={db_host}")
                try:
                    # set and retry
                    self.database_url = constructed
                    init_table()
                    self.ipc_ready = True
                    advisor_ipc_ready.set(1)
                    logger.info("✅ IPC table initialized (PostgreSQL) via DB_HOST variables")
                except Exception as e:
                    self.ipc_ready = False
                    advisor_ipc_ready.set(0)
                    self.ipc_init_error = str(e)
                    logger.warning(f"IPC init failed using DB_HOST vars: {e}")
                    reachable = _tcp_check(db_host, db_port)
                    self.ipc_diag = {'error': self.ipc_init_error, 'candidates': {db_host: {'port': db_port, 'reachable': reachable}}}
            else:
                # garantir que a métrica reflita o estado quando não configurado
                advisor_ipc_ready.set(0)

        # RAG — knowledge retriever
        self.rag = None
        if RAG_AVAILABLE:
            try:
                self.rag = ServerKnowledgeRAG()
                n = self.rag.index()
                advisor_rag_documents_indexed.set(n)
                logger.info(f"📚 RAG: indexou {n} documentos")
            except Exception as e:
                logger.error(f"RAG init falhou: {e}")
                self.rag = None

    def _get_rag_context(self, query: str, top_k: int = 3) -> str:
        """Busca contexto relevante no RAG para enriquecer prompts LLM."""
        if not self.rag or not self.rag.indexed:
            return ""
        try:
            results = self.rag.query(query, top_k=top_k)
            advisor_rag_queries_total.labels(result="success").inc()
            if not results:
                return ""
            parts = []
            for r in results:
                parts.append(f"[{r['source']}:{r['id']}] (relevância={r['score']:.2f})\n{r['excerpt']}")
            return "\n---\n".join(parts)
        except Exception as e:
            advisor_rag_queries_total.labels(result="error").inc()
            logger.warning(f"RAG query error: {e}")
            return ""

    def reindex_rag(self) -> int:
        """Re-indexa o RAG coletando documentos atualizados do sistema."""
        if not self.rag:
            return 0
        try:
            n = self.rag.index()
            advisor_rag_documents_indexed.set(n)
            advisor_rag_reindex_total.inc()
            logger.info(f"📚 RAG re-indexado: {n} documentos")
            return n
        except Exception as e:
            logger.error(f"RAG reindex error: {e}")
            return 0

    async def call_llm(self, prompt: str, max_tokens: int = 4096) -> str:
        """Chama LLM para análise/recomendações"""
        start_time = time.time()
        try:
            url = f"{self.ollama_host}/api/generate"
            payload = {
                "model": self.ollama_model,
                "prompt": prompt,
                "stream": False,
                "options": {"num_predict": max_tokens}
            }
            async with httpx.AsyncClient(timeout=180.0) as client:
                # Audit log: provider information (do NOT log secrets)
                logger.info(
                    f"LLM request provider=ollama host={self.ollama_host} model={self.ollama_model} prompt_len={len(prompt)}"
                )
                r = await client.post(url, json=payload)
                r.raise_for_status()
                data = r.json()
                advisor_llm_calls_total.labels(status="success").inc()
                return data.get("response", "")
        except Exception as exc:
            advisor_llm_calls_total.labels(status="error").inc()
            err_type = type(exc).__name__
            logger.error(f"LLM error ({err_type}): {exc}")
            return f"[erro LLM ({err_type}): {exc}]"
        finally:
            duration = time.time() - start_time
            advisor_llm_duration_seconds.observe(duration)
    
    async def analyze_performance(self, context: Dict = None) -> Dict[str, Any]:
        """Analisa performance do sistema"""
        start_time = time.time()
        try:
            # Coletar métricas
            cpu_percent = psutil.cpu_percent(interval=1)
            mem = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            
            metrics = {
                "cpu_percent": cpu_percent,
                "memory_percent": mem.percent,
                "memory_available_gb": mem.available / (1024**3),
                "disk_percent": disk.percent,
                "disk_free_gb": disk.free / (1024**3)
            }
            
            # Construir prompt para LLM com contexto RAG
            rag_context = self._get_rag_context(f"performance cpu memory disk {cpu_percent}%")
            rag_section = ""
            if rag_context:
                rag_section = f"\n\nContexto relevante do servidor (RAG):\n{rag_context}\n"

            prompt = f"""Você é um consultor de performance de servidores homelab.

Métricas atuais:
- CPU: {cpu_percent}%
- Memória: {mem.percent}% ({mem.available / (1024**3):.1f}GB livres)
- Disco: {disk.percent}% ({disk.free / (1024**3):.1f}GB livres)
{rag_section}
Forneça recomendações específicas de otimização de performance."""
            
            recommendations = await self.call_llm(prompt, max_tokens=400)
            
            return {
                "metrics": metrics,
                "recommendations": recommendations,
                "timestamp": datetime.now().isoformat()
            }
        finally:
            duration = time.time() - start_time
            advisor_analysis_total.labels(scope="performance").inc()
            advisor_analysis_duration_seconds.labels(scope="performance").observe(duration)
    
    async def analyze_security(self, context: Dict = None) -> Dict[str, Any]:
        """Analisa segurança e sugere safeguards"""
        start_time = time.time()
        try:
            # Verificar portas abertas
            try:
                result = subprocess.run(
                    ['ss', '-tuln'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                open_ports = result.stdout
            except Exception:
                open_ports = "Não foi possível listar portas"
            
            rag_context = self._get_rag_context(f"security ports firewall safeguards {open_ports[:100]}")
            rag_section = ""
            if rag_context:
                rag_section = f"\n\nContexto relevante do servidor (RAG):\n{rag_context}\n"

            prompt = f"""Você é um consultor de segurança de servidores homelab.

Portas abertas detectadas:
{open_ports[:500]}
{rag_section}
Analise e forneça:
1. Riscos de segurança identificados
2. Safeguards recomendados
3. Configurações de firewall sugeridas"""
            
            recommendations = await self.call_llm(prompt, max_tokens=500)
            
            return {
                "recommendations": recommendations,
                "timestamp": datetime.now().isoformat()
            }
        finally:
            duration = time.time() - start_time
            advisor_analysis_total.labels(scope="security").inc()
            advisor_analysis_duration_seconds.labels(scope="security").observe(duration)
    
    async def review_architecture(self, context: Dict = None) -> Dict[str, Any]:
        """Revisa arquitetura do sistema"""
        # Listar containers Docker
        try:
            result = subprocess.run(
                ['docker', 'ps', '--format', '{{.Names}}:{{.Status}}'],
                capture_output=True,
                text=True,
                timeout=10
            )
            containers = result.stdout
        except Exception:
            containers = "Não foi possível listar containers"
        
        # Listar serviços systemd
        try:
            result = subprocess.run(
                ['systemctl', 'list-units', '--type=service', '--state=running', '--no-pager'],
                capture_output=True,
                text=True,
                timeout=10
            )
            services = result.stdout
        except Exception:
            services = "Não foi possível listar serviços"
        
        rag_context = self._get_rag_context(f"architecture docker containers systemd services {containers[:100]}")
        rag_section = ""
        if rag_context:
            rag_section = f"\n\nContexto relevante do servidor (RAG):\n{rag_context}\n"

        prompt = f"""Você é um arquiteto de sistemas especialista em homelab.

Containers Docker ativos:
{containers[:300]}

Serviços systemd rodando:
{services[:500]}
{rag_section}
Avalie a arquitetura e sugira melhorias para:
1. Performance
2. Resiliência
3. Manutenibilidade
4. Escalabilidade"""
        
        recommendations = await self.call_llm(prompt, max_tokens=600)
        
        return {
            "containers": containers,
            "services_count": len(services.split('\n')),
            "recommendations": recommendations,
            "timestamp": datetime.now().isoformat()
        }
    
    async def train_local_agent(self, agent_name: str, task: str, solution: str, metadata: Dict = None) -> Dict[str, Any]:
        """Treina agente local com tarefa resolvida"""
        training_data = {
            "timestamp": datetime.now().isoformat(),
            "agent": agent_name,
            "task": task,
            "solution": solution,
            "metadata": metadata or {}
        }
        
        # Salvar training sample em arquivo JSONL
        training_file = f"/tmp/training_{agent_name}_{datetime.now().strftime('%Y%m%d')}.jsonl"
        try:
            with open(training_file, 'a', encoding='utf-8') as f:
                f.write(json.dumps(training_data, ensure_ascii=False) + '\n')
            
            advisor_agents_trained_total.labels(agent_name=agent_name).inc()
            
            return {
                "status": "training_data_saved",
                "file": training_file,
                "message": f"Agente {agent_name} será treinado com esta tarefa"
            }
        except Exception as e:
            return {
                "status": "error",
                "message": f"Erro ao salvar training data: {e}"
            }
    
    def handle_bus_message(self, message):
        """Handler para mensagens do bus (inclui alerts de 'monitoring').

        - passa a aceitar mensagens cujo `target` seja `monitoring`;
        - quando recebe um alerta (metadata.severity) agenda um handler assíncrono
          que executa uma análise rápida e responde via IPC/operations.
        """
        try:
            targets = ('advisor', 'homelab-advisor', 'monitoring', 'all')
            if hasattr(message, 'target') and message.target in targets:
                content = (message.content or "")
                source = getattr(message, 'source', 'unknown')
                logger.info(f"📨 Bus msg de {source} (target={getattr(message, 'target', '')}): {content[:200]}")
                logger.info(f"ipc_ready={self.ipc_ready} api_base_url={self.api_base_url} metadata_keys={list(getattr(message, 'metadata', {}) or {})}")

                # detectar severidade (se vier em metadata)
                severity = None
                if hasattr(message, 'metadata') and isinstance(message.metadata, dict):
                    severity = message.metadata.get('severity') or message.metadata.get('level')
                    if severity:
                        severity = str(severity).lower()

                # Se for um alerta crítico/warning, tratar assincronamente
                if severity in ('critical', 'warning'):
                    try:
                        # disparar worker assíncrono para não bloquear o callback do bus
                        asyncio.get_running_loop().create_task(self._handle_alert(message))
                    except RuntimeError:
                        # fallback caso não exista loop corrente
                        asyncio.create_task(self._handle_alert(message))
                    return

                # comportamento padrão: ecoar/ack via IPC para o originador
                if self.ipc_ready:
                    try:
                        req_id = publish_request(
                            source="homelab-advisor",
                            target=source,
                            content=f"Advisor acknowledged: {content[:50]}",
                            metadata={"original_message_id": getattr(message, 'id', None)}
                        )
                        logger.info(f"📤 Resposta IPC publicada: {req_id}")
                    except Exception as e:
                        logger.error(f"Erro ao publicar resposta IPC: {e}")
                else:
                    # IPC offline → fallback: publicar diretamente no Agent Bus via API
                    try:
                        logger.info("ℹ️ Fallback path triggered: publishing direct response to /communication/publish")
                        payload = {
                            "message_type": "response",
                            "source": "homelab-advisor",
                            "target": source,
                            "content": f"Advisor (fallback): acknowledged - {content[:120]}",
                            "metadata": {"original_message_id": getattr(message, 'id', None), "fallback": True}
                        }
                        resp = httpx.post(f"{self.api_base_url}/communication/publish", json=payload, timeout=5.0)
                        if resp.status_code == 200:
                            logger.info("📤 Fallback: resposta publicada diretamente no bus via API")
                        else:
                            logger.error(f"Fallback publish falhou: {resp.status_code} {resp.text}")
                    except Exception as e:
                        logger.error(f"Erro no fallback de publish direto ao bus: {e}")
        except Exception as e:
            logger.error(f"Erro ao processar mensagem do bus: {e}")

    async def _handle_alert(self, message):
        """Trata alertas vindos do bus: executa check rápido e responde ao originador."""
        try:
            md = getattr(message, 'metadata', {}) or {}
            severity = (md.get('severity') or md.get('level') or '').lower()
            alert_name = md.get('alert_name') or md.get('name') or 'grafana_alert'
            instance = md.get('instance') or 'unknown'

            logger.info(f"⚠️ Handling alert {alert_name} severity={severity} instance={instance}")

            # Buscar contexto RAG relevante para o alerta
            rag_context = self._get_rag_context(f"alert {alert_name} {severity} {instance}", top_k=3)
            rag_section = f"\nContexto RAG:\n{rag_context}" if rag_context else ""

            # ação para alertas críticos: análise rápida de performance + resposta
            if severity == 'critical':
                result = await self.analyze_performance()
                summary = self._summarize_result('performance', result)
                recommendations = result.get('recommendations', '')

                response_text = (
                    f"Alert handled: {alert_name} ({severity}) on {instance}\n"
                    f"Summary: {summary}\n"
                    f"Recommendations: {recommendations[:1200]}"
                    f"{rag_section}"
                )

                # publicar resposta via IPC para o originador do alerta
                if self.ipc_ready:
                    try:
                        rid = publish_request(
                            source='homelab-advisor',
                            target=getattr(message, 'source', 'monitoring'),
                            content=response_text,
                            metadata={'original_message_id': getattr(message, 'id', None), 'alert_handled': True}
                        )
                        logger.info(f"📨 IPC response for alert published: {rid}")
                    except Exception as e:
                        logger.error(f"Erro ao publicar resposta IPC do alerta: {e}")

                # também publicar um relatório para operations (se disponível)
                if self.ipc_ready:
                    try:
                        publish_request(
                            source='homelab-advisor',
                            target='operations',
                            content=f"Automatic incident report: {alert_name} on {instance}",
                            metadata={'severity': severity, 'summary': summary}
                        )
                    except Exception as e:
                        logger.debug(f"Não foi possível publicar relatório para operations: {e}")

            elif severity == 'warning':
                # para warnings, coletar métricas e enviar resumo curto
                result = await self.analyze_performance()
                summary = self._summarize_result('performance', result)
                response_text = f"Warning observed: {alert_name} on {instance} — {summary}{rag_section}"

                if self.ipc_ready:
                    try:
                        publish_request(source='homelab-advisor', target=getattr(message, 'source', 'monitoring'), content=response_text, metadata={'alert_handled': True})
                    except Exception as e:
                        logger.debug(f"IPC publish (warning) falhou: {e}")

            else:
                # outros tipos: registrar e ignorar (pode ser expandido)
                logger.info(f"Alert received (no-op): {alert_name} severity={severity}")

        except Exception as e:
            logger.error(f"Erro em _handle_alert: {e}")
    
    async def process_ipc_requests(self):
        """Processa requests IPC pendentes"""
        if not self.ipc_ready:
            return
        
        try:
            pending = fetch_pending(target='homelab-advisor', limit=10)
        except Exception as e:
            logger.error(f"Erro ao buscar IPC pendentes: {e}")
            advisor_ipc_pending_requests.set(0)
            return
        
        advisor_ipc_pending_requests.set(len(pending))
        
        for req in pending:
            try:
                content = req['content']
                req_id = req['id']
                source = req['source']
                
                logger.info(f"📨 IPC Request #{req_id} de {source}: {content[:100]}")
                
                if 'performance' in content.lower():
                    result = await self.analyze_performance()
                    response_text = json.dumps(result, ensure_ascii=False)
                elif 'security' in content.lower() or 'safeguard' in content.lower():
                    result = await self.analyze_security()
                    response_text = json.dumps(result, ensure_ascii=False)
                elif 'architecture' in content.lower() or 'arquitetura' in content.lower():
                    result = await self.review_architecture()
                    response_text = json.dumps(result, ensure_ascii=False)
                else:
                    try:
                        # Limitar tempo de espera pelo LLM para não bloquear respostas IPC
                        response_text = await asyncio.wait_for(
                            self.call_llm(content, max_tokens=400),
                            timeout=12.0
                        )
                    except asyncio.TimeoutError:
                        logger.warning(f"LLM timeout para IPC #{req_id} — retornando fallback")
                        response_text = "[resposta temporária] O consultor está ocupado; por favor tente novamente em instantes."
                    except Exception as exc:
                        logger.error(f"Erro LLM ao processar IPC #{req_id}: {exc}")
                        response_text = f"[erro LLM: {type(exc).__name__}]"

                respond(req_id, responder="homelab-advisor", response_text=response_text)
                advisor_ipc_messages_processed_total.labels(result="success").inc()
                logger.info(f"✅ Resposta enviada para IPC #{req_id}")
                
            except Exception as e:
                advisor_ipc_messages_processed_total.labels(result="error").inc()
                logger.error(f"Erro ao processar IPC request #{req.get('id','?')}: {e}")

    # ==================== Scheduler ====================
    async def scheduled_analysis(self, scope: str):
        """Executa análise agendada e reporta à API principal"""
        logger.info(f"🕐 Scheduler: iniciando análise '{scope}'")
        try:
            if scope == "performance":
                result = await self.analyze_performance()
            elif scope == "security":
                result = await self.analyze_security()
            elif scope == "architecture":
                result = await self.review_architecture()
            else:
                logger.warning(f"Scheduler: scope desconhecido: {scope}")
                return
            
            self.last_results[scope] = result
            advisor_scheduler_runs_total.labels(scope=scope).inc()
            advisor_scheduler_last_run_timestamp.labels(scope=scope).set(time.time())
            
            # Reportar resultado à API principal
            await self.report_to_api(scope, result)
            
            # Publicar no IPC para outros agentes consumirem
            if self.ipc_ready:
                try:
                    # Relatórios de análises agendadas vão para 'operations' (consumidor apropriado),
                    # não para 'coordinator' que não processa mensagens informativas.
                    publish_request(
                        source="homelab-advisor",
                        target="operations",
                        content=f"Análise {scope} completada automaticamente",
                        metadata={
                            "scope": scope,
                            "summary": self._summarize_result(scope, result),
                            "timestamp": datetime.now().isoformat(),
                            "auto_scheduled": True
                        }
                    )
                except Exception as e:
                    logger.warning(f"IPC publish para operations falhou: {e}")
            
            logger.info(f"✅ Scheduler: análise '{scope}' completa")
            
        except Exception as e:
            advisor_scheduler_errors_total.labels(scope=scope).inc()
            logger.error(f"❌ Scheduler: erro em análise '{scope}': {e}")
    
    def _summarize_result(self, scope: str, result: Dict) -> str:
        """Gera resumo curto do resultado para IPC"""
        if scope == "performance":
            m = result.get("metrics", {})
            return f"CPU:{m.get('cpu_percent',0)}% MEM:{m.get('memory_percent',0)}% DISK:{m.get('disk_percent',0)}%"
        elif scope == "security":
            r = result.get("recommendations", "")
            return r[:200] if r else "sem recomendações"
        elif scope == "architecture":
            return f"containers analisados, serviços: {result.get('services_count', 0)}"
        return "análise concluída"

    # ==================== API Integration (8503) ====================
    async def register_at_api(self):
        """Registra este agente na API principal (8503)"""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                # Verificar se a API está saudável
                r = await client.get(f"{self.api_base_url}/health")
                if r.status_code != 200:
                    logger.warning(f"API principal não saudável: {r.status_code}")
                    advisor_api_registration_status.set(0)
                    return False
                
                # Publicar via IPC que o advisor está online
                if self.ipc_ready:
                    # Não publicar status periódicos para 'coordinator' (polui a fila).
                    # Enviar para 'monitoring' — informação apenas para observabilidade.
                    publish_request(
                        source="homelab-advisor",
                        target="monitoring",
                        content="Homelab Advisor Agent online e operacional",
                        metadata={
                            "agent_type": "homelab-advisor",
                            "capabilities": ["performance", "security", "architecture", "safeguards"],
                            "port": 8085,
                            "scheduler_active": True,
                            "intervals": {
                                "performance_min": self.perf_interval,
                                "security_min": self.sec_interval,
                                "architecture_min": self.arch_interval
                            }
                        }
                    )
                
                advisor_api_registration_status.set(1)
                logger.info("✅ Registrado na API principal via IPC")
                return True
                
        except Exception as e:
            advisor_api_registration_status.set(0)
            logger.warning(f"Registro na API falhou: {e}")
            return False
    
    async def report_to_api(self, scope: str, result: Dict):
        """Reporta resultado de análise à API principal"""
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                payload = {
                    "source": "homelab-advisor",
                    "scope": scope,
                    "summary": self._summarize_result(scope, result),
                    "timestamp": datetime.now().isoformat(),
                    "auto_scheduled": True
                }
                
                # Tentar reportar via health/status
                r = await client.get(f"{self.api_base_url}/health")
                if r.status_code == 200:
                    advisor_api_reports_total.labels(status="success").inc()
                    # Armazenar resultado via IPC (persistência real)
                    if self.ipc_ready:
                        publish_request(
                            source="homelab-advisor",
                            target="operations",
                            content=f"Relatório automático: {scope}",
                            metadata={
                                "report_type": scope,
                                "data": self._summarize_result(scope, result),
                                "timestamp": datetime.now().isoformat()
                            }
                        )
                else:
                    advisor_api_reports_total.labels(status="api_unavailable").inc()
                    
        except Exception as e:
            advisor_api_reports_total.labels(status="error").inc()
            logger.warning(f"Report à API falhou: {e}")
    
    async def check_api_tasks(self):
        """Verifica se há tarefas atribuídas a este agente na API"""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                r = await client.get(f"{self.api_base_url}/health")
                if r.status_code == 200:
                    api_data = r.json()
                    logger.debug(f"API health: {api_data.get('status', 'unknown')}")
        except Exception:
            pass  # Silencioso — não bloquear por falha da API


# Singleton advisor
advisor = HomelabAdvisor()


@app.on_event("startup")
async def startup_event():
    logger.info("🚀 Homelab Advisor Agent iniciado")
    logger.info(f"   Ollama: {advisor.ollama_host}")
    logger.info(f"   Model: {advisor.ollama_model}")
    logger.info(f"   Bus: {'✅ Conectado' if advisor.bus else '❌ Offline'}")
    logger.info(f"   IPC: {'✅ Disponível' if advisor.ipc_ready else '❌ Offline'}")
    rag_st = advisor.rag.status() if advisor.rag else {'indexed': False, 'documents': 0}
    logger.info(f"   RAG: {'📚 ' + str(rag_st['documents']) + ' docs' if rag_st['indexed'] else '❌ Offline'}")
    logger.info(f"   API: {advisor.api_base_url}")
    logger.info(f"   Scheduler: perf={advisor.perf_interval}m, sec={advisor.sec_interval}m, arch={advisor.arch_interval}m")
    
    # Iniciar worker IPC em background
    if advisor.ipc_ready:
        asyncio.create_task(ipc_worker())
        logger.info("🔄 IPC worker iniciado (poll a cada 5s)")
    
    # Iniciar poller do bus remoto (consome /communication/messages)
    asyncio.create_task(bus_poll_worker())
    logger.info("🔔 Remote bus poller iniciado (consome /communication/messages)")

    # Iniciar scheduler de análises periódicas
    asyncio.create_task(scheduler_worker())
    logger.info("🕐 Scheduler de análises iniciado")

    # Iniciar heartbeat worker (emite log 'advisor_heartbeat' + metric)
    asyncio.create_task(heartbeat_worker())
    # Garantir que o metric exista imediatamente após startup (evita gaps entre startup e 1ª iteração)
    try:
        advisor_heartbeat_timestamp.set(time.time())
        logger.info("💓 Heartbeat metric inicializado no startup")
    except Exception as _:
        logger.exception("Erro ao setar advisor_heartbeat_timestamp no startup")
    logger.info("💓 Heartbeat worker iniciado")
    
    # Iniciar RAG re-index worker
    if advisor.rag:
        asyncio.create_task(rag_reindex_worker())
        logger.info("📚 RAG reindex worker iniciado")

    # Registrar na API principal
    asyncio.create_task(api_registration_worker())
    logger.info("🔗 API registration worker iniciado")


async def ipc_worker():
    """Worker para processar requests IPC periodicamente"""
    while True:
        try:
            await advisor.process_ipc_requests()
        except Exception as e:
            logger.error(f"Erro no IPC worker: {e}")
        await asyncio.sleep(5)


async def scheduler_worker():
    """Worker que executa análises periódicas automaticamente"""
    # Aguardar 30s para o sistema estabilizar antes da primeira análise
    await asyncio.sleep(30)
    
    # Rodar primeira análise de performance imediatamente
    await advisor.scheduled_analysis("performance")
    
    # Tracks para próxima execução de cada scope
    next_run = {
        "performance": time.time() + (advisor.perf_interval * 60),
        "security": time.time() + 60,  # Security 1min após start
        "architecture": time.time() + 120,  # Architecture 2min após start
    }
    
    while True:
        try:
            now = time.time()
            
            for scope, next_time in next_run.items():
                if now >= next_time:
                    await advisor.scheduled_analysis(scope)
                    interval = {
                        "performance": advisor.perf_interval,
                        "security": advisor.sec_interval,
                        "architecture": advisor.arch_interval,
                    }[scope]
                    next_run[scope] = now + (interval * 60)
            
        except Exception as e:
            logger.error(f"Erro no scheduler: {e}")
        
        await asyncio.sleep(30)  # Verificar a cada 30s


async def rag_reindex_worker():
    """Re-indexa o RAG periodicamente para manter dados atualizados."""
    interval = int(os.environ.get("RAG_REINDEX_INTERVAL_MIN", "15")) * 60
    await asyncio.sleep(interval)  # Primeira re-indexação após o intervalo
    while True:
        try:
            n = advisor.reindex_rag()
            logger.info(f"📚 RAG re-index periódico: {n} documentos")
        except Exception as e:
            logger.error(f"Erro no RAG reindex worker: {e}")
        await asyncio.sleep(interval)


async def api_registration_worker():
    """Worker que mantém registro na API principal"""
    await asyncio.sleep(10)  # Aguardar startup
    
    while True:
        try:
            await advisor.register_at_api()
            # Re-registrar a cada 10 minutos
            await asyncio.sleep(600)
        except Exception as e:
            logger.error(f"Erro no API registration: {e}")
            await asyncio.sleep(60)  # Retry em 1 min em caso de erro


async def bus_poll_worker():
    """Poll no bus remoto (/communication/messages) e encaminha mensagens relevantes ao handler local."""
    await asyncio.sleep(5)
    session = httpx.AsyncClient(timeout=10.0)
    try:
        while True:
            try:
                resp = await session.get(f"{advisor.api_base_url}/communication/messages")
                if resp.status_code == 200:
                    data = resp.json()
                    messages = data.get('messages', [])

                    for m in messages:
                        mid = m.get('id')
                        if not mid or mid in advisor._processed_message_ids:
                            continue

                        # evitar processo de mensagens originadas por este agente
                        if m.get('source') == 'homelab-advisor':
                            advisor._processed_message_ids.add(mid)
                            continue

                        # somente interessados: monitoring, homelab-advisor, advisor, all
                        if m.get('target') and m.get('target') in ('monitoring', 'homelab-advisor', 'advisor', 'all'):
                            # construir objeto simples compatível com handle_bus_message
                            from types import SimpleNamespace
                            msg_obj = SimpleNamespace(
                                id=m.get('id'),
                                timestamp=m.get('timestamp'),
                                content=m.get('content'),
                                source=m.get('source'),
                                target=m.get('target'),
                                metadata=m.get('metadata', {})
                            )
                            try:
                                advisor.handle_bus_message(msg_obj)
                                advisor._processed_message_ids.add(mid)
                            except Exception as e:
                                logger.error(f"Erro ao encaminhar mensagem do bus remoto: {e}")
                else:
                    logger.debug(f"bus_poll_worker: /communication/messages returned {resp.status_code}")
            except Exception as e:
                logger.debug(f"bus_poll_worker error: {e}")

            await asyncio.sleep(advisor.bus_poll_interval)
    finally:
        await session.aclose()



async def heartbeat_worker():
    """Periodic heartbeat log + metric to verify log ingestion and liveness."""
    while True:
        try:
            # Human-readable log line (picked up by promtail) and metric for alerts
            logger.info("💓 advisor_heartbeat")
            advisor_heartbeat_timestamp.set(time.time())
        except Exception as e:
            logger.error(f"Heartbeat error: {e}")
        await asyncio.sleep(60)


@app.get("/health")
async def health():
    """Health check com status completo de todas as integrações

    Adiciona métricas do host (cpu/mem/disk/load) para que painéis/indicadores
    possam exibir o uso real do homelab.
    """
    # coletar métricas de sistema rapidamente (não bloqueante por muito tempo)
    try:
        cpu = psutil.cpu_percent(interval=0.1)
        mem = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        load1, load5, load15 = os.getloadavg()
        system_metrics = {
            "cpu_percent": cpu,
            "memory_percent": mem.percent,
            "memory_available_gb": round(mem.available / (1024**3), 2),
            "disk_percent": disk.percent,
            "disk_free_gb": round(disk.free / (1024**3), 2),
            "loadavg": {"1m": round(load1, 2), "5m": round(load5, 2), "15m": round(load15, 2)}
        }
    except Exception as e:
        logger.warning(f"Falha ao coletar system metrics: {e}")
        system_metrics = {}

    return {
        "status": "healthy",
        "agent": "homelab-advisor",
        "ollama_host": advisor.ollama_host,
        "bus_connected": advisor.bus is not None,
        "ipc_available": advisor.ipc_ready,
        "ipc_diag": getattr(advisor, 'ipc_diag', {}),
        "api_base_url": advisor.api_base_url,
        "system": system_metrics,
        "scheduler": {
            "active": True,
            "intervals": {
                "performance_min": advisor.perf_interval,
                "security_min": advisor.sec_interval,
                "architecture_min": advisor.arch_interval
            },
            "last_results": {
                scope: result.get("timestamp", "nunca")
                for scope, result in advisor.last_results.items()
            }
        },
        "rag": advisor.rag.status() if advisor.rag else {"indexed": False, "documents": 0, "available": False},
        "timestamp": datetime.now().isoformat()
    }


@app.get("/rag/status")
async def rag_status():
    """Retorna status do RAG (documentos indexados, etc.)"""
    if not advisor.rag:
        return {"available": False, "indexed": False, "documents": 0}
    st = advisor.rag.status()
    st["available"] = True
    return st


@app.post("/rag/reindex")
async def rag_reindex():
    """Força re-indexação do RAG"""
    if not advisor.rag:
        raise HTTPException(status_code=503, detail="RAG não disponível")
    n = advisor.reindex_rag()
    return {"status": "reindexed", "documents": n}


@app.get("/rag/search")
async def rag_search(q: str, top_k: int = 3):
    """Busca no RAG por documentos relevantes"""
    if not advisor.rag:
        raise HTTPException(status_code=503, detail="RAG não disponível")
    results = advisor.rag.query(q, top_k=top_k)
    advisor_rag_queries_total.labels(result="success").inc()
    return {"query": q, "results": results}


@app.get("/status")
async def status():
    """Retorna último resultado de cada análise do scheduler"""
    return {
        "agent": "homelab-advisor",
        "last_analyses": {
            scope: {
                "timestamp": result.get("timestamp"),
                "summary": advisor._summarize_result(scope, result)
            }
            for scope, result in advisor.last_results.items()
        },
        "ipc_ready": advisor.ipc_ready,
        "scheduler_scopes": ["performance", "security", "architecture"],
        "timestamp": datetime.now().isoformat()
    }


@app.post("/generate")
async def generate(req: GenerateRequest):
    """Endpoint de geração genérica (compatibilidade com versão anterior)"""
    result = await advisor.call_llm(req.prompt, req.max_tokens)
    return {"result": result, "model": advisor.ollama_model}


@app.post("/analyze")
async def analyze(req: AnalysisRequest):
    """Análise especializada do homelab"""
    if req.scope == "performance":
        result = await advisor.analyze_performance(req.context)
    elif req.scope == "security":
        result = await advisor.analyze_security(req.context)
    elif req.scope == "architecture":
        result = await advisor.review_architecture(req.context)
    elif req.scope == "safeguards":
        # Análise combinada
        perf = await advisor.analyze_performance(req.context)
        sec = await advisor.analyze_security(req.context)
        result = {
            "performance": perf,
            "security": sec,
            "timestamp": datetime.now().isoformat()
        }
    else:
        raise HTTPException(status_code=400, detail=f"Scope inválido: {req.scope}")
    
    return result


@app.post("/train")
async def train(req: TrainingRequest):
    """Treina agente local com tarefa resolvida"""
    result = await advisor.train_local_agent(
        agent_name=req.agent_name,
        task=req.task_description,
        solution=req.solution,
        metadata=req.metadata
    )
    return result


@app.post("/bus/publish")
async def bus_publish(source: str, target: str, content: str, message_type: str = "REQUEST"):
    """Publica mensagem no bus (para testes)"""
    if not advisor.bus:
        raise HTTPException(status_code=503, detail="Bus não disponível")
    
    msg_type = MessageType[message_type.upper()]
    message = advisor.bus.publish(
        message_type=msg_type,
        source=source,
        target=target,
        content=content,
        metadata={"via_api": True}
    )
    
    return {
        "status": "published",
        "message_id": message.id if message else None
    }


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8085))
    uvicorn.run(app, host="0.0.0.0", port=port)
