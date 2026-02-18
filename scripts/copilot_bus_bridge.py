#!/usr/bin/env python3
"""
Copilot Bus Bridge — Mantém o Agent Copilot (dev_local) conectado ao Communication Bus
do homelab e aceita tarefas quando os agentes especializados estão ocupados.

Funcionalidades:
- Anuncia presença (heartbeat) no bus a cada 30s
- Escuta mensagens via SSE /bus/stream
- Aceita tarefas REQUEST direcionadas ao copilot ou sem target quando agentes estão busy
- Responde via /communication/publish
- Registra resultados via /distributed/record-result

Uso:
    python3 scripts/copilot_bus_bridge.py [--homelab-url URL] [--poll-interval SEC]

Requisitos: requests (pip install requests)
"""
import argparse
import json
import logging
import os
import signal
import sys
import threading
import time
from datetime import datetime, timezone
from typing import Optional, Dict, Any

try:
    import requests
except ImportError:
    print("ERRO: pip install requests")
    sys.exit(1)

# ── Config ────────────────────────────────────────────────────
HOMELAB_URL = os.environ.get("HOMELAB_URL", "http://192.168.15.2:8503")
COPILOT_AGENT_NAME = "copilot-vscode"
HEARTBEAT_INTERVAL = 30  # segundos
POLL_INTERVAL = 5  # polling quando SSE não disponível
TASK_ACCEPT_KEYWORDS = ["copilot", "copilot-vscode", "copilot-local", "dev_local"]
MAX_IDLE_BEFORE_VOLUNTEER = 60  # segundos sem atividade → voluntariar para tarefas

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("copilot-bridge")


class CopilotBusBridge:
    """Bridge entre Copilot local e o Communication Bus do homelab."""

    def __init__(self, homelab_url: str = HOMELAB_URL):
        self.homelab_url = homelab_url.rstrip("/")
        self.running = False
        self.connected = False
        self.last_heartbeat = 0
        self.last_activity = time.time()
        self.tasks_accepted = 0
        self.tasks_completed = 0
        self.tasks_failed = 0
        self._pending_tasks: list = []
        self._lock = threading.Lock()
        self.poll_interval = POLL_INTERVAL

    # ── API Helpers ───────────────────────────────────────

    def _post(self, path: str, json_data: dict, timeout: float = 10) -> Optional[dict]:
        """POST request ao homelab API."""
        try:
            resp = requests.post(
                f"{self.homelab_url}{path}",
                json=json_data,
                timeout=timeout,
            )
            resp.raise_for_status()
            return resp.json()
        except requests.exceptions.ConnectionError:
            if self.connected:
                logger.warning("Conexão com homelab perdida")
                self.connected = False
            return None
        except Exception as e:
            logger.error(f"POST {path} falhou: {e}")
            return None

    def _get(self, path: str, timeout: float = 10) -> Optional[dict]:
        """GET request ao homelab API."""
        try:
            resp = requests.get(f"{self.homelab_url}{path}", timeout=timeout)
            resp.raise_for_status()
            return resp.json()
        except requests.exceptions.ConnectionError:
            if self.connected:
                logger.warning("Conexão com homelab perdida")
                self.connected = False
            return None
        except Exception as e:
            logger.error(f"GET {path} falhou: {e}")
            return None

    # ── Heartbeat ─────────────────────────────────────────

    def send_heartbeat(self):
        """Anuncia presença do Copilot no bus."""
        now = time.time()
        if now - self.last_heartbeat < HEARTBEAT_INTERVAL:
            return

        result = self._post("/communication/publish", {
            "message_type": "response",
            "source": COPILOT_AGENT_NAME,
            "target": "coordinator",
            "content": json.dumps({
                "type": "heartbeat",
                "agent": COPILOT_AGENT_NAME,
                "status": "online",
                "capabilities": [
                    "flutter", "dart", "node.js", "express", "python",
                    "devops", "ci/cd", "docker", "git", "code-review",
                    "multi-language", "full-stack"
                ],
                "tasks_accepted": self.tasks_accepted,
                "tasks_completed": self.tasks_completed,
                "tasks_failed": self.tasks_failed,
                "pending_tasks": len(self._pending_tasks),
                "available": len(self._pending_tasks) < 3,  # aceita até 3 simultâneas
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }),
            "metadata": {
                "agent_type": "copilot-vscode",
                "heartbeat": True,
                "available_for_overflow": True,
            }
        })

        if result:
            if not self.connected:
                logger.info("✅ Conectado ao Communication Bus do homelab")
                self.connected = True
            self.last_heartbeat = now
        else:
            self.connected = False

    # ── Task Handling ─────────────────────────────────────

    def should_accept_task(self, message: dict) -> bool:
        """Decide se o Copilot deve aceitar esta tarefa."""
        target = message.get("target", "").lower()
        source = message.get("source", "").lower()
        msg_type = message.get("type", "").lower()
        content = str(message.get("content", "")).lower()

        # Sempre aceitar se explicitamente direcionado ao copilot
        if any(kw in target for kw in TASK_ACCEPT_KEYWORDS):
            return True

        # Ignorar heartbeats e mensagens do coordinator (auto-scaling noise)
        if msg_type == "coordinator" or source == "coordinator":
            return False

        # Ignorar nossas próprias mensagens
        if source == COPILOT_AGENT_NAME or source == "copilot-local":
            return False

        # Aceitar requests sem target específico (broadcast) se idle
        if msg_type == "request" and (target == "all" or target == ""):
            idle_time = time.time() - self.last_activity
            if idle_time > MAX_IDLE_BEFORE_VOLUNTEER and len(self._pending_tasks) < 3:
                return True

        # Aceitar se um agente falhou e há fallback para copilot
        if "fallback" in content and "copilot" in content:
            return True

        # Aceitar tasks de erro que mencionam linguagens que dominamos
        if msg_type == "error" and any(
            lang in content
            for lang in ["flutter", "dart", "javascript", "typescript", "python", "node"]
        ):
            if len(self._pending_tasks) < 3:
                return True

        return False

    def accept_task(self, message: dict):
        """Aceita e registra uma tarefa."""
        task_id = message.get("id", f"task_{int(time.time())}")
        content = message.get("content", "")

        with self._lock:
            self._pending_tasks.append({
                "id": task_id,
                "content": content,
                "source": message.get("source", "unknown"),
                "accepted_at": datetime.now(timezone.utc).isoformat(),
            })
            self.tasks_accepted += 1

        logger.info(f"📋 Tarefa aceita: {task_id} de {message.get('source', '?')}")

        # Publicar aceitação no bus
        self._post("/communication/publish", {
            "message_type": "response",
            "source": COPILOT_AGENT_NAME,
            "target": message.get("source", "coordinator"),
            "content": json.dumps({
                "type": "task_accepted",
                "task_id": task_id,
                "message": f"Copilot aceitou a tarefa. Pendentes: {len(self._pending_tasks)}",
            }),
            "metadata": {"task_id": task_id, "overflow": True}
        })

        self.last_activity = time.time()

    def complete_task(self, task_id: str, success: bool = True, result: str = ""):
        """Marca tarefa como concluída e registra no sistema distribuído."""
        with self._lock:
            self._pending_tasks = [t for t in self._pending_tasks if t["id"] != task_id]
            if success:
                self.tasks_completed += 1
            else:
                self.tasks_failed += 1

        # Registrar no distributed coordinator
        self._post("/distributed/record-result", {
            "language": "copilot",
            "success": success,
            "execution_time": 0.0,
        })

        # Publicar resultado no bus
        self._post("/communication/publish", {
            "message_type": "response",
            "source": COPILOT_AGENT_NAME,
            "target": "coordinator",
            "content": json.dumps({
                "type": "task_completed" if success else "task_failed",
                "task_id": task_id,
                "success": success,
                "result": result[:500],
            }),
            "metadata": {"task_id": task_id}
        })

        logger.info(f"{'✅' if success else '❌'} Tarefa {task_id}: {'concluída' if success else 'falhou'}")

    # ── Bus Listener (Polling) ────────────────────────────

    def poll_messages(self):
        """Polling de mensagens do bus (fallback quando SSE não funciona cross-network)."""
        data = self._get("/communication/messages")
        if not data:
            return

        messages = data if isinstance(data, list) else data.get("messages", [])

        for msg in messages[-20:]:  # últimas 20
            if self.should_accept_task(msg):
                self.accept_task(msg)

    def listen_sse(self):
        """Escuta SSE /bus/stream em tempo real (roda em thread separada)."""
        logger.info("🔌 Iniciando SSE listener...")
        while self.running:
            try:
                with requests.get(
                    f"{self.homelab_url}/bus/stream?limit=10",
                    stream=True,
                    timeout=(10, None),  # connect timeout 10s, read indefinido
                ) as resp:
                    resp.raise_for_status()
                    logger.info("📡 SSE stream conectado")
                    self.connected = True

                    for line in resp.iter_lines(decode_unicode=True):
                        if not self.running:
                            break
                        if not line or line.startswith(":"):
                            continue
                        if line.startswith("data: "):
                            data = line[6:]
                            if data == "[HEARTBEAT]":
                                continue
                            try:
                                msg = json.loads(data)
                                if self.should_accept_task(msg):
                                    self.accept_task(msg)
                            except json.JSONDecodeError:
                                pass
            except requests.exceptions.ConnectionError:
                if self.connected:
                    logger.warning("SSE desconectado, reconectando em 10s...")
                    self.connected = False
                time.sleep(10)
            except Exception as e:
                logger.error(f"SSE erro: {e}")
                time.sleep(10)

    # ── Main Loop ─────────────────────────────────────────

    def announce_online(self):
        """Anuncia que o Copilot está online no bus."""
        result = self._post("/communication/publish", {
            "message_type": "response",
            "source": COPILOT_AGENT_NAME,
            "target": "coordinator",
            "content": json.dumps({
                "type": "agent_online",
                "agent": COPILOT_AGENT_NAME,
                "message": "Copilot (dev_local) conectado ao bus — disponível para overflow de tarefas",
                "capabilities": [
                    "flutter", "dart", "node.js", "express", "python",
                    "devops", "ci/cd", "docker", "git", "code-review",
                ],
                "accept_overflow": True,
            }),
            "metadata": {"agent_type": "copilot-vscode", "event": "online"}
        })

        if result:
            logger.info("📢 Anúncio de presença publicado no bus")
            self.connected = True
        else:
            logger.error("❌ Falha ao anunciar presença — homelab inacessível?")

    def announce_offline(self):
        """Anuncia que o Copilot está saindo."""
        self._post("/communication/publish", {
            "message_type": "response",
            "source": COPILOT_AGENT_NAME,
            "target": "coordinator",
            "content": json.dumps({
                "type": "agent_offline",
                "agent": COPILOT_AGENT_NAME,
                "message": "Copilot (dev_local) desconectando do bus",
                "stats": {
                    "tasks_accepted": self.tasks_accepted,
                    "tasks_completed": self.tasks_completed,
                    "tasks_failed": self.tasks_failed,
                }
            }),
            "metadata": {"agent_type": "copilot-vscode", "event": "offline"}
        })
        logger.info("👋 Anúncio de saída publicado")

    def get_status(self) -> dict:
        """Retorna status atual do bridge."""
        return {
            "agent": COPILOT_AGENT_NAME,
            "connected": self.connected,
            "homelab_url": self.homelab_url,
            "tasks_accepted": self.tasks_accepted,
            "tasks_completed": self.tasks_completed,
            "tasks_failed": self.tasks_failed,
            "pending_tasks": len(self._pending_tasks),
            "uptime_seconds": time.time() - self._start_time if hasattr(self, "_start_time") else 0,
        }

    def run(self, use_sse: bool = True):
        """Loop principal do bridge."""
        self.running = True
        self._start_time = time.time()

        # Registrar handlers de sinal
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

        logger.info(f"🚀 Copilot Bus Bridge iniciando — homelab: {self.homelab_url}")

        # Verificar conectividade
        health = self._get("/health")
        if not health:
            logger.error(f"❌ Homelab inacessível em {self.homelab_url}")
            logger.info("Tentando novamente em 10s...")
            time.sleep(10)
            health = self._get("/health")
            if not health:
                logger.error("Homelab continua inacessível. Abortando.")
                return

        logger.info(f"✅ Homelab healthy: {health.get('status', '?')}")

        # Anunciar presença
        self.announce_online()

        # Iniciar SSE listener em thread separada
        if use_sse:
            sse_thread = threading.Thread(target=self.listen_sse, daemon=True)
            sse_thread.start()

        # Loop principal: heartbeat + polling backup
        try:
            while self.running:
                self.send_heartbeat()

                # Polling backup (caso SSE perca msgs)
                if not use_sse:
                    self.poll_messages()

                # Log status periódico (a cada 5 min)
                if int(time.time()) % 300 < self.poll_interval:
                    status = self.get_status()
                    logger.info(
                        f"📊 Status: connected={status['connected']} | "
                        f"accepted={status['tasks_accepted']} | "
                        f"completed={status['tasks_completed']} | "
                        f"pending={status['pending_tasks']}"
                    )

                time.sleep(self.poll_interval)

        except KeyboardInterrupt:
            logger.info("Interrompido pelo usuário")
        finally:
            self.running = False
            self.announce_offline()
            logger.info("🛑 Copilot Bus Bridge encerrado")

    def _signal_handler(self, signum, frame):
        logger.info(f"Sinal {signum} recebido, encerrando...")
        self.running = False


def main():
    parser = argparse.ArgumentParser(description="Copilot Bus Bridge")
    parser.add_argument(
        "--homelab-url",
        default=os.environ.get("HOMELAB_URL", HOMELAB_URL),
        help="URL da API do homelab (default: http://192.168.15.2:8503)",
    )
    parser.add_argument(
        "--poll-interval",
        type=int,
        default=POLL_INTERVAL,
        help="Intervalo de polling em segundos (default: 5)",
    )
    parser.add_argument(
        "--no-sse",
        action="store_true",
        help="Usar apenas polling (sem SSE stream)",
    )
    args = parser.parse_args()

    poll_interval = args.poll_interval

    bridge = CopilotBusBridge(homelab_url=args.homelab_url)
    bridge.poll_interval = poll_interval
    bridge.run(use_sse=not args.no_sse)


if __name__ == "__main__":
    main()
