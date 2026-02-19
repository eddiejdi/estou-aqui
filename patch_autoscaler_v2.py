#!/usr/bin/env python3
"""
Patch: Autoscaler v2 — gerenciamento REAL de containers Docker.
Aplica no homelab via SSH.

Problemas corrigidos:
1. Autoscaler só atualizava contador (não criava/destruía containers)
2. Thresholds inconsistentes entre config.py e autoscaler.py
3. Contador desincronizado com containers reais (24 vs 7)
4. Containers criados sem nunca serem iniciados (port conflicts)

Criado em: 2026-02-18
"""

AUTOSCALER_V2 = r'''"""
Agent Auto-Scaling Manager v2
Gerencia escalonamento automatico de agents com Docker REAL.
"""
import asyncio
import subprocess
import psutil
import time
from datetime import datetime
from typing import Dict, List, Optional
from dataclasses import dataclass, field
from enum import Enum
import logging

logger = logging.getLogger(__name__)

try:
    from .config import AUTOSCALING_CONFIG, SYNERGY_CONFIG
except ImportError:
    AUTOSCALING_CONFIG = {
        "enabled": True,
        "min_agents": 2,
        "max_agents": 16,
        "cpu_scale_up_threshold": 50,
        "cpu_scale_down_threshold": 80,
        "scale_check_interval_seconds": 60,
        "scale_up_increment": 2,
        "scale_down_increment": 1,
        "cooldown_seconds": 120,
    }
    SYNERGY_CONFIG = {
        "communication_bus_enabled": True,
        "max_parallel_tasks_per_agent": 3,
    }

CONTAINER_PREFIX = "spec_agent"


class ScaleAction(Enum):
    NONE = "none"
    SCALE_UP = "scale_up"
    SCALE_DOWN = "scale_down"


@dataclass
class ResourceMetrics:
    """Metricas de recursos do sistema."""
    cpu_percent: float
    memory_percent: float
    disk_percent: float
    active_containers: int
    stopped_containers: int
    pending_tasks: int
    timestamp: datetime


@dataclass
class ScalingDecision:
    """Decisao de escalonamento."""
    action: ScaleAction
    current_agents: int
    target_agents: int
    reason: str
    metrics: ResourceMetrics
    containers_to_stop: List[str] = field(default_factory=list)
    containers_to_start: List[str] = field(default_factory=list)


class AgentAutoScaler:
    """
    Gerencia auto-scaling de agents baseado em uso de CPU/memoria.

    v2: Integracao REAL com Docker containers.
        - Sync counter com containers reais via 'docker ps'
        - Scale DOWN: para containers ociosos quando CPU > threshold
        - Scale UP: reinicia containers parados quando CPU < threshold
        - Safeguard: nunca cria novos containers, apenas start/stop existentes
    """

    def __init__(self):
        self.config = AUTOSCALING_CONFIG
        self.current_agents = 0  # sera sincronizado do Docker
        self.last_scale_action = None
        self.last_scale_time = 0
        self.metrics_history: List[ResourceMetrics] = []
        self.running = False
        self._task: Optional[asyncio.Task] = None
        # Sync on init
        self._sync_container_count()

    # ---- Docker helpers ----

    def _run_docker_cmd(self, args: List[str], timeout: int = 30) -> tuple:
        """Executa comando Docker e retorna (success, stdout, stderr)."""
        try:
            result = subprocess.run(
                ["docker"] + args,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return (result.returncode == 0, result.stdout.strip(), result.stderr.strip())
        except subprocess.TimeoutExpired:
            logger.warning(f"Docker command timed out: docker {' '.join(args)}")
            return (False, "", "timeout")
        except FileNotFoundError:
            logger.error("Docker not found in PATH")
            return (False, "", "docker not found")
        except Exception as e:
            logger.error(f"Docker command error: {e}")
            return (False, "", str(e))

    def _get_running_containers(self) -> List[Dict]:
        """Lista containers spec_agent em execucao."""
        ok, stdout, _ = self._run_docker_cmd([
            "ps", "--filter", f"name={CONTAINER_PREFIX}",
            "--format", "{{.ID}}\t{{.Names}}\t{{.Status}}"
        ])
        if not ok or not stdout:
            return []
        containers = []
        for line in stdout.split("\n"):
            if not line.strip():
                continue
            parts = line.split("\t")
            if len(parts) >= 2:
                containers.append({
                    "id": parts[0],
                    "name": parts[1],
                    "status": parts[2] if len(parts) > 2 else "unknown",
                })
        return containers

    def _get_stopped_containers(self) -> List[Dict]:
        """Lista containers spec_agent parados."""
        ok, stdout, _ = self._run_docker_cmd([
            "ps", "-a",
            "--filter", f"name={CONTAINER_PREFIX}",
            "--filter", "status=exited",
            "--format", "{{.ID}}\t{{.Names}}\t{{.Status}}"
        ])
        if not ok or not stdout:
            return []
        containers = []
        for line in stdout.split("\n"):
            if not line.strip():
                continue
            parts = line.split("\t")
            if len(parts) >= 2:
                containers.append({
                    "id": parts[0],
                    "name": parts[1],
                    "status": parts[2] if len(parts) > 2 else "exited",
                })
        return containers

    def _get_container_cpu_usage(self, container_id: str) -> float:
        """Obtem uso de CPU de um container especifico."""
        ok, stdout, _ = self._run_docker_cmd([
            "stats", "--no-stream", "--format", "{{.CPUPerc}}", container_id
        ], timeout=15)
        if ok and stdout:
            try:
                return float(stdout.replace("%", ""))
            except ValueError:
                pass
        return 0.0

    def _find_idle_containers(self, running: List[Dict], count: int) -> List[str]:
        """Encontra containers ociosos (menor uso de CPU)."""
        usage = []
        for c in running:
            cpu = self._get_container_cpu_usage(c["id"])
            usage.append((c["id"], c["name"], cpu))
        # Sort by CPU usage ascending (most idle first)
        usage.sort(key=lambda x: x[2])
        return [u[0] for u in usage[:count]]

    def _sync_container_count(self):
        """Sincroniza o counter com containers Docker reais."""
        running = self._get_running_containers()
        self.current_agents = len(running)
        return self.current_agents

    def _cleanup_created_containers(self):
        """Remove containers spec_agent em estado 'Created' (nunca iniciados)."""
        ok, stdout, _ = self._run_docker_cmd([
            "ps", "-a",
            "--filter", f"name={CONTAINER_PREFIX}",
            "--filter", "status=created",
            "-q"
        ])
        if ok and stdout:
            ids = [cid.strip() for cid in stdout.split("\n") if cid.strip()]
            if ids:
                logger.warning(f"🧹 Removendo {len(ids)} containers zumbi (Created)...")
                for cid in ids:
                    self._run_docker_cmd(["rm", "-f", cid])
                logger.info(f"🧹 {len(ids)} containers zumbi removidos")

    # ---- Lifecycle ----

    async def start(self):
        """Inicia monitoramento de auto-scaling."""
        if not self.config.get("enabled", True):
            logger.info("Auto-scaling desabilitado")
            return

        # Cleanup containers zumbi na inicializacao
        self._cleanup_created_containers()
        self._sync_container_count()
        self.running = True
        self._task = asyncio.create_task(self._monitor_loop())
        logger.info(f"🚀 Auto-scaler v2 iniciado (containers reais: {self.current_agents})")

    async def stop(self):
        """Para monitoramento."""
        self.running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        logger.info("⏹️ Auto-scaler parado")

    async def _monitor_loop(self):
        """Loop principal de monitoramento."""
        while self.running:
            try:
                # Sync com estado Docker real
                self._sync_container_count()

                metrics = self._collect_metrics()
                self.metrics_history.append(metrics)

                # Manter apenas ultimos 10 minutos de historico
                cutoff = datetime.now().timestamp() - 600
                self.metrics_history = [
                    m for m in self.metrics_history
                    if m.timestamp.timestamp() > cutoff
                ]

                # Avaliar decisao de scaling
                decision = self._evaluate_scaling(metrics)

                if decision.action != ScaleAction.NONE:
                    await self._execute_scaling(decision)

                # Cleanup periodico de containers zumbi
                if len(self.metrics_history) % 20 == 0:
                    self._cleanup_created_containers()

                await asyncio.sleep(self.config.get("scale_check_interval_seconds", 60))

            except Exception as e:
                logger.error(f"Erro no auto-scaler: {e}")
                await asyncio.sleep(30)

    def _collect_metrics(self) -> ResourceMetrics:
        """Coleta metricas atuais do sistema."""
        running = self._get_running_containers()
        stopped = self._get_stopped_containers()
        return ResourceMetrics(
            cpu_percent=psutil.cpu_percent(interval=1),
            memory_percent=psutil.virtual_memory().percent,
            disk_percent=psutil.disk_usage('/').percent,
            active_containers=len(running),
            stopped_containers=len(stopped),
            pending_tasks=self._get_pending_tasks(),
            timestamp=datetime.now()
        )

    def _get_pending_tasks(self) -> int:
        """Obtem numero de tarefas pendentes."""
        try:
            from .agent_communication_bus import get_communication_bus
            bus = get_communication_bus()
            if hasattr(bus, 'pending_count'):
                return bus.pending_count()
        except Exception:
            pass
        return 0

    def _evaluate_scaling(self, metrics: ResourceMetrics) -> ScalingDecision:
        """Avalia se deve escalar agents."""

        # Verificar cooldown
        cooldown = self.config.get("cooldown_seconds", 120)
        if time.time() - self.last_scale_time < cooldown:
            return ScalingDecision(
                action=ScaleAction.NONE,
                current_agents=self.current_agents,
                target_agents=self.current_agents,
                reason="Em cooldown",
                metrics=metrics
            )

        # Calcular media de CPU dos ultimos 60 segundos
        recent_metrics = [
            m for m in self.metrics_history
            if (datetime.now() - m.timestamp).total_seconds() < 60
        ]

        if not recent_metrics:
            recent_metrics = [metrics]

        avg_cpu = sum(m.cpu_percent for m in recent_metrics) / len(recent_metrics)

        scale_up_threshold = self.config.get("cpu_scale_up_threshold", 50)
        scale_down_threshold = self.config.get("cpu_scale_down_threshold", 80)
        min_agents = self.config.get("min_agents", 2)
        max_agents = self.config.get("max_agents", 16)

        running = self._get_running_containers()
        stopped = self._get_stopped_containers()

        # SCALE UP: CPU baixa, ha containers parados que podem ser reiniciados
        if avg_cpu < scale_up_threshold and len(running) < max_agents and len(stopped) > 0:
            increment = min(
                self.config.get("scale_up_increment", 2),
                len(stopped),
                max_agents - len(running)
            )
            if increment > 0:
                containers_to_start = [c["id"] for c in stopped[:increment]]
                return ScalingDecision(
                    action=ScaleAction.SCALE_UP,
                    current_agents=len(running),
                    target_agents=len(running) + increment,
                    reason=f"CPU subutilizada ({avg_cpu:.1f}% < {scale_up_threshold}%) - reiniciando {increment} container(s)",
                    metrics=metrics,
                    containers_to_start=containers_to_start
                )

        # SCALE DOWN: CPU alta, parar containers ociosos
        if avg_cpu > scale_down_threshold and len(running) > min_agents:
            decrement = min(
                self.config.get("scale_down_increment", 1),
                len(running) - min_agents
            )
            if decrement > 0:
                idle_containers = self._find_idle_containers(running, decrement)
                if idle_containers:
                    return ScalingDecision(
                        action=ScaleAction.SCALE_DOWN,
                        current_agents=len(running),
                        target_agents=len(running) - len(idle_containers),
                        reason=f"CPU sobrecarregada ({avg_cpu:.1f}% > {scale_down_threshold}%) - parando {len(idle_containers)} container(s)",
                        metrics=metrics,
                        containers_to_stop=idle_containers
                    )

        return ScalingDecision(
            action=ScaleAction.NONE,
            current_agents=len(running),
            target_agents=len(running),
            reason=f"CPU estavel ({avg_cpu:.1f}%)",
            metrics=metrics
        )

    async def _execute_scaling(self, decision: ScalingDecision):
        """Executa acao de scaling com operacoes Docker REAIS."""
        try:
            old_count = self.current_agents

            if decision.action == ScaleAction.SCALE_UP:
                started = 0
                for container_id in decision.containers_to_start:
                    ok, _, stderr = self._run_docker_cmd(["start", container_id])
                    if ok:
                        started += 1
                        logger.info(f"  ✅ Container iniciado: {container_id}")
                    else:
                        logger.warning(f"  ❌ Falha ao iniciar {container_id}: {stderr}")

                if started > 0:
                    logger.info(f"⬆️ Scale UP: {started}/{len(decision.containers_to_start)} containers iniciados")

            elif decision.action == ScaleAction.SCALE_DOWN:
                stopped = 0
                for container_id in decision.containers_to_stop:
                    ok, _, stderr = self._run_docker_cmd(["stop", container_id])
                    if ok:
                        stopped += 1
                        logger.info(f"  ⏹️ Container parado: {container_id}")
                    else:
                        logger.warning(f"  ❌ Falha ao parar {container_id}: {stderr}")

                if stopped > 0:
                    logger.info(f"⬇️ Scale DOWN: {stopped}/{len(decision.containers_to_stop)} containers parados")

            # Sync after action
            self._sync_container_count()
            self.last_scale_time = time.time()
            self.last_scale_action = decision.action

            action_emoji = "⬆️" if decision.action == ScaleAction.SCALE_UP else "⬇️"
            logger.info(
                f"{action_emoji} Auto-scaling: {old_count} → {self.current_agents} agents | "
                f"Razao: {decision.reason}"
            )

            # Notificar Communication Bus
            await self._notify_scaling(decision)

        except Exception as e:
            logger.error(f"Erro ao executar scaling: {e}")

    async def _notify_scaling(self, decision: ScalingDecision):
        """Notifica outros componentes sobre scaling."""
        try:
            from .agent_communication_bus import log_coordinator
            log_coordinator(
                f"Auto-scaling v2: {decision.current_agents} → {decision.target_agents} agents. "
                f"Razao: {decision.reason}"
            )
        except ImportError:
            pass

    def get_status(self) -> Dict:
        """Retorna status atual do auto-scaler."""
        self._sync_container_count()
        running = self._get_running_containers()
        stopped = self._get_stopped_containers()
        recent_metrics = self.metrics_history[-1] if self.metrics_history else None

        return {
            "enabled": self.config.get("enabled", True),
            "running": self.running,
            "current_agents": self.current_agents,
            "real_running_containers": len(running),
            "stopped_containers": len(stopped),
            "container_names": [c["name"] for c in running],
            "min_agents": self.config.get("min_agents", 2),
            "max_agents": self.config.get("max_agents", 16),
            "last_scale_action": self.last_scale_action.value if self.last_scale_action else None,
            "last_scale_time": datetime.fromtimestamp(self.last_scale_time).isoformat() if self.last_scale_time else None,
            "current_metrics": {
                "cpu_percent": recent_metrics.cpu_percent if recent_metrics else 0,
                "memory_percent": recent_metrics.memory_percent if recent_metrics else 0,
                "disk_percent": recent_metrics.disk_percent if recent_metrics else 0,
            } if recent_metrics else None,
            "thresholds": {
                "scale_up_below_cpu": self.config.get("cpu_scale_up_threshold", 50),
                "scale_down_above_cpu": self.config.get("cpu_scale_down_threshold", 80),
            },
            "version": "v2_docker_real"
        }

    def get_recommended_parallelism(self) -> int:
        """Retorna numero recomendado de tarefas paralelas."""
        max_per_agent = SYNERGY_CONFIG.get("max_parallel_tasks_per_agent", 3)
        return max(self.current_agents, 1) * max_per_agent


# Singleton
_autoscaler_instance: Optional[AgentAutoScaler] = None


def get_autoscaler() -> AgentAutoScaler:
    """Retorna instancia singleton do auto-scaler."""
    global _autoscaler_instance
    if _autoscaler_instance is None:
        _autoscaler_instance = AgentAutoScaler()
    return _autoscaler_instance
'''

CONFIG_PATCH = r'''
# --- AUTOSCALING v2 - Thresholds balanceados ---
AUTOSCALING_CONFIG = {
    "enabled": True,
    "min_agents": 2,                    # Minimo real: 2 containers
    "max_agents": 12,                   # Maximo razoavel para 4 CPUs
    "cpu_scale_up_threshold": 50,       # Escala up quando CPU < 50% (ha headroom)
    "cpu_scale_down_threshold": 80,     # Escala down quando CPU > 80% (sobrecarregado)
    "scale_check_interval_seconds": 60, # Verifica a cada 60s (evita loops agressivos)
    "scale_up_increment": 1,            # Escala 1 por vez (conservador)
    "scale_down_increment": 1,          # Reduz 1 por vez
    "cooldown_seconds": 120,            # 2min entre acoes de scaling
    "idle_timeout_seconds": 300,        # 5min de idle antes de considerar parar
}
'''

import subprocess
import sys


def run(cmd, desc=""):
    """Executa comando SSH no homelab."""
    full_cmd = f'ssh homelab@192.168.15.2 {cmd}'
    print(f"  → {desc or cmd}")
    result = subprocess.run(
        ['ssh', 'homelab@192.168.15.2', cmd],
        capture_output=True, text=True, timeout=30
    )
    if result.returncode != 0:
        print(f"  ⚠️ stderr: {result.stderr[:200]}")
    return result


def main():
    print("=" * 60)
    print("Patch Autoscaler v2 — Docker REAL")
    print("=" * 60)

    # 1. Backup
    print("\n[1/4] Backup do autoscaler.py original...")
    run("cp /home/homelab/myClaude/specialized_agents/autoscaler.py /home/homelab/myClaude/specialized_agents/autoscaler.py.bak",
        "Backup autoscaler.py")

    # 2. Escrever autoscaler v2
    print("\n[2/4] Aplicando autoscaler v2...")
    # Escape single quotes in the content for shell
    escaped = AUTOSCALER_V2.replace("'", "'\\''")
    run(f"cat > /home/homelab/myClaude/specialized_agents/autoscaler.py << 'AUTOSCALER_EOF'\n{AUTOSCALER_V2}\nAUTOSCALER_EOF",
        "Escrevendo autoscaler.py v2")

    # 3. Config fix
    print("\n[3/4] Corrigindo AUTOSCALING_CONFIG em config.py...")
    run("""python3 -c "
import re
path = '/home/homelab/myClaude/specialized_agents/config.py'
with open(path) as f:
    content = f.read()
# Replace AUTOSCALING_CONFIG block
new_config = '''AUTOSCALING_CONFIG = {
    \\"enabled\\": True,
    \\"min_agents\\": 2,
    \\"max_agents\\": 12,
    \\"cpu_scale_up_threshold\\": 50,
    \\"cpu_scale_down_threshold\\": 80,
    \\"scale_check_interval_seconds\\": 60,
    \\"scale_up_increment\\": 1,
    \\"scale_down_increment\\": 1,
    \\"cooldown_seconds\\": 120,
    \\"idle_timeout_seconds\\": 300,
}'''
pattern = r'AUTOSCALING_CONFIG\\s*=\\s*\\{[^}]+\\}'
content = re.sub(pattern, new_config, content)
with open(path, 'w') as f:
    f.write(content)
print('Config atualizado')
" """, "Patch config.py")

    # 4. Restart API
    print("\n[4/4] Reiniciando API...")
    run("sudo systemctl restart specialized-agents-api", "Restart specialized-agents-api")

    print("\n✅ Patch aplicado com sucesso!")
    print("Aguarde 10s para a API reiniciar e execute a validacao.")


if __name__ == "__main__":
    main()
