#!/usr/bin/env bash
# Chạy bằng sudo trên VM4 api; cập nhật API nguồn và giữ nguyên bind/key/env.
set -euo pipefail
[[ $EUID -eq 0 && $(hostname -s) == api ]] || { echo "FAIL: cần sudo trên đúng VM api"; exit 1; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
umask 077
mkdir -p "$ROOT/evidence"
chown trung:trung "$ROOT/evidence"
LOG="$ROOT/evidence/vm-api.log"
exec > >(tee "$LOG") 2>&1
finish() {
  result=$?
  trap - EXIT
  echo "RUN_EXIT=$result"
  chown trung:trung "$LOG"
  chmod 600 "$LOG"
  exit "$result"
}
trap finish EXIT
echo "Task: API deploy + source smoke (không phải NiFi acceptance)"
date -Iseconds
hostname
python3 --version
ENV_FILE=/etc/nt132-api/api.env
[[ -f $ENV_FILE ]] || { echo "FAIL: thiếu env hiện có; cần kiểm tra trước khi triển khai"; exit 1; }
if ! cmp -s "$ROOT/api/data/shifts.json" /opt/nt132-api/data/shifts.json; then
  echo "FAIL: fixture trên VM khác baseline; giữ nguyên dữ liệu, chưa cập nhật."
  exit 1
fi
before_env="$(sha256sum "$ENV_FILE")"
BACKUP="$(mktemp -d /var/backups/nt132-api-before-check.XXXXXX)"
chmod 700 "$BACKUP"
cp -a /opt/nt132-api/app.py /opt/nt132-api/gunicorn.conf.py /opt/nt132-api/requirements.lock "$BACKUP/"
cp -a /etc/systemd/system/nt132-api.service "$BACKUP/"
echo "Backup source/unit: $BACKUP (không chứa API key)"
bash "$ROOT/api/deploy/install.sh"
after_env="$(sha256sum "$ENV_FILE")"
[[ $before_env == "$after_env" ]] || { echo "FAIL: nội dung env thay đổi"; exit 1; }
echo "PASS api_env_unchanged"
bash "$ROOT/api/deploy/smoke_test.sh"
systemctl show nt132-api -p User -p Group -p ActiveState -p SubState -p UnitFileState
stat -c '%U:%G %a %n' "$ENV_FILE"
ss -ltn
echo "API_SOURCE_CHECKS=PASS"
