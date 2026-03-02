#!/usr/bin/env python3
"""Run all selenium tests sequentially."""
import sys
import importlib
import time
from pathlib import Path

# Ensure project root is on sys.path so `tests` package can be imported
proj_root = str(Path(__file__).resolve().parents[2])
if proj_root not in sys.path:
    sys.path.insert(0, proj_root)

TESTS = [
    'test_auth',
    'test_create_event',
    'test_checkin',
]


def run_all(base_url: str):
    failures = []
    for mod in TESTS:
        print('Running', mod)
        m = importlib.import_module(f'tests.selenium.{mod}', package=None)
        try:
            # most tests expose run(url, headless=False)
            m.run(base_url, headless=False)
            print(mod, 'OK')
        except Exception as e:
            print(mod, 'FAILED:', e)
            failures.append((mod, e))
        time.sleep(1)

    if failures:
        print('Some tests failed:')
        for mod, e in failures:
            print(mod, e)
        sys.exit(2)
    print('All tests passed')


if __name__ == '__main__':
    base = 'http://localhost:34951/#/events'
    run_all(base)
