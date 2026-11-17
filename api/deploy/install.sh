#!/usr/bin/env bash
# VM4 Ubuntu 24.04: sudo bash api/deploy/install.sh [<IP_VM4>:5000]
# Chạy lại giữ nguyên API key đã có. Exit khác 0 nếu service/health không sẵn sàng.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
BIND="${1:-}"
APP_DIR=/opt/nt132-api
ENV_DIR=/etc/nt132-api
ENV_FILE=$ENV_DIR/api.env
SVC_USER=nifi-source-api

[[ $EUID -eq 0 ]] || { echo "Cần chạy bằng sudo" >&2; exit 1; }
if [[ -n $BIND && ! $BIND =~ ^[A-Za-z0-9.-]+:[0-9]{1,5}$ ]]; then
  echo "BIND phải có dạng IPv4/hostname:port" >&2
  exit 1
fi
apt-get install -y -q python3-venv openssl >/dev/null
id -u "$SVC_USER" >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin "$SVC_USER"

install -d -m 755 -o root -g root "$APP_DIR" "$APP_DIR/data" "$APP_DIR/deploy"
install -m 644 "$SRC/app.py" "$SRC/gunicorn.conf.py" "$SRC/requirements.lock" "$APP_DIR/"
install -m 644 "$SRC/data/shifts.json" "$APP_DIR/data/"
install -m 644 "$SRC/deploy/smoke_test.py" "$SRC/deploy/smoke_test.sh" "$APP_DIR/deploy/"
[[ -x $APP_DIR/venv/bin/pip ]] || python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install -q -r "$APP_DIR/requirements.lock"

install -d -m 750 -o root -g "$SVC_USER" "$ENV_DIR"
if [[ ! -f $ENV_FILE ]]; then
  umask 077
  API_KEY="$(openssl rand -hex 32)"
  [[ ${#API_KEY} -eq 64 ]] || { echo "Không sinh được API key" >&2; exit 1; }
  cat > "$ENV_FILE" <<ENV
NT132_API_KEY=$API_KEY
NT132_API_BIND=${BIND:-127.0.0.1:5000}
NT132_LAB_TEST_ENDPOINTS=1
ENV
  unset API_KEY
  echo "Đã tạo $ENV_FILE; API key không được in ra log."
elif [[ -n $BIND ]]; then
  if grep -q '^NT132_API_BIND=' "$ENV_FILE"; then
    sed -i "s|^NT132_API_BIND=.*|NT132_API_BIND=$BIND|" "$ENV_FILE"
  else
    printf '\nNT132_API_BIND=%s\n' "$BIND" >> "$ENV_FILE"
  fi
fi
chown root:"$SVC_USER" "$ENV_FILE"
chmod 640 "$ENV_FILE"

install -m 644 "$SRC/deploy/nt132-api.service" /etc/systemd/system/nt132-api.service
systemctl daemon-reload
systemctl enable nt132-api >/dev/null
systemctl restart nt132-api
for attempt in {1..15}; do
  if systemctl is-active --quiet nt132-api &&
     "$APP_DIR/venv/bin/python" "$APP_DIR/deploy/smoke_test.py" \
       --env-file "$ENV_FILE" --health-only --timeout 2 >/dev/null 2>&1; then
    echo "PASS: nt132-api active, /health trả đúng JSON."
    exit 0
  fi
  sleep 1
done
echo "FAIL: API chưa sẵn sàng; xem sudo journalctl -u nt132-api --no-pager." >&2
systemctl --no-pager --lines=5 status nt132-api >&2 || true
exit 1
