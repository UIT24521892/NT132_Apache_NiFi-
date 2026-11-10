#!/usr/bin/env bash
# VM2: sudo bash sql/verify_source.sh
# --check-seed-replay chạy lại INSERT IGNORE, chỉ dùng lab baseline trước TC-08.
# Các đối số còn lại chuyển cho mysql; dùng defaults-extra-file thay password trên CLI.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
replay=0
if [[ ${1:-} == --check-seed-replay ]]; then replay=1; shift; fi
command -v mysql >/dev/null || { echo "FAIL: thiếu mysql client" >&2; exit 1; }
mysql_cmd=(mysql "$@" --batch --skip-column-names --default-character-set=utf8mb4)
pass=0; fail=0
echo "Timestamp: $(date -Iseconds)"
if ! report="$("${mysql_cmd[@]}" < "$SCRIPT_DIR/99_verify.sql")"; then
  echo "FAIL: không đọc được schema/seed hr_db" >&2
  exit 1
fi
while IFS=$'\t' read -r name status actual; do
  if [[ $status == PASS ]]; then
    echo "PASS $name ($actual)"; pass=$((pass+1))
  else
    echo "FAIL $name ($actual)"; fail=$((fail+1))
  fi
done <<< "$report"
if [[ $((pass+fail)) -ne 10 ]]; then echo "FAIL: thiếu kết quả kiểm tra"; fail=$((fail+1)); fi
if [[ $replay -eq 1 && $fail -eq 0 ]]; then
  command -v sha256sum >/dev/null || { echo "FAIL: thiếu sha256sum" >&2; exit 1; }
  snapshot_sql='SELECT * FROM hr_db.departments ORDER BY department_id; SELECT * FROM hr_db.employees ORDER BY employee_id;'
  before="$("${mysql_cmd[@]}" --execute="$snapshot_sql" | sha256sum)"
  "${mysql_cmd[@]}" < "$SCRIPT_DIR/02_seed.sql"
  after="$("${mysql_cmd[@]}" --execute="$snapshot_sql" | sha256sum)"
  if [[ $before == "$after" ]]; then echo "PASS seed_replay_preserves_content"; pass=$((pass+1))
  else echo "FAIL seed_replay_changed_content"; fail=$((fail+1)); fi
fi
echo "Total: $pass PASS, $fail FAIL"
[[ $fail -eq 0 ]]
