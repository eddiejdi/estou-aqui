import subprocess
import sys


def test_no_token_exits_with_code_2():
    p = subprocess.Popen([sys.executable, 'tests/linkedin/daily_post_agent.py'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out, _ = p.communicate(timeout=10)
    assert p.returncode == 2
    assert b"Missing LINKEDIN_ACCESS_TOKEN" in out
