#!/usr/bin/env bash
# Chạy trên VM4: sudo bash api/deploy/smoke_test.sh [http://<IP_VM4>:5000]
# Có thể chạy từ VM1 với NT132_API_KEY trong môi trường, không ghi key vào lệnh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/smoke_test.py" "$@"
