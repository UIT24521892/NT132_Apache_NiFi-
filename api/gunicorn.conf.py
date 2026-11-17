# Gunicorn cho API nguồn (VM4). Bind lấy từ env để chỉ nghe IP lab, không nghe 0.0.0.0.
import os

bind = os.environ.get("NT132_API_BIND", "127.0.0.1:5000")
workers = 2
worker_class = "gthread"
threads = 4            # /api/slow giữ 1 thread 10s, không chặn request khác
timeout = 30
accesslog = "-"        # stdout -> journald; format mặc định không ghi header nên không lộ key
errorlog = "-"
loglevel = "info"
