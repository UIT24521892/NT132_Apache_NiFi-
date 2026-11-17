#!/usr/bin/env bash
# VM1: bash sql/verify_reader.sh --defaults-extra-file=/path/reader.cnf --host=db.lab --protocol=TCP
# Chỉ SELECT và các lệnh ghi WHERE 1=0 (không có dòng nào bị thêm/sửa/xóa, kể cả cấp quyền sai).
# Không dùng password trên CLI. Client config giữ ngoài repo, mode 0600.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
command -v mysql >/dev/null || { echo "FAIL: thiếu mysql client" >&2; exit 1; }
mysql_cmd=(mysql "$@" --batch --skip-column-names --default-character-set=utf8mb4)
pass=0; fail=0
echo "Timestamp: $(date -Iseconds)"
identity="$("${mysql_cmd[@]}" --execute='SELECT CURRENT_USER()')"
[[ $identity == db_reader@* ]] || { echo "FAIL: phải dùng tài khoản db_reader" >&2; exit 1; }
"${mysql_cmd[@]}" < "$SCRIPT_DIR/10_nifi_select_employees.sql" >/dev/null
echo "PASS source_select"; pass=$((pass+1))
expect_denied() {
  local label=$1 statement=$2 error_text
  if error_text="$("${mysql_cmd[@]}" --execute="$statement" 2>&1)"; then
    echo "FAIL $label: được cấp quyền ngoài yêu cầu"; fail=$((fail+1))
  elif [[ $error_text =~ ERROR\ (1142|1143)\  ]]; then
    echo "PASS $label: permission denied"; pass=$((pass+1))
  else
    echo "FAIL $label: lỗi khác permission denied"; fail=$((fail+1))
  fi
}
expect_denied insert "INSERT INTO hr_db.employees (employee_id) SELECT 'E9999' WHERE 1=0"
expect_denied update "UPDATE hr_db.employees SET full_name=full_name WHERE 1=0"
expect_denied delete "DELETE FROM hr_db.employees WHERE 1=0"
expect_denied sensitive_column "SELECT base_salary FROM hr_db.employees LIMIT 0"
echo "Total: $pass PASS, $fail FAIL"
[[ $fail -eq 0 ]]
