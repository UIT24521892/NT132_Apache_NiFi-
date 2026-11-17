#!/usr/bin/env python3
"""Kiểm tra nguồn API thật bằng stdlib; không thay TC-10..TC-13 trong NiFi.

Không in response body, API key hoặc exception chứa thông tin kết nối.
Exit 0: tất cả checks đạt; 1: check thất bại; 2: cấu hình không hợp lệ.
"""
import argparse
import json
import os
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

EXPECTED_SHIFTS = [
    {"id": "S1", "name": "Ca hành chính", "start": "08:00", "end": "17:00", "grace": 10},
    {"id": "S2", "name": "Ca sáng", "start": "06:00", "end": "14:00", "grace": 0},
    {"id": "S3", "name": "Ca chiều", "start": "14:00", "end": "22:00", "grace": 0},
]
WRONG_KEY = "wrong-key-123"


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


@dataclass
class Response:
    status: int
    content_type: str
    body: bytes
    elapsed: float


def request_api(base, path, key, timeout):
    headers = {"X-API-Key": key} if key is not None else {}
    started = time.perf_counter()
    try:
        # Không gửi API key tiếp sang đích redirect.
        try:
            response = build_opener(NoRedirect).open(
                Request(base + path, headers=headers), timeout=timeout
            )
        except HTTPError as error:
            response = error
        with response:
            body = response.read(1024 * 1024 + 1)
            return Response(
                response.code, response.headers.get_content_type(), body,
                time.perf_counter() - started,
            )
    except (URLError, OSError, ValueError):
        return Response(0, "", b"", time.perf_counter() - started)


def run_checks(base, key, lab_tests, timeout=15, health_only=False, requester=request_api):
    passed = failed = 0

    def check(name, path, status, expected, sent_key=None, min_seconds=0):
        nonlocal passed, failed
        response = requester(base, path, sent_key, timeout)
        reasons = []
        if response.status != status:
            reasons.append("HTTP " + str(response.status) + ", expected " + str(status))
        if response.content_type != "application/json":
            reasons.append("Content-Type khong phai JSON")
        try:
            payload = json.loads(response.body)
            # So sánh cả kiểu: JSON 0.0/false không thay thế được integer 0.
            actual_json = json.dumps(payload, sort_keys=True, ensure_ascii=False)
            expected_json = json.dumps(expected, sort_keys=True, ensure_ascii=False)
            if actual_json != expected_json:
                reasons.append("JSON khong dung hop dong baseline")
        except (ValueError, UnicodeError):
            reasons.append("JSON khong doc duoc")
        if any(secret.encode("utf-8") in response.body for secret in (key, WRONG_KEY) if secret):
            reasons.append("response co echo credential")
        if response.elapsed < min_seconds:
            reasons.append("endpoint cham tra ve qua som")
        if reasons:
            failed += 1
            print("FAIL " + name + ": " + "; ".join(reasons))
        else:
            passed += 1
            print("PASS " + name)

    check("health", "/health", 200, {"status": "ok"})
    if not health_only:
        check("shifts", "/api/shifts", 200, {"shifts": EXPECTED_SHIFTS}, key)
        check("shift S1", "/api/shifts/S1", 200, EXPECTED_SHIFTS[0], key)
        check("shift S9", "/api/shifts/S9", 404, {"error": "not_found"}, key)
        protected = ["/api/shifts", "/api/shifts/S1"]
        if lab_tests:
            protected += ["/api/slow", "/api/error"]
        for path in protected:
            for label, sent_key in (("missing key", None), ("wrong key", WRONG_KEY)):
                check(label + " " + path, path, 401, {"error": "unauthorized"}, sent_key)
        if lab_tests:
            check("error lab", "/api/error", 500, {"error": "simulated_server_error"}, key)
            # Dung sai 0.5s cho phép đo; app vẫn phải sleep(10).
            check("slow lab >=9.5s", "/api/slow", 200, {"status": "slow-ok"}, key, 9.5)
        else:
            for path in ("/api/slow", "/api/error"):
                check("disabled " + path, path, 404, {"error": "not_found"}, key)
    print("Total: " + str(passed) + " PASS, " + str(failed) + " FAIL")
    return 1 if failed else 0


def read_env(path):
    values = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                name, separator, value = line.partition("=")
                if separator:
                    values[name.strip()] = value.strip().strip("\"'")
    return values


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base", nargs="?", help="http://<IP_VM4>:5000")
    parser.add_argument("--env-file", type=Path, default=Path("/etc/nt132-api/api.env"))
    parser.add_argument("--health-only", action="store_true", help="Readiness check cho installer")
    parser.add_argument("--timeout", type=float, default=15)
    args = parser.parse_args(argv)
    try:
        config = read_env(args.env_file)
        config.update({k: v for k, v in os.environ.items() if k.startswith("NT132_")})
        key = config.get("NT132_API_KEY", "")
        base = (args.base or "http://" + config.get("NT132_API_BIND", "127.0.0.1:5000")).rstrip("/")
        parts = urlsplit(base)
        if (parts.scheme not in ("http", "https") or not parts.hostname
                or parts.username is not None or parts.password is not None
                or parts.query or parts.fragment or args.timeout <= 0
                or (not args.health_only and len(key) < 16)):
            raise ValueError("invalid config")
        print("Timestamp: " + datetime.now().astimezone().isoformat(timespec="seconds"))
        # Không in URL do người gọi có thể vô tình đặt credential vào URL.
        return run_checks(base, key, config.get("NT132_LAB_TEST_ENDPOINTS", "0") == "1",
                          args.timeout, args.health_only)
    except (OSError, ValueError):
        print("ERROR: kiem tra env file, API key, base URL va timeout.", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
