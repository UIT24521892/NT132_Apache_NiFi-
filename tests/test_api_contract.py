"""Kiểm thử nguồn API, không thay các test NiFi TC-10..TC-13."""
import importlib
import json
import sys
from pathlib import Path

import pytest

KEY = "test-key-0123456789abcdef"
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "api"))


@pytest.fixture()
def app_module(monkeypatch):
    monkeypatch.setenv("NT132_API_KEY", KEY)
    monkeypatch.setenv("NT132_LAB_TEST_ENDPOINTS", "1")
    monkeypatch.delenv("NT132_SHIFTS_FILE", raising=False)
    return importlib.import_module("app")


@pytest.fixture()
def client(app_module):
    return app_module.create_app().test_client()


def test_health_no_key(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_shifts_snapshot(client):
    response = client.get("/api/shifts", headers={"X-API-Key": KEY})
    assert response.status_code == 200
    payload = response.get_json()
    assert set(payload) == {"shifts"}
    shifts = payload["shifts"]
    assert type(shifts) is list and len(shifts) == 3
    assert len({shift["id"] for shift in shifts}) == 3
    expected = {
        "S1": ("Ca hành chính", "08:00", "17:00", 10),
        "S2": ("Ca sáng", "06:00", "14:00", 0),
        "S3": ("Ca chiều", "14:00", "22:00", 0),
    }
    for shift in shifts:
        assert set(shift) == {"id", "name", "start", "end", "grace"}
        assert all(type(shift[field]) is str for field in ("id", "name", "start", "end"))
        assert type(shift["grace"]) is int
        assert (shift["name"], shift["start"], shift["end"], shift["grace"]) == expected[shift["id"]]
    assert "Ca hành chính" in response.get_data(as_text=True)


@pytest.mark.parametrize("headers", [{}, {"X-API-Key": "wrong-key-xxxxxxxxxxxx"}, {"X-API-Key": ""}])
@pytest.mark.parametrize("path", ["/api/shifts", "/api/shifts/S1", "/api/slow", "/api/error"])
def test_missing_or_wrong_key_401_no_echo(client, headers, path):
    response = client.get(path, headers=headers)
    assert response.status_code == 401
    assert response.get_json() == {"error": "unauthorized"}
    assert KEY not in response.get_data(as_text=True)
    assert "wrong-key" not in response.get_data(as_text=True)


def test_shift_by_id_and_404(client):
    response = client.get("/api/shifts/S2", headers={"X-API-Key": KEY})
    assert response.status_code == 200
    assert response.get_json() == {
        "id": "S2", "name": "Ca sáng", "start": "06:00", "end": "14:00", "grace": 0,
    }
    response = client.get("/api/shifts/S9", headers={"X-API-Key": KEY})
    assert response.status_code == 404 and response.get_json() == {"error": "not_found"}


def test_error_endpoint_500(client):
    response = client.get("/api/error", headers={"X-API-Key": KEY})
    assert response.status_code == 500
    assert response.get_json() == {"error": "simulated_server_error"}


def test_slow_contract(client, app_module, monkeypatch):
    waits = []
    monkeypatch.setattr(app_module.time, "sleep", waits.append)
    response = client.get("/api/slow", headers={"X-API-Key": KEY})
    assert waits == [10]
    assert response.status_code == 200 and response.get_json() == {"status": "slow-ok"}
    # Thời lượng thực được kiểm tra qua HTTP trong test_source_checks.py.


@pytest.mark.parametrize("flag", [None, "0"])
@pytest.mark.parametrize("path", ["/api/error", "/api/slow"])
def test_lab_endpoints_disabled(app_module, monkeypatch, flag, path):
    monkeypatch.delenv("NT132_LAB_TEST_ENDPOINTS", raising=False)
    if flag is not None:
        monkeypatch.setenv("NT132_LAB_TEST_ENDPOINTS", flag)
    response = app_module.create_app().test_client().get(path, headers={"X-API-Key": KEY})
    assert response.status_code == 404


@pytest.mark.parametrize("key", [None, "", "short", "x" * 15])
def test_refuses_invalid_key(app_module, monkeypatch, key):
    monkeypatch.delenv("NT132_API_KEY", raising=False)
    if key is not None:
        monkeypatch.setenv("NT132_API_KEY", key)
    with pytest.raises(RuntimeError):
        app_module.create_app()


def test_fixture_changes_visible_without_restart(app_module, monkeypatch, tmp_path):
    fixture = tmp_path / "shifts.json"
    fixture.write_text(json.dumps({"shifts": [{"id": "S1", "name": "before"}]}), encoding="utf-8")
    monkeypatch.setenv("NT132_SHIFTS_FILE", str(fixture))
    client = app_module.create_app().test_client()
    assert client.get("/api/shifts/S1", headers={"X-API-Key": KEY}).get_json()["name"] == "before"
    fixture.write_text(json.dumps({"shifts": [{"id": "S1", "name": "after"}]}), encoding="utf-8")
    assert client.get("/api/shifts/S1", headers={"X-API-Key": KEY}).get_json()["name"] == "after"
