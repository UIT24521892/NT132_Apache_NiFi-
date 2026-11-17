# Kiểm chứng bản sửa DB/API — 10/11/2026

- Môi trường: HOST-WIN-A, Windows, Python 3.12.16 trong `.venv`.
- Nhánh: `trung/db-api`, nền `17533fa` và bản sửa trong working tree.
- Thời gian: 10/11/2026, khoảng 20:16–20:17, UTC+07:00 (Asia/Bangkok).

Lệnh chạy từ root repo:

```powershell
.venv/Scripts/python.exe -B -m pytest -q -p no:cacheprovider --basetemp=.tools/pytest-tmp-20261110 --junitxml=.tools/pytest-2026-11-10.xml tests
```

Kết quả: **33 passed in 46.13s**, exit 0. JUnit: [local-db-api-2026-11-10.junit.xml](local-db-api-2026-11-10.junit.xml).
Bao gồm hợp đồng API, hồi quy checker, HTTP loopback thật với lab bật/tắt, endpoint chậm và generator SQL.
Lần đầu dùng thư mục tạm mặc định bị `PermissionError` trong setup `tmp_path` (32 passed/1 error);
chuyển `--basetemp` vào workspace giải quyết hạn chế quyền, không cần sửa logic ứng dụng/test.

Kiểm tra cú pháp Git Bash `bash -n` cho installer, smoke wrapper, hai verifier SQL và hai script
`scripts/check_{db,api}_vm.sh` đều exit 0. Kiểm tra cú pháp không chứng minh dịch vụ đã triển khai.

Hai VM `db`/`api` được bật bằng VirtualBox headless; SSH bằng khóa lab vào đúng hostname và user `trung` thành công.
`sudo -n true` trên cả hai trả `sudo: a password is required`. Triển khai đặc quyền và kiểm tra MySQL
chờ nhập mật khẩu tại terminal cục bộ; không thu mật khẩu trong chat hoặc evidence.

Các test nghiệm thu NiFi vẫn `NOT_RUN`.
