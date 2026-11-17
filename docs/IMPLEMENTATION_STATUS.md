# Trạng thái triển khai và kiểm chứng

Cập nhật: 17/11/2026 (Asia/Ho_Chi_Minh).

**17/11: chuyển cả 4 VM sang UTM Shared Network trên Mac. Agent đã cài và kiểm tra qua SSH ba VM
nguồn — db `192.168.64.102` (MySQL, verify 10/10 PASS), ftp `.103` (vsftpd, quyền reader/uploader đúng),
api `.104` (smoke 14/14 PASS). Kali tĩnh `.101`, từ Kali đọc được cả ba nguồn (db_reader 5/5 PASS);
ufw allow/deny đã thử; reboot cả 4 VM giữ IP/service. PG-REST và PG-JDBC đã chạy tới PutFile (bản demo đợt 1, chưa envelope/batch_id); PG-FTP chưa chạy.** Chi tiết: [evidence 17/11](../evidence/G2/2026-11-17_utm_source-vms.md).
Phần dưới từ 11/11 trở về trước giữ làm lịch sử.

**NiFi 2.12.0 đã chạy trên VM1 bằng JDK 21, systemd và HTTPS localhost; khung 5 PG đã
được dựng. Kali đã kết nối FTP qua hotspot, đăng nhập/list/download CSV bằng curl thành công;
chưa chạy processor nguồn trong NiFi. Mạng lab DB/API chưa hoàn tất.**
Cấu hình VM xem [DEPLOYMENT_ARCHITECTURE.md](DEPLOYMENT_ARCHITECTURE.md), cấu hình flow xem
[nifi/README.md](../nifi/README.md), việc còn thiếu xem [MANUAL_ACTIONS.md](MANUAL_ACTIONS.md).
Bản tổng hợp để đưa vào báo cáo: [Báo cáo tiến độ ngày 11/11](BAO_CAO_TIEN_DO_2026-11-11.md).

## Các gate nghiệm thu

| Gate | Phạm vi | Trạng thái | Kết quả hiện có / phần còn thiếu |
|---|---|---|---|
| G0 | Rà soát plan và specs | DONE_DOCUMENT_REVIEW | Đã rà soát; ngày 11/11 người dùng báo thầy yêu cầu dashboard, chưa chốt hình thức; chưa có rubric/phê duyệt phạm vi đầy đủ |
| G1 | Inventory, phiên bản, mạng/SSH | IN_PROGRESS | 17/11: UTM `192.168.64.0/24`, VM nguồn IP tĩnh `.102–.104`, Kali `.101`; host key/phiên bản đã ghi; SSH key cả 4 VM |
| G2 | NiFi và ba dịch vụ nguồn | IN_PROGRESS | 17/11: MySQL/vsftpd/API cài bằng script nhóm, bind IP lab, verify trên VM và từ Kali đạt, ufw đã thử; reboot 4 VM đạt; còn TLS lab và identities |
| G3 | Ba flow JDBC, REST, FTP | IN_PROGRESS | 17/11: PG-REST (3 ca) và PG-JDBC (45 active, đã mask) chạy tới PutFile; PG-FTP chưa chạy; flow export `nifi/flows/` ([evidence G3](../evidence/G3/2026-11-17_pg-rest-jdbc_first-run.md)) |
| G4 | Transform/output, rejected, retry, idempotency | NOT_RUN | Chưa có kết quả tích hợp theo hợp đồng dữ liệu |
| G5 | TLS/RBAC, Provenance, queues, restart, backup/restore | NOT_RUN | Reboot VM1 chỉ được người dùng xác nhận; chưa có bộ evidence vận hành/nghiệm thu |
| G6 | Báo cáo, slide, demo và bàn giao | IN_PROGRESS | Đã tổng hợp báo cáo tiến độ ngày 11/11; báo cáo cuối kỳ/slide/demo chưa nghiệm thu; thiếu rubric/format/deadline và hình thức dashboard |

## Tiến độ VM1 NiFi — 09–10/11/2026

Nguồn: output/ảnh Trường cung cấp, được chép lại tại
[evidence/G2/2026-11-09_vm1_nifi-bootstrap.md](../evidence/G2/2026-11-09_vm1_nifi-bootstrap.md).
Ảnh gốc ngày 09/11 không còn trong repo; còn ảnh PG-OUTPUT ngày 10/11.
Agent chưa đăng nhập VM1; SSH từ phiên công cụ tới hai IP VM1 timeout ngày 09/11.

| Hạng mục | Ghi nhận |
|---|---|
| Checksum, JDK/JRE, user `nifi` | Output được cung cấp: ZIP `OK`, JDK/JRE `21.0.13+9-1 arm64`, uid 999 / gid 981 |
| Service, HTTPS, thư mục | Output được cung cấp: `nifi.service` enabled/active bằng JDK 21; listener localhost:8443; output/rejected `nifi:nifi`, 0750 |
| Múi giờ | UI hiển thị `ICT` sau khi đổi từ PST |
| Parameter Context | Ảnh cho thấy `nt132-params` gán 5 PG; đủ 13 parameters, 3 sensitive là USER_CONFIRMED |
| Ports, 7 connections, back pressure 100 / 10 MB, expiration 0 | USER_CONFIRMED; chưa có ảnh canvas gốc hoặc flow export |
| PutFile | Có ảnh trong PG-OUTPUT, đang có cảnh báo chưa rõ nguyên nhân; smoke test và chạy lại vẫn 1 file (`ignore`) là USER_CONFIRMED |
| Đăng nhập UI, tự khởi động sau reboot | Đăng nhập UI: USER_CONFIRMED. Tự khởi động: 17/11 agent reboot qua SSH, `nifi` active, 8443 lên (E-UTM-07) |

Còn mở: sửa tên `PD-JDBC` → `PG-JDBC`, xem nguyên nhân cảnh báo PutFile, export flow,
thêm Controller Services/driver, đối chiếu host key và hoàn tất mạng/TLS/RBAC.

## Tiến độ mạng lab và FTP — 11/11/2026

Nguồn: ảnh/output người dùng gửi trong chat; bản chép lại tại
[evidence hotspot/FTP](../evidence/G2/2026-11-11_hotspot_ftp-connectivity.md).
Ảnh gốc chưa được lưu trong repo. Agent chỉ trực tiếp đọc IP Mac, chưa đăng nhập các VM.

| Hạng mục | Kết quả hiện có | Chưa kiểm chứng |
|---|---|---|
| Mạng hotspot | Mac `172.20.10.9/28`, Kali `172.20.10.10/28`, FTP `172.20.10.13/28`; gateway Kali `172.20.10.1`; UTM bridge Wi-Fi en0 | IP tĩnh, tất cả cặp máy, reconnect/reboot, firewall allow/deny |
| SSH và UI | Mac → Kali SSH được người dùng xác nhận; chọn dùng NiFi trực tiếp trong Kali | Host key; truy cập NiFi từ Mac qua tunnel chưa xác nhận thành công |
| Sự cố IP | Có lúc Kali nhận `172.30.239.242/16`, FTP báo No route to host; ảnh sau trở lại `172.20.10.10/28`, FTP thông | Chưa xác định nguyên nhân cấp IP 172.30.x.x |
| VM FTP | vsftpd active; xác nhận tên `clock_uploader`, `nifi_fetch` và remote path `/checkin` | Dải passive, firewall, quyền reader ghi/rename/delete bị từ chối |
| Kali → FTP | TCP 21 open, reader đăng nhập/list `/` và `/checkin/`, tải CSV 368 byte bằng curl passive | Chưa chạy ListFTP/FetchFTP hoặc cập nhật parameters trong NiFi |
| CSV tải về | `/tmp/nt132-ftp-check.csv`; header employee_id,timestamp,device_id; `wc -l` = 11 | Chưa parse toàn file, normalize hoặc đối chiếu 7 accepted / 1 duplicate / 2 rejected |
| VM DB Trung | Ảnh mới: enp0s3 DOWN, enp0s8 `10.0.3.15/24`, gateway `10.0.3.2` | Chưa nhận IP hotspot; bridge/DHCP, bind/grants/firewall và JDBC |
| VM API Trung | Chưa có IP lab mới | Kết nối qua hotspot và InvokeHTTP |
| Dashboard | Người dùng báo thầy yêu cầu; đã trao đổi phương án NiFi UI hoặc dashboard riêng | Chưa chốt hình thức/chỉ tiêu, chưa triển khai riêng |

IP hotspot là giá trị đã quan sát, có thể đổi theo DHCP. Kết quả curl là kiểm tra thành phần
hỗ trợ TC-03/TC-14, không phải PASS của flow NiFi hoặc toàn bộ hai TC này.

## Tiến độ VM nguồn theo báo cáo thành viên — nhận 09/11/2026

Agent chưa truy cập VM nguồn. Bảng dưới giữ báo cáo ngày 09/11; kết quả FTP và ảnh mạng DB
ngày 11/11 được bổ sung ở mục trên, không thay thế kiểm tra triển khai MySQL/API.

| Người / VM | Đã báo hoàn thành | Còn thiếu |
|---|---|---|
| Trung / VM2 DB | MySQL 8.0.46 autostart, `hr_db` seed 50/45/5 và 5 phòng ban | SQL verify, tạo grant theo IP VM1, bind/firewall mạng lab |
| Trung / VM4 API | Python 3.12.3, Gunicorn 23.0.0, service riêng; API key, 3 ca, endpoint lỗi/chậm; báo 33 test hợp đồng/loopback đạt | Bản sửa/test chưa push và chưa áp dụng vào service; bind/firewall mạng lab |
| Phước / VM3 FTP | vsftpd, uploader/reader, inbox, truyền passive; thử `.tmp` → `.csv` cục bộ | Xác nhận account/path/passive, thử reader không rename/delete, bật firewall; cấu hình/simulator/fixture chưa có trong repo |

Nhánh `origin/trung/db-api` được kiểm tra ngày 09/11 ở commit `17533fa` (06/11), có
`sql/`, `api/`, `infra/db/zz-nt132.cnf`, `tests/test_api_contract.py`. Đã merge vào `main` qua PR #1
(`4eacec3`) và được dùng để cài VM db/api trên UTM ngày 17/11.
Bộ 33 test do Trung báo không thay thế kiểm thử từ NiFi. Bàn giao cụ thể tại
[MA-07](MANUAL_ACTIONS.md#ma-07--đưa-artifact-vm-nguồn-vào-repo-và-hoàn-tất-kiểm-tra-cục-bộ).

## Trạng thái bộ test

**TC-01..TC-30 đều NOT_RUN**, định nghĩa tại [SPECS mục 8](../SPECS.md#8-nghiệm-thu-và-evidence).
Các kết quả bootstrap, xác nhận thành viên và curl FTP thành công chưa đủ để đánh PASS một
TC tích hợp; các phần đã kiểm tra được ghi riêng trong evidence ngày 11/11.

`USER_CONFIRMED` nghĩa là người dùng xác nhận nhưng chưa có evidence đầy đủ.
`PASS`/`FAIL` chỉ dùng khi đã chạy kiểm chứng có expected/actual và evidence cụ thể.
`PENDING_ENVIRONMENT` dùng khi thiếu đầu vào; `BLOCKED` cần có rào cản đã quan sát.

Khi chạy test, ghi: ID, thời điểm/timezone, VM/phiên bản, bước/lệnh, expected,
actual/exit code, đường dẫn evidence đã che secrets và việc còn lại.

## Lịch sử DB/API trên VirtualBox (Trung) — 06–10/11/2026

Các mục dưới đây giữ nguyên nhật ký của Trung khi VM2/VM4 còn chạy VirtualBox trên HOST-WIN-A.
Từ 17/11 VM db/api chạy trên UTM của Mac và được cài lại bằng chính `sql/` và `api/deploy/` này
(xem đầu file); các điều kiện SSH/sudo/mạng ghi bên dưới không còn áp dụng.

## Tiến độ VM2/VM4 trên HOST-WIN-A (Trung) — 06/11/2026

Trạng thái gate không đổi (G1 PENDING_ENVIRONMENT, G2 NOT_RUN) vì chưa có mạng lab, IP tĩnh,
firewall và kết nối từ VM1. Các kiểm tra dưới đây chỉ chạy **cục bộ trong từng VM**, không thay cho TC-03/TC-05.

| Hạng mục | Đã làm | Còn thiếu |
|---|---|---|
| HOST-WIN-A | Windows 11 Home, i9-12900H 20 luồng, RAM 15,7 GiB, ổ D trống 58 GiB, VirtualBox 7.2.20 (đang chạy trên nền Hyper-V/VBS), Wi-Fi Killer AX1650i | IP host trên hotspot |
| VM2 `db` | Ubuntu 24.04.4 amd64, 1 vCPU/2 GiB/25 GiB, NIC1 bridged (Wi-Fi, DHCP thất bại như dự kiến), NIC2 NAT cho apt + SSH `127.0.0.1:2222`. MySQL 8.0.46-0ubuntu0.24.04.4, enabled/active, nghe 127.0.0.1:3306, TZ hệ thống Asia/Ho_Chi_Minh, mysqld `+00:00`. Đã nạp `sql/01_schema.sql` + `02_seed.sql`; `99_verify.sql` ra 50/45/5, 5 phòng ban | IP tĩnh lab, `bind-address`, user `db_reader` (template đã có, đã thử trên MySQL 8.0 khác), UFW, user SSH thành viên, TC-05 từ VM1 |
| VM4 `api` | Ubuntu 24.04.4 amd64, 1 vCPU/1 GiB/25 GiB, NIC như VM2 (SSH `127.0.0.1:2223`). Python 3.12.3; `api/deploy/install.sh` cài `nt132-api.service` (user `nifi-source-api`, enabled/active, Gunicorn 23.0.0 nghe 127.0.0.1:5000); `api/deploy/smoke_test.sh` 8 PASS / 0 FAIL | Bind IP lab, UFW, user SSH thành viên, TC-10..TC-13 từ NiFi |

Artifact mới: `sql/`, `infra/db/zz-nt132.cnf`, `api/` (app, lock, systemd unit, install/smoke scripts, `.env.example`),
`tests/test_api_contract.py` (18 test hợp đồng bằng Flask test client — không phải test tích hợp).
Evidence ảnh do Trung giữ, sẽ đưa vào `evidence/` sau khi che secrets.

### Hoàn thiện artifact DB/API — 07/11/2026

- Sửa checker API: status + JSON đầy đủ, không echo key/body, trả exit lỗi, đo endpoint chậm,
  xác minh endpoint lab bật/tắt. Bash wrapper gọi helper Python stdlib.
- Installer chỉ thành công khi systemd active và health đúng; giữ nguyên key cũ.
- Bổ sung test snapshot không trùng/đúng kiểu, key, cấu hình lab, fixture reload và hồi quy checker.
- DB có verify_source (10 checks; seed replay tùy chọn) và verify_reader (SELECT được,
  ghi/sensitive column bị từ chối). Script DB chưa chạy với MySQL thật trong phiên này.
- Runbook: [DB_API_RUNBOOK.md](DB_API_RUNBOOK.md).

Kết quả kiểm thử đợt này: **33 pytest passed**, Python 3.12.16 trên Windows 11; có HTTP loopback thật với lab bật/tắt và phép đo endpoint chậm. Bốn script Bash qua kiểm tra cú pháp. CLI checker trả 1 khi nguồn offline và 2 khi cấu hình sai. Evidence: [local-db-api-2026-11-07.md](../evidence/local-db-api-2026-11-07.md), kèm JUnit XML. Đây không phải test MySQL/Gunicorn/systemd hay NiFi.
TC tích hợp vẫn NOT_RUN; không suy ra PASS của TC từ pytest hay HTTP loopback.
TCP 127.0.0.1:2222 và :2223 đã mở sau khi người dùng bật VM; SSH trung bị từ chối publickey/password. Chờ cấp public key bằng scripts/authorize_lab_ssh.ps1; endpoint NiFi chưa được cung cấp.
Xem bàn giao DB/API tại [MANUAL_ACTIONS.md](MANUAL_ACTIONS.md).

### Truy cập VM sau khi bật — 07/11/2026

- Người dùng xác nhận hai VM đã bật, username đều trung.
- TCP 127.0.0.1:2222/2223 reachable=true.
- SSH BatchMode=yes, StrictHostKeyChecking=yes trả Permission denied (publickey,password), exit 255 ở cả hai VM.
- Profile Windows ADMIN chỉ có known_hosts/known_hosts.old; không có identity mặc định và không có SSH agent.
- Chuẩn bị khóa riêng cho lab ngoài repo và scripts/authorize_lab_ssh.ps1; người dùng nhập mật khẩu tại terminal cục bộ để cấp public key.
- Chưa copy/apply bản sửa lên VM, chưa xác minh hostname/sudo/MySQL/Gunicorn. G1 PENDING_ENVIRONMENT; TC không đổi.

### Kiểm chứng lại và chuẩn bị triển khai — 10/11/2026

- Nhánh đúng: `trung/db-api`; GitHub trước khi cập nhật ở `17533fa`.
- **33 pytest passed**, exit 0, HTTP loopback thật; sáu script Bash qua kiểm tra cú pháp.
  Evidence: [local-db-api-2026-11-10.md](../evidence/local-db-api-2026-11-10.md).
- Hai VM ban đầu `poweroff`; đã bật đúng `db`/`api` bằng VirtualBox headless.
- SSH với khóa lab đã thành công vào cả hai hostname, user `trung`, thành viên nhóm `sudo`.
  Điều kiện cấp SSH key ngày 07/11 đã được giải quyết.
- `sudo -n true` ở cả hai VM yêu cầu mật khẩu. Cập nhật API/MySQL/TLS vẫn **NOT_RUN**,
  chờ nhập mật khẩu trực tiếp tại terminal cục bộ; không ghi mật khẩu/API key vào log/chat.
- `scripts/check_db_vm.sh` mặc định chỉ đọc baseline và TLS (`have_ssl`); `--extended` mới
  chạy seed replay và tạo/xóa reader tạm. `scripts/check_api_vm.sh` backup source/unit,
  chạy installer và smoke test, đối chiếu env giữ nguyên.
- Chưa có endpoint NiFi hoặc mạng hotspot. G1/G2 và các TC tích hợp chưa được đóng.
