#!/usr/bin/env bash
# Kiểm tra nhanh API trên chính VM4. Đọc key từ file env (cần sudo), không in key ra màn hình.
# Dùng: sudo bash smoke_test.sh [http://127.0.0.1:5000]
set -uo pipefail
BASE="${1:-http://$(sudo sed -n 's/^NT132_API_BIND=//p' /etc/nt132-api/api.env)}"
KEY="$(sudo sed -n 's/^NT132_API_KEY=//p' /etc/nt132-api/api.env)"
pass=0; fail=0
check() { # tên, mã mong đợi, curl args...
  local name=$1 want=$2; shift 2
  local got; got=$(curl -s -o /tmp/smoke.out -w '%{http_code}' --max-time 15 "$@")
  if [[ $got == "$want" ]]; then echo "PASS  $name -> $got  $(head -c 120 /tmp/smoke.out)"; pass=$((pass+1))
  else echo "FAIL  $name -> $got (mong đợi $want)  $(head -c 120 /tmp/smoke.out)"; fail=$((fail+1)); fi
}
echo "Base: $BASE   $(date -Iseconds)"
check "health"            200 "$BASE/health"
check "shifts có key"     200 -H "X-API-Key: $KEY" "$BASE/api/shifts"
check "shift S1"          200 -H "X-API-Key: $KEY" "$BASE/api/shifts/S1"
check "shift S9"          404 -H "X-API-Key: $KEY" "$BASE/api/shifts/S9"
check "thiếu key"         401 "$BASE/api/shifts"
check "sai key"           401 -H "X-API-Key: wrong-key-123" "$BASE/api/shifts"
check "error (lab)"       500 -H "X-API-Key: $KEY" "$BASE/api/error"
start=$(date +%s); check "slow (lab, ~10s)" 200 -H "X-API-Key: $KEY" "$BASE/api/slow"; echo "      slow mất $(( $(date +%s)-start ))s"
grep -q "wrong-key-123" /tmp/smoke.out && { echo "FAIL  phản hồi có echo key"; fail=$((fail+1)); }
echo "Tổng: $pass PASS, $fail FAIL"
