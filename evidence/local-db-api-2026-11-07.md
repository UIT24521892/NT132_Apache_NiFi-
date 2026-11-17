# Kiểm chứng mã nguồn DB/API — 07/11/2026

- Test run: 2026-11-07T14:55:51.704846+07:00, Asia/Ho_Chi_Minh.
- Host: Windows 11, build 26200, x86_64. Python 3.12.16 trong .venv.
- Flask 3.1.2, Werkzeug 3.1.9, pytest 8.3.5; Gunicorn 23.0.0 đã cài nhưng không chạy trên Windows.
- Git Bash 5.2.37. Source nền: commit 17533fa + working tree của đợt sửa DB/API.
- Không có secret thật trong test: dùng key kiểm thử cố định trong tests/.

## LOCAL-01 — API contract và hồi quy checker

Command:
~~~powershell
.venv/Scripts/python.exe -B -m pytest -q -p no:cacheprovider tests --junitxml=.tools/pytest.xml
~~~

Expected: tất cả test đạt, exit 0.
Actual: **33 passed in 14.36s**, exit 0; JUnit ghi 33 tests, 0 failures, 0 errors, 0 skipped.
JUnit: [local-db-api-2026-11-07.junit.xml](local-db-api-2026-11-07.junit.xml).

Bao gồm 26 ca kiểm thử API và 7 ca kiểm thử nguồn/checker. HTTP loopback khởi chạy ứng dụng Flask thật
trên port tự cấp, dùng urllib gửi request thật; lab bật 14 checks, lab tắt 10 checks.
Endpoint chậm chạy sleep(10) thực và phải đạt >=9.5s. Test contract riêng có stub sleep
để kiểm tra nhánh xử lý; không dùng stub đó làm bằng chứng thời lượng.
Các case offline/echo key/slow quá nhanh dùng response giả để kiểm tra checker phát hiện lỗi.
Generator seed sinh lại khớp đúng SQL đã commit.

## LOCAL-02 — Cú pháp shell

Command (Git Bash -n qua đường dẫn đầy đủ trên Windows):
~~~text
bash -n api/deploy/install.sh
bash -n api/deploy/smoke_test.sh
bash -n sql/verify_source.sh
bash -n sql/verify_reader.sh
~~~

Expected/actual: cả 4 lệnh exit 0. Không chạy apt/systemd hoặc kết nối MySQL trong kiểm tra này.

## LOCAL-03 — Exit code CLI checker

Thực hiện 2026-11-07T14:57:19+07:00, key giả nạp vào môi trường; không in key.

~~~text
python -B api/deploy/smoke_test.py http://127.0.0.1:1 --env-file .tools/no-env-file --timeout 0.2
~~~

Expected: nguồn offline làm checker trả 1. Actual: 0 PASS, 14 FAIL, exit **1**.
Đây là test checker xử lý lỗi đúng, không phải nguồn API đang hoạt động.

Thử thêm URL chứa credential giả: checker từ chối cấu hình, chỉ in thông báo chung, exit **2**.
Không ghi URL có credential vào log evidence.

## Phạm vi chưa kiểm chứng

- Chưa chạy sql/99_verify.sql, verify_source.sh, verify_reader.sh với MySQL thật.
- Chưa áp dụng installer mới lên VM4, chưa kiểm tra Gunicorn/systemd/firewall/reboot.
- SSH lịch sử 127.0.0.1:2222/2223 chưa kết nối được; chưa có endpoint NiFi.
- TC-01..TC-30 giữ NOT_RUN cho nghiệm thu tích hợp; LOCAL-01..03 không thay các TC này.
- Các tiến độ VM2/VM4 ngày 06/11 là ghi nhận cũ, chưa được kiểm chứng lại trong đợt này.

Bàn giao: [DB_API_RUNBOOK.md](../docs/DB_API_RUNBOOK.md), [MANUAL_ACTIONS.md](../docs/MANUAL_ACTIONS.md).
