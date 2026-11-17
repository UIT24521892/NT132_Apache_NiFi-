"""API nguồn ca làm việc cho PG-REST (SPECS 5.3).

Chỉ trả dữ liệu thô giả; mọi chuẩn hóa (đổi tên field, HH:mm:ss, validate) do NiFi làm.
Cấu hình qua biến môi trường (file env mode 0600, nạp bởi systemd):
  NT132_API_KEY              bắt buộc; NiFi gửi trong header X-API-Key
  NT132_LAB_TEST_ENDPOINTS   "1" để bật /api/slow và /api/error (chỉ dùng trong lab)
  NT132_SHIFTS_FILE          đường dẫn fixture, mặc định data/shifts.json cạnh app.py
"""
import hmac
import json
import os
import time
from pathlib import Path

from flask import Flask, abort, jsonify, request

BASE_DIR = Path(__file__).resolve().parent


def create_app():
    app = Flask(__name__)
    app.json.ensure_ascii = False  # giữ nguyên tiếng Việt UTF-8
    app.json.sort_keys = False

    api_key = os.environ.get("NT132_API_KEY", "")
    if len(api_key) < 16:
        raise RuntimeError("NT132_API_KEY chưa đặt hoặc quá ngắn (>= 16 ký tự)")
    lab_tests = os.environ.get("NT132_LAB_TEST_ENDPOINTS", "0") == "1"
    shifts_file = Path(os.environ.get("NT132_SHIFTS_FILE", BASE_DIR / "data" / "shifts.json"))

    def load_shifts():
        # Đọc lại mỗi request: sửa fixture (TC-13) có hiệu lực ngay, không cần restart.
        with open(shifts_file, encoding="utf-8") as f:
            return json.load(f)["shifts"]

    def require_key():
        given = request.headers.get("X-API-Key", "")
        # So sánh thời gian hằng; không bao giờ echo key trong phản hồi/log.
        if not given or not hmac.compare_digest(given.encode(), api_key.encode()):
            abort(401)

    @app.get("/health")
    def health():
        return jsonify(status="ok")

    @app.get("/api/shifts")
    def list_shifts():
        require_key()
        return jsonify(shifts=load_shifts())

    @app.get("/api/shifts/<shift_id>")
    def get_shift(shift_id):
        require_key()
        for s in load_shifts():
            if s["id"] == shift_id:
                return jsonify(s)
        abort(404)

    if lab_tests:
        @app.get("/api/slow")
        def slow():
            require_key()
            time.sleep(10)
            return jsonify(status="slow-ok")

        @app.get("/api/error")
        def error():
            require_key()
            return jsonify(error="simulated_server_error"), 500

    for code, name in [(401, "unauthorized"), (404, "not_found"), (405, "method_not_allowed")]:
        app.register_error_handler(code, lambda e, n=name, c=code: (jsonify(error=n), c))

    @app.errorhandler(500)
    def internal(e):
        return jsonify(error="internal_error"), 500

    return app


app = create_app() if os.environ.get("NT132_API_KEY") else None
