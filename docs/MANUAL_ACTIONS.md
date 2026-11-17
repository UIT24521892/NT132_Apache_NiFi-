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

**IN_PROGRESS — G2–G3.** Theo báo cáo 09/11, bản sửa DB/API chưa push/áp dụng đầy đủ;
FTP chưa có artifact trong repo.

| Người / VM | Việc còn lại | Cách kiểm chứng |
|---|---|---|
| Trung / VM2, VM4 | Push bản sửa vào nhánh `trung/db-api`; áp dụng API bằng installer trong VM có sudo, chạy lại smoke test; bổ sung SQL verify | Trên nhánh nguồn: `sudo mysql < sql/99_verify.sql` cho 50/45/5, 5 phòng ban; `systemctl status nt132-api`, `curl -s http://127.0.0.1:5000/health` |
| Phước / VM3 | Đã xác nhận account, `/checkin` và reader list/download từ Kali; còn đưa `vsftpd.conf`, script user/thư mục, simulator và fixture vào repo, xác nhận passive 40000–40010 | Kiểm tra reader ghi/rename/delete bị từ chối; upload `.tmp` → `.csv` từ Windows và chứng minh NiFi không lấy `.tmp`, lưu evidence đã che secrets |

Các lệnh của nhánh DB/API cần checkout đúng nhánh trên VM; các file đó chưa có trong checkout
hiện tại. Với DB/API chưa đổi bind/firewall trước khi có IP lab (MA-01).
Với FTP đã có IP, đối chiếu cấu hình passive/firewall và hoàn thiện kiểm tra quyền reader.

## Quy tắc báo phần chưa thực hiện được

Nếu một bước cần thiết chưa thực hiện được, báo trong chat và cập nhật mục tương ứng:
task/gate/test, nguyên nhân quan sát, prerequisite thiếu, artifact hiện có, thao tác tối thiểu
trên đúng VM, cách verify, ảnh hưởng và evidence. Dùng PENDING_ENVIRONMENT/NOT_RUN khi chưa thử;
chỉ dùng BLOCKED khi đã quan sát rào cản. Khi đủ điều kiện, kiểm chứng lại trước khi đóng mục.
