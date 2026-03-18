from pathlib import Path


def test_homelab_copilot_dockerfile_exists_with_python_runtime() -> None:
    content = Path("Dockerfile.homelab-copilot-agent").read_text()

    assert "FROM python:3.13-slim" in content
    assert "requirements-homelab-copilot-agent.txt" in content
    assert "advisor_agent_patch.py" in content
    assert "EXPOSE 8085" in content


def test_run_script_builds_image_and_mounts_eddie_auto_dev() -> None:
    content = Path("scripts/secrets-agent/run-homelab-copilot.sh").read_text()

    assert "docker image inspect" in content
    assert "Dockerfile.homelab-copilot-agent" in content
    assert "docker build" in content
    assert "EDDIE_AUTO_DEV_PATH=${EDDIE_AUTO_DEV_PATH:-/home/homelab/eddie-auto-dev}" in content
    assert '-v "$EDDIE_AUTO_DEV_PATH:/opt/eddie-auto-dev:ro"' in content
    assert '-e OLLAMA_MODEL="${OLLAMA_MODEL:-eddie-assistant:latest}"' in content
    assert '-e PYTHONPATH="/opt/eddie-auto-dev:/app"' in content


def test_systemd_sample_points_to_deploy_checkout() -> None:
    content = Path("scripts/systemd/homelab_copilot_agent.service.sample").read_text()

    assert "WorkingDirectory=/home/homelab/estou-aqui-deploy" in content
    assert "Environment=OLLAMA_MODEL=eddie-assistant:latest" in content
    assert "EDDIE_AUTO_DEV_PATH=/home/homelab/eddie-auto-dev" in content
    assert "/home/homelab/estou-aqui-deploy/scripts/secrets-agent/run-homelab-copilot.sh" in content