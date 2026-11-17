"""Regression cho checker; HTTP loopback là lab cục bộ, không phải NiFi evidence."""
import importlib
import json
import os
import subprocess
import sys
import threading
from pathlib import Path

import pytest
from werkzeug.serving import make_server

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "api"))
sys.path.insert(0, str(ROOT / "api" / "deploy"))
checker = importlib.import_module("smoke_test")
KEY = "test-key-0123456789abcdef"


def test_checker_failure_returns_nonzero_without_echo(capsys):
    def offline(*args):
        return checker.Response(0, "", b"", 0)
    assert checker.run_checks("http://unused", KEY, True, requester=offline) == 1
    output = capsys.readouterr().out
    assert "0 PASS, 14 FAIL" in output and KEY not in output


@pytest.mark.parametrize("body", [
    b'{"status":"ok","leak":"wrong-key-123"}',
    b'{"status":"ok","leak":"test-key-0123456789abcdef"}',
])
def test_checker_detects_echo_in_current_response(body, capsys):
    def echoed(*args):
        return checker.Response(200, "application/json", body, 0)
    assert checker.run_checks("http://unused", KEY, False, health_only=True, requester=echoed) == 1
    output = capsys.readouterr().out
    assert "echo credential" in output
    assert KEY not in output and checker.WRONG_KEY not in output


def test_checker_rejects_too_fast_slow_endpoint(capsys):
    client_payloads = {
        "/health": (200, {"status": "ok"}),
        "/api/shifts": (200, {"shifts": checker.EXPECTED_SHIFTS}),
        "/api/shifts/S1": (200, checker.EXPECTED_SHIFTS[0]),
        "/api/shifts/S9": (404, {"error": "not_found"}),
        "/api/error": (500, {"error": "simulated_server_error"}),
        "/api/slow": (200, {"status": "slow-ok"}),
    }

    def too_fast(base, path, key, timeout):
        status, payload = client_payloads[path]
        if path != "/health" and key != KEY:
            status, payload = 401, {"error": "unauthorized"}
        return checker.Response(status, "application/json", json.dumps(payload).encode(), 0)
    assert checker.run_checks("http://unused", KEY, True, requester=too_fast) == 1
    assert "13 PASS, 1 FAIL" in capsys.readouterr().out


@pytest.mark.parametrize("lab_flag", ["0", "1"])
def test_checker_over_real_http(monkeypatch, capsys, lab_flag):
    monkeypatch.setenv("NT132_API_KEY", KEY)
    monkeypatch.setenv("NT132_LAB_TEST_ENDPOINTS", lab_flag)
    monkeypatch.delenv("NT132_SHIFTS_FILE", raising=False)
    application = importlib.import_module("app").create_app()
    server = make_server("127.0.0.1", 0, application, threaded=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        base = "http://127.0.0.1:" + str(server.server_port)
        assert checker.run_checks(base, KEY, lab_flag == "1") == 0
        output = capsys.readouterr().out
        assert ("14 PASS" if lab_flag == "1" else "10 PASS") in output
    finally:
        server.shutdown()
        thread.join(timeout=5)
        server.server_close()


def test_seed_generator_matches_committed_fixture():
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    result = subprocess.run(
        [sys.executable, "-B", str(ROOT / "sql" / "tools" / "gen_seed.py")],
        capture_output=True, text=True, encoding="utf-8", env=env, check=True,
    )
    assert result.stdout == (ROOT / "sql" / "02_seed.sql").read_text(encoding="utf-8")
