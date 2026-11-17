# Chạy và kiểm chứng nguồn DB/API

Cập nhật 07/11/2026, Asia/Ho_Chi_Minh. Lệnh Linux dưới đây chạy từ root repo trên đúng VM.
Các kiểm tra nguồn không thay nghiệm thu flow NiFi. Không ghi secret vào command history, Git hoặc evidence.

## 1. Kiểm thử mã nguồn

Trên Windows có Python 3.12:

~~~powershell
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r api/requirements-test.txt
.venv/Scripts/python.exe -m pytest -q -p no:cacheprovider --basetemp=.tools/pytest-tmp tests
~~~

Trên Ubuntu thay đường dẫn Python venv bằng .venv/bin/python.
Bộ test gồm hợp đồng API, hồi quy checker, HTTP loopback thật (endpoint chậm mất khoảng 10s),
và đối chiếu generator với SQL seed đã commit. Loopback không chứng minh Gunicorn/systemd hoặc NiFi hoạt động.

## 2. DB trên VM2

Dùng schema/seed và grants theo [sql/README.md](../sql/README.md). Để kiểm tra baseline:

~~~bash
sudo bash sql/verify_source.sh
sudo bash sql/verify_source.sh --check-seed-replay
~~~

Kết quả lần lượt phải là 10 PASS/0 FAIL và 11 PASS/0 FAIL, exit 0. Lần thứ hai chủ động
chạy lại INSERT IGNORE và so hash toàn bộ bảng; không reset dữ liệu đang phục vụ TC-08.

Khi có IP lab thật:
- Cài infra/db/zz-nt132.cnf vào /etc/mysql/mysql.conf.d/, đặt bind-address là IP VM2.
- Tạo bản cục bộ của sql/03_grants.sql.template, thay IP VM1/mật khẩu; giữ ngoài repo, mode 0600.
- Áp dụng bằng admin MySQL cục bộ, kiểm tra SHOW GRANTS. Template không thu hồi quyền đã có của
  tài khoản cũ; không suy ra chỉ SELECT từ việc GRANT thành công.
- Firewall 3306 chỉ cho IP VM1 theo inventory; giữ đường SSH/console trước khi đổi mạng.
- Restart MySQL, kiểm tra systemctl is-active mysql, ss -ltn và chạy lại verify_source.

## 3. Quyền DB và kết nối từ VM1

VM1 cần mysql client. Tạo client config ngoài repo, chỉ chủ sở hữu đọc được:

~~~ini
[client]
user=db_reader
password=<DB_READER_PASSWORD>
~~~

~~~bash
chmod 600 /path/reader.cnf
bash sql/verify_reader.sh --defaults-extra-file=/path/reader.cnf --host=db.lab --protocol=TCP
~~~

Mong đợi 5 PASS/0 FAIL, exit 0. SELECT nguồn phải thành công trước khi kiểm tra quyền bị từ chối.
Các câu INSERT/UPDATE/DELETE dùng WHERE 1=0, không thay đổi dòng nào kể cả khi quyền bị cấp quá rộng.
Chỉ lỗi MySQL 1142/1143 được tính là từ chối quyền; lỗi kết nối hay sai SQL làm test FAIL.
Đây là kiểm tra MySQL client; TC-03 vẫn cần JDBC từ NiFi thật.

## 4. API trên VM4

~~~bash
sudo bash api/deploy/install.sh 127.0.0.1:5000
sudo bash api/deploy/smoke_test.sh
~~~

Installer giữ key đã có, kiểm tra systemd active và /health đúng JSON trước khi exit 0.
Smoke test không in body/key, exit 1 nếu có check FAIL, exit 2 nếu cấu hình không hợp lệ.
Lab bật có 14 checks, gồm /api/slow >=9.5s; lab tắt có 10 checks và cả hai endpoint test phải 404.
NT132_LAB_TEST_ENDPOINTS đọc từ /etc/nt132-api/api.env; restart service sau khi sửa env.

Khi có IP VM4, chạy lại installer với <IP_VM4>:5000 và cấu hình firewall 5000 chỉ cho IP VM1.
Có thể gọi checker trực tiếp sau khi cài:

~~~bash
sudo python3 /opt/nt132-api/deploy/smoke_test.py --env-file /etc/nt132-api/api.env
~~~

Từ VM1, nạp key bằng cơ chế secret cục bộ vào NT132_API_KEY (không gõ giá trị vào lệnh được lưu/log),
đặt NT132_LAB_TEST_ENDPOINTS khớp VM4, rồi chạy:

~~~bash
bash api/deploy/smoke_test.sh http://api.lab:5000
~~~

Checker đối chiếu fixture baseline. Nếu sửa ca để kiểm tra TC-13, lưu và phục hồi fixture
sau test trước khi chạy baseline. Không chuyển transform từ NiFi sang API.

## 5. Evidence và phần còn chờ

Lưu timestamp có offset, hostname/OS, phiên bản MySQL/Python/Gunicorn, lệnh không chứa secret,
stdout/stderr và exit code; kiểm tra log/ảnh trước khi đưa vào evidence/.
Nếu dùng tee, bật set -o pipefail để không che exit code lỗi.
Không chép api.env, reader.cnf hoặc grants có mật khẩu vào evidence.

| Test | Còn phải chứng minh |
|---|---|
| TC-03/04/05 | JDBC/HTTP từ VM1; firewall allow/deny; tài khoản nguồn đúng quyền |
| TC-06/07 | NiFi đọc 50 và lọc còn 45 active, masking và output đúng |
| TC-08/09 | Snapshot phản ánh sửa nguồn; DB lỗi rồi phục hồi |
| TC-10..13 | NiFi chuẩn hóa ca; xử lý 401, retry hữu hạn với 500/timeout/offline, dead-letter/reprocess |
| TC-27 | Reboot VM2/VM4, service tự chạy và NiFi kết nối lại |

Cập nhật sau khi bật VM 07/11: TCP 127.0.0.1:2222/2223 đã mở, user hai VM là trung.
SSH có host key cục bộ tin cậy nhưng BatchMode bị từ chối (exit 255): Windows chưa có private key/agent.
Khóa riêng nt132_lab_ed25519 được chuẩn bị trong thư mục .ssh của người dùng Windows, ngoài repo.
Trong PowerShell của người dùng tại root repo, chạy một lần:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\authorize_lab_ssh.ps1
~~~

Script chỉ thêm public key vào authorized_keys của trung trên hai VM, giữ key cũ, chạy lại không thêm trùng.
Nhập mật khẩu Ubuntu tại prompt SSH cho từng VM; không gửi vào chat hoặc ghi vào file.
Sau đó agent dùng khóa lab xác minh hostname/quyền sudo và triển khai. Chưa có endpoint NiFi.

## 6. Run VM2/VM4 qua SSH cục bộ (10/11/2026)

SSH key đã được cấp và kiểm tra thành công. Từ bản source đã copy lên đúng VM:

```bash
# VM2 db: chỉ SELECT, không replay seed hoặc thay tài khoản
sudo bash scripts/check_db_vm.sh
# VM4 api: backup source/unit, cài bản sửa, giữ env/key/bind rồi chạy smoke
sudo bash scripts/check_api_vm.sh
```

DB in thêm `total/active/resigned`, số phòng ban, `mysql_tz` và `SHOW VARIABLES LIKE 'have_ssl'`.
TLS `DISABLED` cần báo Trường; script không thay cấu hình TLS. Chỉ khi chủ động kiểm thử mở rộng
mới dùng `check_db_vm.sh --extended` (replay seed và tạo/xóa tài khoản reader localhost tạm).

Agent chuẩn bị `.tools/vm-current-run.json`, sau đó người dùng chạy
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify_lab_vms.ps1`
để nhập mật khẩu sudo tại terminal cho từng VM. Log nằm trong thư mục `evidence/` của run trên VM,
chỉ thu log kết quả; không copy `/etc/nt132-api/api.env`.
