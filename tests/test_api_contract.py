"""Test hợp đồng API nguồn (SPECS 5.3) bằng Flask test client — KHÔNG thay thế kiểm thử
tích hợp NiFi (TC-10..TC-13). Chạy: NT132 venv có pytest; `python -m pytest tests/test_api_contract.py`"""
import importlib
import sys
from pathlib import Path

import pytest

KEY = "test-key-0123456789abcdef"
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "api"))


@pytest.fixture()
def client(monkeypatch):
    monkeypatch.setenv("NT132_API_KEY", KEY)
    monkeypatch.setenv("NT132_LAB_TEST_ENDPOINTS", "1")
    import app as app_module
    importlib.reload(app_module)
    return app_module.create_app().test_client()


def test_health_no_key(client):
    r = client.get("/health")
    assert r.status_code == 200 and r.get_json() == {"status": "ok"}


def test_shifts_snapshot(client):
    r = client.get("/api/shifts", headers={"X-API-Key": KEY})
    assert r.status_code == 200
    shifts = r.get_json()["shifts"]
    got = {(s["id"], s["start"], s["end"], s["grace"]) for s in shifts}
    assert got == {("S1", "08:00", "17:00", 10), ("S2", "06:00", "14:00", 0), ("S3", "14:00", "22:00", 0)}
    assert "Ca hành chính" in r.get_data(as_text=True)  # UTF-8 thật, không \\u escape


@pytest.mark.parametrize("headers", [{}, {"X-API-Key": "wrong-key-xxxxxxxxxxxx"}, {"X-API-Key": ""}])
@pytest.mark.parametrize("path", ["/api/shifts", "/api/shifts/S1", "/api/slow", "/api/error"])
def test_missing_or_wrong_key_401_no_echo(client, headers, path):
    r = client.get(path, headers=headers)
    assert r.status_code == 401
    assert r.get_json() == {"error": "unauthorized"}
    assert "wrong-key" not in r.get_data(as_text=True)


def test_shift_by_id_and_404(client):
    assert client.get("/api/shifts/S2", headers={"X-API-Key": KEY}).get_json()["start"] == "06:00"
    r = client.get("/api/shifts/S9", headers={"X-API-Key": KEY})
    assert r.status_code == 404 and r.get_json() == {"error": "not_found"}


def test_error_endpoint_500(client):
    r = client.get("/api/error", headers={"X-API-Key": KEY})
    assert r.status_code == 500 and r.is_json


def test_lab_endpoints_off_by_default(monkeypatch):
    monkeypatch.setenv("NT132_API_KEY", KEY)
    monkeypatch.setenv("NT132_LAB_TEST_ENDPOINTS", "0")
    import app as app_module
    c = app_module.create_app().test_client()
    assert c.get("/api/error", headers={"X-API-Key": KEY}).status_code == 404


def test_refuses_to_start_without_key(monkeypatch):
    monkeypatch.delenv("NT132_API_KEY", raising=False)
    import app as app_module
    with pytest.raises(RuntimeError):
        app_module.create_app()
