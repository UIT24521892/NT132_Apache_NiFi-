# Việc còn thiếu để nối và vận hành các VM

Cập nhật: 17/11/2026 (Asia/Ho_Chi_Minh).

Cấu hình đã dùng lưu tại [DEPLOYMENT_ARCHITECTURE.md](DEPLOYMENT_ARCHITECTURE.md).
NiFi đã chạy trên VM1; không cần cài lại JDK/NiFi hoặc chạy lại preflight cũ.

Ưu tiên trên VM1: xem cảnh báo PutFile, sửa `PD-JDBC` → `PG-JDBC`, export flow vào `nifi/`,
tạo Controller Services (`JsonTreeReader`, `JsonRecordSetWriter`, `CSVReader`) và chuẩn bị
MySQL Connector/J có version/checksum trong `/opt/nifi/drivers`.
Đây là việc tiếp theo, chưa được ghi nhận hoàn thành.

## MA-01 — Máy ảo và card mạng

**Cập nhật 17/11/2026 — cả 4 VM trên UTM Shared Network của Mac** (nội dung hotspot bên dưới
là lịch sử). Đã xong: IP tĩnh nifi `.101`, db `.102`, ftp `.103`, api `.104`; cài và kiểm tra ba nguồn;
Kali truy cập được cả ba; ufw allow/deny đã thử
([evidence](../evidence/G2/2026-11-17_utm_source-vms.md)). Còn lại:

1. ~~Reboot thử 4 VM~~ — đạt 17/11 (E-UTM-07).
2. Gỡ `/etc/sudoers.d/90-nt132-setup` trên cả 4 VM khi xong giai đoạn cấu hình, trước nghiệm thu.

**IN_PROGRESS — G1–G2.** Hotspot đã có Mac `172.20.10.9/28`, Kali `172.20.10.10/28`,
FTP `172.20.10.13/28`; gateway Kali `172.20.10.1`. Kali → FTP TCP/list/download qua curl
thành công; xem [evidence 11/11](../evidence/G2/2026-11-11_hotspot_ftp-connectivity.md).
VM DB Trung vẫn NAT `10.0.3.15/24`, enp0s3 DOWN; VM API chưa có IP lab.
Trung cần giữ NAT quản trị, cấu hình card còn lại bridge Wi-Fi Windows và bật DHCP đúng card;
gửi output IP/route cho cả DB và API trước khi đổi bind/firewall. Các IP hotspot chưa cố định.

Trên từng VM, ghi `ip -br address`, `ip route`; thử TCP giữa các host/VM theo
[ma trận kết nối](DEPLOYMENT_ARCHITECTURE.md#4-kết-nối-cần-hoàn-tất), gồm cả ca bị chặn.
JDBC/REST còn chờ mạng nguồn. FTP đã đủ kết nối CLI để bắt đầu dựng flow trong NiFi;
cả ba flow NiFi vẫn NOT_RUN cho tới khi có kết quả processor thật.

## MA-02 — IP, SSH và quyền quản trị Linux

**IN_PROGRESS — G1–G2.** SSH VM1 active/enabled, user `anhtruong` có sudo trong guest.
Phiên công cụ bị từ chối mở TCP ngày 05/11 và 11/11; SSH tới hai IP cũ VM1 timeout ngày 09/11.
Ngày 11/11 người dùng xác nhận Mac SSH vào Kali `172.20.10.10` được (USER_CONFIRMED).
Còn thiếu evidence đối chiếu host key và log đăng nhập; giới hạn công cụ không chứng minh guest/firewall lỗi.

Đối chiếu host key từ console Kali:

```sh
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Sau khi đối chiếu, kiểm tra trong Terminal Mac với IP đã ghi nhận:

```sh
ssh anhtruong@172.20.10.10 'id; hostname'
```

Trung/Phước bổ sung IP lab, user/host key và cách SSH vào VM nguồn. Mỗi thành viên dùng key
riêng; chỉ có sudo trên VM phụ trách. Không gửi private key/mật khẩu vào chat/Git.
Trước khi đổi firewall cần giữ console và kiểm tra một phiên SSH mới.

## MA-03 — Credentials và danh tính nội bộ

**IN_PROGRESS — G2–G5.** Đã kiểm tra reader FTP `nifi_fetch` đăng nhập/list/download bằng curl;
uploader có tên `clock_uploader`. Chưa nhận bằng chứng credentials mới được nạp vào NiFi.
Nạp DB/FTP password và API key vào sensitive parameters của `nt132-params` tại VM1;
không lưu giá trị thật trong repo. Thông số hiện có tại [nifi/README.md](../nifi/README.md).

Khi nối nguồn: kiểm tra DB chỉ SELECT, API key đúng/sai và FTP reader chỉ list/download.
Single-user hiện tại chỉ phục vụ bootstrap; ba identity/policies còn chưa cấu hình.

## MA-04 — Trust CA và chứng chỉ client trên trình duyệt

**NOT_RUN — G2/G5.** Khi có endpoint lab, cấu hình CA/SAN phù hợp và client certificate riêng
cho admin/operator/manager theo SPECS mục 7. Lưu khóa riêng ngoài Git,
import CA/client cert vào browser dùng demo.

Kiểm tra TLS bằng CA tin cậy, browser không cảnh báo và quyền cho phép/bị từ chối của từng role.
HTTPS tự sinh ở localhost hiện tại chưa đáp ứng phần nghiệm thu này.

## MA-05 — Rubric, phạm vi và yêu cầu nộp của giảng viên

**PENDING_ENVIRONMENT.** Ngày 11/11 người dùng báo giảng viên yêu cầu dashboard.
Chưa chốt dùng giám sát sẵn có của NiFi hay phải làm web riêng, chỉ tiêu hiển thị và tiêu chí nghiệm thu.
Cần làm rõ phần này để cập nhật phạm vi đang ghi trong SPECS; chưa có rubric/format/deadline đầy đủ.
Tiếp tục tích hợp nguồn và chuẩn bị flow trong lúc chờ.

## MA-06 — Evidence GUI và demo trực tiếp

**IN_PROGRESS — G3–G6.** Đã tổng hợp [báo cáo tiến độ 11/11](BAO_CAO_TIEN_DO_2026-11-11.md)
và bản chép evidence FTP từ ảnh chat. Còn lưu ảnh gốc, flow thật chạy với dữ liệu giả,
flow export và log/ảnh theo TC-01..TC-30. Chưa có bằng chứng xem CSV trong queue NiFi;
việc này cần chạy ListFTP/FetchFTP trước.
Thu evidence có thời điểm, môi trường, expected/actual; che secrets.
Chỉ bàn giao thao tác GUI khi công cụ không thực hiện được; không dùng ảnh cấu hình làm kết quả test.

## MA-07 — Đưa artifact VM nguồn vào repo và hoàn tất kiểm tra cục bộ

**IN_PROGRESS — G2–G3 (cập nhật 17/11).** DB/API đã merge vào `main` (PR #1, `4eacec3`) và đã cài,
kiểm tra trên VM UTM (verify_source 10/0, verify_reader 5/0, smoke 14/0). FTP: `vsftpd.conf` và
`setup_vm3.sh` đã có trong `infra/ftp/` và đã dùng để cài VM ftp; quyền reader đã kiểm tra.

| Người | Việc còn lại | Cách kiểm chứng |
|---|---|---|
| Trung | Không còn việc chờ cho nguồn; review PG-JDBC/PG-REST trên NiFi | Chạy lại flow, đối chiếu 45 record đã mask và 3 ca |
| Phước | Simulator upload `.tmp` → rename `.csv` (user `clock_uploader`, không ghi mật khẩu vào code); xác nhận fixture CSV và bảng kết quả mong đợi | Chạy simulator vào `ftp.lab`, NiFi không lấy `.tmp`; kết quả khớp bảng mong đợi |

## Quy tắc báo phần chưa thực hiện được

Nếu một bước cần thiết chưa thực hiện được, báo trong chat và cập nhật mục tương ứng:
task/gate/test, nguyên nhân quan sát, prerequisite thiếu, artifact hiện có, thao tác tối thiểu
trên đúng VM, cách verify, ảnh hưởng và evidence. Dùng PENDING_ENVIRONMENT/NOT_RUN khi chưa thử;
chỉ dùng BLOCKED khi đã quan sát rào cản. Khi đủ điều kiện, kiểm chứng lại trước khi đóng mục.

## Lịch sử bàn giao DB/API trên VirtualBox (Trung) — đã đóng 17/11/2026

Giữ nguyên văn để tham chiếu. Các mục này thuộc bố trí VirtualBox/HOST-WIN-A cũ; từ 17/11 VM db/api
trên UTM đã được cài bằng installer/verify script dưới đây (verify_source 10/0, verify_reader 5/0,
smoke API 14/0) nên không còn việc chờ.

### Bàn giao DB/API — 07/11/2026

- **Task/gate/test:** kiểm chứng nguồn VM2/VM4 và PG-JDBC/PG-REST; G1/G2/G3, TC-03..TC-13, TC-27.
- **Observed cause:** hai endpoint SSH lịch sử 127.0.0.1:2222/2223 không kết nối được khi kiểm tra TCP;
  chưa có endpoint NiFi và inventory mạng lab. Không kết luận lỗi sudo/firewall.
- **Prerequisite:** VM2/VM4 đang chạy, endpoint/user/host key được xác minh; SSH và quyền đúng VM;
  key/mật khẩu nạp cục bộ, IP lab VM1/VM2/VM4 thật.
- **Artifact đã chuẩn bị:** api/deploy/install.sh, smoke_test.sh + smoke_test.py,
  sql/99_verify.sql, verify_source.sh, verify_reader.sh; tests và docs/DB_API_RUNBOOK.md.
  Áp dụng bản sửa lên VM và kiểm thử MySQL/systemd vẫn NOT_RUN.
- **Manual steps tối thiểu:** bật đúng VM2/VM4 hoặc xác nhận endpoint mới trên HOST-WIN-A;
  xác minh SSH/host key và cấp quyền/secret cục bộ. Không gửi private key/password vào chat.
  Khi có kết nối, agent tiếp tục tự triển khai/verify bằng artifact đã chuẩn bị.
- **Verify:** theo DB_API_RUNBOOK.md; verify_source 10/0 (11/0 khi chủ động replay seed),
  verify_reader 5/0; API smoke lab bật 14/0, lab tắt 10/0. Sau đó chạy TC trong NiFi và reboot VM;
  lưu log/ảnh có timestamp, exit code, không chứa secret.
- **Effect/status:** PENDING_ENVIRONMENT cho triển khai VM/NiFi; artifact/test cục bộ tiếp tục độc lập.
- **Evidence:** chưa có evidence VM/NiFi cho bản sửa; test cục bộ có 33 pytest passed và evidence tại evidence/local-db-api-2026-11-07.md. Kết quả này không đóng các TC tích hợp.

### Cấp public key SSH cho VM2/VM4 — 07/11/2026

- **Task/gate/test:** truy cập VM2/VM4 để triển khai, G1/G2; TC-01/03/05/10..13/27 còn chờ.
- **Observed cause:** TCP 2222/2223 đã mở; user trung; SSH dùng host key cục bộ tin cậy
  nhưng exit 255 Permission denied (publickey,password). Windows không có key/agent để xác thực.
- **Prerequisite:** người dùng nhập mật khẩu Ubuntu một lần tại SSH trong PowerShell của mình,
  hoặc cấp public key qua console; không gửi password/private key vào chat.
- **Artifact:** khóa nt132_lab_ed25519 ngoài repo trong .ssh của ADMIN; scripts/authorize_lab_ssh.ps1
  chỉ gửi file .pub lên authorized_keys của trung, giữ key cũ và không thêm trùng.
- **Manual step:** từ root repo trên Windows chạy
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\authorize_lab_ssh.ps1,
  nhập mật khẩu trung cho từng cổng 2222/2223 tại prompt, rồi báo đã xong.
- **Verify:** agent SSH BatchMode với khóa lab, kiểm tra hostname, id, sudo -n true.
  Nếu sudo cần mật khẩu tương tác, chỉ bàn giao bước sudo cụ thể sau khi xác minh quyền.
- **Effect/status:** PENDING_ENVIRONMENT cho xác thực; bản sửa chưa áp dụng lên VM,
  33 test cục bộ vẫn là evidence riêng, không đổi TC thành PASS.

### Sudo triển khai DB/API — 10/11/2026

- **Task/gate/test:** cập nhật nguồn API VM4, kiểm tra baseline/TLS MySQL VM2; G2.
- **Observed cause:** SSH bằng khóa lab đã thành công vào `db`/`api` qua
  `127.0.0.1:2222/2223`, user `trung`; `sudo -n true` cả hai trả `sudo: a password is required`.
  Điều kiện cấp public key 07/11 đã giải quyết, không cần chạy lại authorize script.
- **Prerequisite:** người dùng nhập mật khẩu sudo Ubuntu trực tiếp tại terminal SSH cục bộ.
  Không gửi mật khẩu/private key/API key vào chat hoặc đưa vào file evidence.
- **Artifact:** `scripts/verify_lab_vms.ps1` chạy đúng hai script được copy vào thư mục
  `/home/trung/nt132-verify-<run-id>`; `.tools/vm-current-run.json` giữ đường dẫn run hiện tại ngoài Git.
  Script DB mặc định chỉ đọc, in 10 baseline checks, tổng 50/45/5, 5 phòng ban, timezone và `have_ssl`.
  Script API backup source/unit, giữ nguyên env/key/bind, chạy installer rồi smoke test.
- **Manual step:** sau khi agent chuẩn bị run, chạy
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify_lab_vms.ps1`
  từ root repo (hoặc dùng terminal agent mở), nhập mật khẩu tại từng prompt sudo.
- **Verify:** agent lấy `evidence/vm-db.log` và `vm-api.log` từ từng VM;
  mong đợi DB 10/0, 50/45/5, 5 phòng ban, timezone `+00:00`, TLS `YES`,
  API env unchanged, service active/enabled và smoke 14/0 khi lab bật, `RUN_EXIT=0`.
  Nếu TLS `DISABLED`, ghi rõ để Trường chốt tham số NiFi; không tự đổi TLS.
- **Effect/status:** PENDING_ENVIRONMENT cho sudo; commit/push và test cục bộ tiếp tục được.
  Chưa có kết quả DB/API runtime cho bản sửa; TC NiFi vẫn NOT_RUN.
