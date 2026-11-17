#!/usr/bin/env bash
# Chạy bằng sudo trên VM2 db; không reset dữ liệu, không đổi mạng/firewall.
# Mặc định chỉ đọc. --extended kiểm tra thêm seed replay và user reader tạm.
set -euo pipefail
[[ $EUID -eq 0 && $(hostname -s) == db ]] || { echo "FAIL: cần sudo trên đúng VM db"; exit 1; }
extended=0
case ${1:-} in
  '') ;;
  --extended) extended=1 ;;
  *) echo "Dùng: sudo bash scripts/check_db_vm.sh [--extended]" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { echo "FAIL: quá nhiều đối số" >&2; exit 2; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
umask 077
mkdir -p "$ROOT/evidence"
chown trung:trung "$ROOT/evidence"
LOG="$ROOT/evidence/vm-db.log"
exec > >(tee "$LOG") 2>&1
reader_created=0
reader_config=
finish() {
  result=$?
  trap - EXIT
  if [[ $reader_created -eq 1 ]]; then
    if ! mysql --execute="DROP USER 'db_reader'@'localhost'"; then
      echo "FAIL: chưa xóa được tài khoản kiểm thử localhost"; result=1
    fi
  fi
  if [[ -n $reader_config ]]; then rm -f -- "$reader_config"; fi
  echo "RUN_EXIT=$result"
  chown trung:trung "$LOG"
  chmod 600 "$LOG"
  exit "$result"
}
trap finish EXIT
echo "Task: DB source checks (không phải JDBC/NiFi acceptance)"
date -Iseconds
hostname
mysql --version
systemctl is-active mysql
systemctl is-enabled mysql
source_args=()
if [[ $extended -eq 1 ]]; then source_args+=(--check-seed-replay); fi
bash "$ROOT/sql/verify_source.sh" "${source_args[@]}"
mysql --table --execute="SELECT COUNT(*) AS total, SUM(status='active') AS active, SUM(status='resigned') AS resigned FROM hr_db.employees; SELECT COUNT(*) AS departments FROM hr_db.departments; SELECT @@global.time_zone AS mysql_tz;"
mysql --table --execute="SHOW VARIABLES LIKE 'have_ssl'"
tls="$(mysql --batch --skip-column-names --execute="SHOW VARIABLES LIKE 'have_ssl'")"
tls=${tls##*$'\t'}
case $tls in
  YES) echo "MYSQL_TLS=YES" ;;
  DISABLED) echo "MYSQL_TLS=DISABLED: báo Trường để chốt tham số JDBC/NiFi." ;;
  *) echo "FAIL: chưa xác định được MySQL TLS"; exit 1 ;;
esac
if [[ $extended -eq 1 ]]; then
existing="$(mysql --batch --skip-column-names --execute="SELECT COUNT(*) FROM mysql.user WHERE User='db_reader' AND Host='localhost'")"
if [[ $existing -ne 0 ]]; then
  echo "LOCAL_READER_TEST=NOT_RUN: db_reader@localhost đã tồn tại; không đổi mật khẩu/quyền của tài khoản cũ."
else
  reader_password="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
  mysql <<SQL
CREATE USER 'db_reader'@'localhost' IDENTIFIED BY '$reader_password';
SQL
  reader_created=1
  # Áp dụng đúng GRANT từ template, sau khi đã tạo tài khoản test mới an toàn.
  sed -e '/^CREATE USER /d' -e 's/<IP_VM1>/localhost/g' "$ROOT/sql/03_grants.sql.template" | mysql >/dev/null
  reader_config="$(mktemp /run/nt132-reader.XXXXXX)"
  printf '[client]\nuser=db_reader\npassword=%s\n' "$reader_password" > "$reader_config"
  unset reader_password
  chmod 600 "$reader_config"
  bash "$ROOT/sql/verify_reader.sh" --defaults-extra-file="$reader_config"
  echo "LOCAL_READER_TEST=PASS (socket localhost; chưa thay TC-05 từ VM1)"
fi
else
  echo "EXTENDED_CHECKS=NOT_RUN (mặc định chỉ đọc DB)"
fi
ss -ltn
echo "DB_SOURCE_CHECKS=PASS"
