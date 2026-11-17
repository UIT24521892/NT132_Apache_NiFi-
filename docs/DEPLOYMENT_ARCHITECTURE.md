# Cấu hình VM đang dùng — Apache NiFi, NT132

Cập nhật: 17/11/2026 (Asia/Ho_Chi_Minh).

Từ 16/11/2026 cả 4 VM chạy trên **UTM của Mac**, mạng **Shared Network** `192.168.64.0/24`
(Mac `bridge100` = `192.168.64.1`, gateway/DNS cho VM). Mạng này nằm trong Mac nên không phụ thuộc
Wi-Fi đang dùng; Wi-Fi chỉ cần khi VM ra Internet (apt/pip). Bố trí hotspot/VirtualBox trước đó
là lịch sử, xem [evidence 11/11](../evidence/G2/2026-11-11_hotspot_ftp-connectivity.md).
Ba VM nguồn do agent cài/kiểm tra qua SSH ngày 17/11:
[evidence UTM](../evidence/G2/2026-11-17_utm_source-vms.md). VM1 theo
[evidence bootstrap](../evidence/G2/2026-11-09_vm1_nifi-bootstrap.md).

## 1. Các VM đang dùng

| VM | Hostname / IP | OS | Dịch vụ |
|---|---|---|---|
| VM1 NiFi | `24521892` / `192.168.64.101` tĩnh (`nifi.lab`), giữ thêm `192.168.92.92` cũ | Kali Rolling 2026.2 ARM64 | NiFi 2.12.0, OpenJDK 21.0.13; HTTPS localhost, systemd |
| VM2 DB | `db` / `192.168.64.102` tĩnh (`db.lab`) | Ubuntu 24.04.5 LTS aarch64, 2 vCPU, 2 GB, 9.3 GB | MySQL 8.0.46, `hr_db`, nghe `127.0.0.1` + `192.168.64.102:3306` |
| VM3 FTP | `ftp` / `192.168.64.103` tĩnh (`ftp.lab`) | Ubuntu 24.04.5 LTS aarch64, 2 vCPU, 2 GB, 12 GB | vsftpd, inbox `/checkin`, passive 40000–40010 |
| VM4 API | `api` / `192.168.64.104` tĩnh (`api.lab`) | Ubuntu 24.04.5 LTS aarch64, 2 vCPU, 2 GB, 12 GB | Flask/Gunicorn `nt132-api.service`, nghe `192.168.64.104:5000` |

Quản trị VM nguồn: user `anhtruong` (sudo), SSH key `~/.ssh/nt132_lab` trên Mac.
Khi demo chỉ bật 4 VM này; Mac còn VM Windows/Kali cũ dùng DHCP cùng dải (`.3`, `.4`).
Nếu Wi-Fi nơi demo cũng là `192.168.64.0/24` thì Mac bị trùng route — kiểm tra `ipconfig getifaddr en0`.

## 2. VM1 — Kali / NiFi

| Mục | Cấu hình đã ghi nhận |
|---|---|
| Tài khoản quản trị | `anhtruong`, sudo `(ALL : ALL) ALL` |
| Init / mạng | systemd, NetworkManager (`nmcli`) |
| SSH | Cổng 22, service `ssh` active/enabled; Mac → Kali được người dùng xác nhận 11/11; host key chưa có evidence đối chiếu |
| NIC `eth0` | NetworkManager `Wired connection 1` manual `192.168.64.101/24` + `192.168.92.92/24` (17/11); trước đó DHCP `.2` |
| Default route | `192.168.64.1` (UTM Shared Network), DNS `192.168.64.1` |
| JDBC driver | `/opt/nifi/drivers/mysql-connector-j-26.10.0.jar` (root:nifi 0640, dir 0750, đặt 10/11); SHA-256 `cef70caf532833c9ab8f41f74773ce22c08bf503fad215c9c2ee1e9db87e759e`, SHA-1 khớp `.sha1`/`.sha256` trên [Maven Central](https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/26.10.0/) (kiểm 17/11) |
| Java shell mặc định | `openjdk 25.0.5-ea` (17/11); service NiFi vẫn dùng `JAVA_HOME` JDK 21 |
| Secrets nguồn | `/root/nt132-secrets/` root 0600: `reader.cnf`, `api.key`, `api.hdr`, `ftp_nifi_fetch.pass`, `netrc_ftp` |
| Múi giờ | Đã đổi sang `Asia/Ho_Chi_Minh`; UI NiFi hiện `ICT` |
| NiFi home | `/opt/nifi/nifi-2.12.0` |
| JDK service sử dụng | `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64` |
| Package JDK/JRE | `openjdk-21-jdk-headless`, `openjdk-21-jre-headless`: `21.0.13+9-1 arm64`; `javac 21.0.13` |
| User / group dịch vụ | `nifi:nifi`, uid 999 / gid 981 |
| Unit | `/etc/systemd/system/nifi.service`, enabled/active; bản trong repo: [nifi.service](../infra/nifi/nifi.service) |
| UI trong Kali | `https://localhost:8443/nifi`; listener `127.0.0.1:8443` |
| Xác thực hiện tại | Single-user, chứng chỉ tự sinh; chưa có CA/SAN lab hoặc RBAC ba vai trò |
| Config / log | `/opt/nifi/nifi-2.12.0/conf`, `/opt/nifi/nifi-2.12.0/logs` |
| Repositories / state | Giữ đường dẫn mặc định trong NiFi home; chưa ghi nhận di chuyển |
| Output | `/srv/nt132/output/{employees,shifts,attendance_events}` |
| Rejected | `/srv/nt132/rejected/{files,records,dead-letter}` |
| Quyền output/rejected | `nifi:nifi`, mode `0750` |

Kali ở UTM Shared Network; cấu hình bridge Wi-Fi/hotspot ngày 11/11 là lịch sử.
SSH bằng key `nt132_lab`, `/etc/hosts` có khối `nt132-lab`. Client MySQL là MariaDB 11.8.9.
Người dùng chọn thao tác UI trong Kali; truy cập NiFi từ Mac chưa xác nhận.
Java mặc định của shell chưa được kiểm tra lại; service trỏ riêng vào JDK 21 như unit.
Khung 5 PG, Parameter Context và PutFile lưu tại [nifi/README.md](../nifi/README.md).

Binary đã dùng: `nifi-2.12.0-bin.zip`, nguồn [Apache 2.12.0](https://downloads.apache.org/nifi/2.12.0/),
checksum đã trả `OK` ngày 09/11. SHA-512 đã lưu từ đợt setup:

```text
5891039ccf15234bb21c2d1ce65027357ca7603ad8fdfc946dd4b6499ab8061fb07a6a56f8e8c5bb7635d446354ca7cc76ba40e55921818931f193a75f247334
```

### Lệnh vận hành trên Terminal Kali

Kiểm tra service, cổng và log:

```sh
sudo systemctl status nifi --no-pager --lines=10
systemctl is-enabled nifi
sudo ss -ltnp 'sport = :8443'
sudo journalctl -u nifi -n 50 --no-pager
sudo tail -n 50 /opt/nifi/nifi-2.12.0/logs/nifi-app.log
```

Khởi động, dừng hoặc khởi động lại khi cần (chọn lệnh tương ứng):

```sh
sudo systemctl start nifi
sudo systemctl stop nifi
sudo systemctl restart nifi
```

Không xóa repositories/state/flow khi xử lý lỗi. Backup phải gồm cấu hình, flow,
state/repositories cần bảo toàn queue, output/rejected và secrets lưu riêng theo
[SPECS 7.3](../SPECS.md#73-backuprestore-drill); chưa có restore drill.

## 3. Cấu hình VM nguồn (17/11/2026)

Chung cho ba VM: ufw deny incoming, SSH 22 từ `192.168.64.0/24`; netplan `/etc/netplan/60-nt132-static.yaml` (gateway/DNS `192.168.64.1`),
cloud-init network disabled; `/etc/hosts` có khối `nt132-lab` cho `nifi/db/ftp/api.lab`.
Mã nguồn chép vào `~/nt132` (DB/API từ `origin/trung/db-api` @ `4eacec3`, FTP từ `infra/ftp/`).
Secrets sinh trên VM, nằm trong `/root/nt132-secrets/` (0700); không đưa vào Git/chat.

| VM | Cấu hình | Chưa làm |
|---|---|---|
| VM2 DB | `mysql` enabled; `/etc/mysql/mysql.conf.d/zz-nt132.cnf` UTC, utf8mb4, `bind-address = 127.0.0.1,192.168.64.102`; seed 50/45/5, 5 phòng ban; `db_reader@192.168.64.101` SELECT theo cột; ufw 3306 chỉ từ `.101` | Cert TLS MySQL còn tự sinh (không SAN `db.lab`) |
| VM3 FTP | `setup_vm3.sh 192.168.64.103`; `clock_uploader` (ghi/rename), `nifi_fetch` (chỉ list/read), chroot `/srv/ftp/nt132`, inbox `/checkin`; ufw 21 + 40000–40010 từ `.101` và Mac `.1` | Simulator/fixture |
| VM4 API | `install.sh 192.168.64.104:5000`; user `nifi-source-api`; key trong `/etc/nt132-api/api.env`; endpoint lab lỗi/chậm bật; ufw 5000 chỉ từ `.101` | — |

## 4. Ma trận kết nối

| Nguồn | Đích | TCP | Mục đích | Trạng thái 17/11 |
|---|---|---|---|---|
| Mac (`192.168.64.1`) | VM1–VM4 | 22 | SSH quản trị bằng key | OK cả 4 |
| Mac | VM1 | 8443 | NiFi UI/API | Chưa mở ngoài localhost |
| VM1 NiFi | VM2 | 3306 | JDBC, `db_reader` chỉ SELECT | Kali OK, `verify_reader` 5/5; Mac/ftp bị chặn |
| VM1 NiFi | VM4 | 5000 | HTTP API, `X-API-Key` | Kali 200/401 đúng; Mac/ftp bị chặn |
| VM1 NiFi | VM3 | 21, 40000–40010 | List/fetch passive | Kali list 226; quyền reader đạt |
| Mac (simulator) | VM3 | 21, 40000–40010 | Upload `.tmp` → rename `.csv` | Port mở; chưa có simulator |

Firewall allow/deny đã kiểm tra 17/11 ([E-UTM-06](../evidence/G2/2026-11-17_utm_source-vms.md)). NiFi cần CA/SAN phù hợp endpoint và ba identity
admin/operator/manager theo specs. Việc còn thiếu xem [MANUAL_ACTIONS.md](MANUAL_ACTIONS.md).
