#!/usr/bin/env bash
# Cài/cập nhật API nguồn trên VM4 (Ubuntu 24.04). Chạy lại an toàn; KHÔNG ghi đè API key đã có.
# Dùng: sudo bash install.sh [BIND]     ví dụ: sudo bash install.sh 127.0.0.1:5000
#       Khi có IP lab: sudo bash install.sh <IP_VM4>:5000
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"          # thư mục api/
BIND="${1:-}"
APP_DIR=/opt/nt132-api
ENV_DIR=/etc/nt132-api
ENV_FILE=$ENV_DIR/api.env
SVC_USER=nifi-source-api

[[ $EUID -eq 0 ]] || { echo "Cần chạy bằng sudo"; exit 1; }
apt-get install -y -q python3-venv >/dev/null

id -u "$SVC_USER" >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin "$SVC_USER"

install -d -m 755 -o root -g root "$APP_DIR" "$APP_DIR/data"
install -m 644 "$SRC/app.py" "$SRC/gunicorn.conf.py" "$SRC/requirements.lock" "$APP_DIR/"
install -m 644 "$SRC/data/shifts.json" "$APP_DIR/data/"
[[ -x $APP_DIR/venv/bin/pip ]] || python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install -q -r "$APP_DIR/requirements.lock"

install -d -m 750 -o root -g "$SVC_USER" "$ENV_DIR"
if [[ ! -f $ENV_FILE ]]; then
  umask 077
  cat > "$ENV_FILE" <<ENV
NT132_API_KEY=$(openssl rand -hex 32)
NT132_API_BIND=${BIND:-127.0.0.1:5000}
NT132_LAB_TEST_ENDPOINTS=1
ENV
  echo "Đã tạo $ENV_FILE với API key mới (xem: sudo cat $ENV_FILE)"
elif [[ -n $BIND ]]; then
  sed -i "s|^NT132_API_BIND=.*|NT132_API_BIND=$BIND|" "$ENV_FILE"
fi
chown root:"$SVC_USER" "$ENV_FILE"; chmod 640 "$ENV_FILE"

install -m 644 "$SRC/deploy/nt132-api.service" /etc/systemd/system/nt132-api.service
systemctl daemon-reload
systemctl enable nt132-api >/dev/null 2>&1
systemctl restart nt132-api
sleep 2
systemctl --no-pager --lines=5 status nt132-api || true
