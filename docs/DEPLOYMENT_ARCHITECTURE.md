# Kiến trúc triển khai (Deployment Architecture) — Apache NiFi, NT132

Cập nhật: 05/11/2026 (Asia/Ho_Chi_Minh). **Trạng thái: thiết kế, chưa provision.**
Giá trị dạng `<...>` là placeholder, phải thay bằng số liệu thật; G1 vẫn `PENDING_ENVIRONMENT`.

Tài liệu trả lời: NiFi và ba dịch vụ nguồn chạy trên máy nào, nối với nhau qua mạng và cổng nào,
ai truy cập từ đâu, dữ liệu và secrets nằm ở đâu. Luồng dữ liệu bên trong NiFi xem
[SPECS.md mục 3 và 6](../SPECS.md#3-kiến-trúc-nifi); hành vi và tiêu chí nghiệm thu vẫn theo SPECS.

## 1. Quyết định triển khai

| Quyết định | Nội dung | Nguồn |
|---|---|---|
| Profile | 4 VM, mỗi VM một dịch vụ: NiFi, MySQL, vsftpd, API | Nhóm chốt 28/10/2026; thầy chưa xác nhận |
| Máy vật lý | 4 VM chạy trên 3 máy: 1 MacBook Apple Silicon + 2 laptop Windows, mỗi thành viên phụ trách máy của mình | Nhóm, 28/10 và 05/11/2026 |
| Mạng | Hotspot Wi-Fi của một điện thoại trong nhóm làm LAN lab; mỗi VM một NIC bridged, IP tĩnh | Nhóm không có router riêng (05/11/2026) |
| Đặt VM | NiFi trên Mac (Trường); DB + API trên WIN-A (Trung), hai VM riêng; FTP trên WIN-B (Phước) | Nhóm chốt 05/11/2026 |
| Truy cập chéo | Thành viên xem server của nhau qua SSH bằng tài khoản riêng; không mở cổng dịch vụ cho máy thành viên | Mục 7.1 |

VM nằm trên ba máy khác nhau nên mạng host-only trong một máy không còn dùng được. Cả ba kết nối
NiFi → DB, NiFi → API và NiFi → FTP đi qua mạng vật lý, vì vậy bind address, route và firewall phải đúng như một
hệ thống nhiều máy thật.

Lý do đặt VM:

- Mỗi thành viên dựng và chịu trách nhiệm dịch vụ trên máy của mình: Trường — NiFi; Trung — MySQL
  và Flask API; Phước — vsftpd và simulator máy chấm công.
- NiFi tốn tài nguyên nhất (JVM, FlowFile/Content/Provenance repository) → máy mạnh nhất. Mac cũng là
  máy chạy browser demo.
- DB và API tách thành hai VM riêng trên WIN-A dù cùng một người làm, để giữ profile mỗi VM một dịch vụ,
  firewall và tài khoản dịch vụ độc lập. Cả hai đều nhẹ (tổng ≈3 GiB RAM).
- Cả ba luồng JDBC, REST, FTP đều đi qua ranh giới máy vật lý, nên kiểm thử firewall allow/deny có ý nghĩa.

## 2. Sơ đồ máy vật lý

```text
  ┌────────────────────────────────────────────────────────────────────────────┐
  │ PHONE-AP: hotspot điện thoại của nhóm — mạng lab <LAB_SUBNET>              │
  │ WPA2/WPA3 · chỉ 3 laptop kết nối · VM dùng IP tĩnh · không thuộc mạng trường│
  │ Internet (4G) chỉ dùng khi cài gói/NTP; demo chạy trong LAN                │
  └───────────┬──────────────────────────┬──────────────────────────┬──────────┘
              │                          │                          │
  ┌───────────┴──────────┐   ┌───────────┴──────────┐   ┌───────────┴──────────┐
  │ HOST-MAC · Trường    │   │ HOST-WIN-A · Trung   │   │ HOST-WIN-B · Phước   │
  │ macOS · Apple M2 Pro │   │ Windows · <HV>       │   │ Windows · <HV>       │
  │ UTM (bridged)        │   │ <HV> (bridged)       │   │ <HV> (bridged)       │
  │                      │   │                      │   │                      │
  │ [VM1 nifi.lab]       │   │ [VM2 db.lab]         │   │ [VM3 ftp.lab]        │
  │                      │   │ [VM4 api.lab]        │   │                      │
  │                      │   │                      │   │                      │
  │ Browser 3 role       │   │ SSH client           │   │ Simulator máy        │
  │ SSH client           │   │                      │   │ chấm công (Python)   │
  │                      │   │                      │   │ SSH client           │
  └──────────────────────┘   └──────────────────────┘   └──────────────────────┘
  [VMx] = VM Ubuntu Server 24.04, NIC bridged vào card mạng nối LAN lab
```

`<HV>` là hypervisor trên Windows (VirtualBox, VMware Workstation hoặc Hyper-V), chưa chốt.

## 3. Sơ đồ kết nối dịch vụ

```text
┌──────────────────────────┐                 ┌───────────────────────────┐
│ VM1 nifi.lab  (HOST-MAC) │ JDBC 3306       │ VM2 db.lab (HOST-WIN-A)   │
│ NiFi 2.12.0 · JDK 21     ├────────────────>│ MySQL 8.0 · hr_db         │
│ :8443 HTTPS              │                 └───────────────────────────┘
│                          │                 ┌───────────────────────────┐
│ PG-JDBC   PG-REST        │ HTTP 5000       │ VM4 api.lab (HOST-WIN-A)  │
│ PG-FTP    PG-OUTPUT      ├────────────────>│ Flask + Gunicorn          │
│ PG-ERROR                 │                 └───────────────────────────┘
│                          │                 ┌───────────────────────────┐
│ /srv/nt132/output        │ FTP 21+passive  │ VM3 ftp.lab (HOST-WIN-B)  │
│ /srv/nt132/rejected      ├────────────────>│ vsftpd · /checkin         │
└─────────────^────────────┘                 └─────────────^─────────────┘
              │ HTTPS 8443                                 │ FTP upload .tmp → .csv
      Browser trên HOST-MAC                      Simulator trên HOST-WIN-B
      client cert admin /
      operator / manager
```

Mũi tên chỉ chiều mở kết nối TCP. NiFi luôn là bên chủ động lấy dữ liệu; nguồn không đẩy vào NiFi.
SSH quản trị của thành viên không vẽ ở đây; xem mục 7.1.

## 4. Máy vật lý

| Host | OS / CPU | RAM | Disk trống | Hypervisor | Card nối LAN lab | IP host | Vai trò ngoài VM |
|---|---|---|---|---|---|---|---|
| HOST-MAC | macOS 27.0.1 · Apple M2 Pro (arm64), 10 nhân | 32 GiB | ≈75 GiB (đo 05/11/2026) | UTM 4.7.5 | `en0` Wi-Fi | `<IP_MAC>` | Trường: VM1; browser demo; giữ CA/backup ngoài repo |
| HOST-WIN-A | `<edition · CPU · arch>` | `<RAM>` | `<disk>` | `<HV>` | `<card>` | `<IP_WIN_A>` | Trung: VM2 + VM4 |
| HOST-WIN-B | `<edition · CPU · arch>` | `<RAM>` | `<disk>` | `<HV>` | `<card>` | `<IP_WIN_B>` | Phước: VM3; simulator máy chấm công |

Yêu cầu tối thiểu cho máy Windows:

- WIN-A cần thêm ≈3 GiB RAM và 30 GiB disk cho VM2 + VM4; WIN-B cần thêm ≈1 GiB RAM và 15 GiB disk cho VM3,
  ngoài phần Windows tự dùng (khuyến nghị tổng RAM ≥ 8 GiB).
- Bật virtualization trong firmware. Nên dùng cùng một hypervisor trên hai máy Windows để runbook chung.

Mac chỉ chạy VM1 (30 GiB disk khai báo, đĩa UTM chỉ chiếm theo dữ liệu thật); disk trống ≈75 GiB đủ cho
thêm một VM restore ở TC-28, xem mục 11.

## 5. Inventory VM

| VM | Hostname | Host | Arch | IP lab | vCPU / RAM / disk | Dịch vụ · cổng | Tài khoản dịch vụ |
|---|---|---|---|---|---|---|---|
| VM1 | nifi.lab | HOST-MAC | arm64 | `<IP_VM1>` | 2 / 4 GiB / 30 GiB | NiFi HTTPS 8443 | `nifi` |
| VM2 | db.lab | HOST-WIN-A | `<arch>` | `<IP_VM2>` | 1 / 2 GiB / 15 GiB | MySQL 3306 | `mysql` của package; DB user nguồn chỉ SELECT |
| VM3 | ftp.lab | HOST-WIN-B | `<arch>` | `<IP_VM3>` | 1 / 1 GiB / 15 GiB | vsftpd 21, 40000–40010 | FTP `clock_uploader` (ghi), `nifi_fetch` (chỉ đọc) |
| VM4 | api.lab | HOST-WIN-A | `<arch>` | `<IP_VM4>` | 1 / 1 GiB / 15 GiB | Gunicorn 5000 | `nifi-source-api` |

Tài nguyên lấy theo [SPECS 4.2](../SPECS.md#42-inventory-minh-họa--phải-thay-bằng-thông-số-thật), phải đo lại.
VM trên Mac là arm64 (UTM chế độ Virtualize, ISO arm64; không giả lập x86_64), VM trên Windows nhiều khả năng là x86_64: ISO, package version và checksum
ghi riêng từng VM trong version manifest. Giữ cùng phiên bản NiFi/JDK/MySQL/Python giữa các VM.
NiFi, JDK và Connector/J chạy trên JVM nên cấu hình flow không đổi theo kiến trúc CPU.

## 6. Mạng

Nhóm không có router riêng nên LAN lab là **hotspot Wi-Fi của một điện thoại** (gọi là PHONE-AP).
Với 3 laptop và 4 VM, hotspot đủ dùng; điều kiện là kiểm tra sớm các điểm dưới đây ở TC-01.

- **Thiết bị:** luôn dùng **cùng một điện thoại** cho mọi buổi dựng, test và demo, để subnet không đổi.
  Chỉ 3 laptop được kết nối; điện thoại khác không vào hotspot này. Không dùng Wi-Fi trường, ký túc xá
  hay quán: thường bật client isolation, IP thay đổi, và nhóm không được cấp quyền cấu hình mạng đó.
  Nếu sau này có router/switch thì chỉ cần đổi subnet trong inventory; thiết kế còn lại giữ nguyên.
- **Subnet do điện thoại quyết định**, không cấu hình được như router:
  - iPhone thường cấp `172.20.10.0/28`, gateway `172.20.10.1`: chỉ 14 địa chỉ, vẫn đủ cho 3 host + 4 VM.
    Netmask trong netplan phải là `/28`, không phải `/24`.
  - Android: dải tùy hãng và phiên bản; một số máy đổi subnet mỗi lần bật lại hotspot. Kiểm tra bằng cách
    tắt/bật hotspot hai lần và so IP. Nếu subnet đổi, dùng điện thoại khác cho lab.
  - Ghi subnet, gateway, DNS thật vào inventory (`<LAB_SUBNET>`, `<LAB_GATEWAY>`).
- **Client isolation:** phải xác nhận các laptop nói chuyện được với nhau trước khi tạo VM, ví dụ từ
  WIN-A kết nối TCP tới một cổng đang mở trên Mac. Nếu bị chặn thì hotspot đó không dùng được.
- **Địa chỉ:** hotspot không có DHCP reservation. Đặt IP tĩnh cho 4 VM ở cuối dải (iPhone: ví dụ `.10–.13`),
  để phần đầu dải cho DHCP. IP của cả 3 host nằm trong rule firewall (SSH, simulator) nên cũng cố định:
  Windows đặt IP tĩnh riêng cho profile Wi-Fi của hotspot (Settings → Wi-Fi → mạng đó → IP assignment);
  Mac tạo Network Location riêng cho lab. Gateway/DNS là IP của điện thoại.
- **NIC của VM:** một NIC bridged vào card Wi-Fi của host, nên VM có IP riêng và các máy khác truy cập
  trực tiếp. Không port-forward qua host: FTP passive và rule firewall theo IP nguồn sẽ sai.
- **Bridged qua Wi-Fi:** chuẩn Wi-Fi chỉ chấp nhận MAC của host, nên hypervisor thay MAC của VM khi đi qua
  Wi-Fi; DHCP trong VM có thể thất bại, vì vậy dùng IP tĩnh. Thử bridged trên từng hypervisor ngay ở
  TC-01 (ping và TCP giữa VM trên các host khác nhau), trước khi cài dịch vụ.
- **Vận hành điện thoại:** cắm sạc, tắt chế độ tự tắt hotspot khi không có thiết bị (nếu máy có tùy chọn),
  không mang điện thoại đi chỗ khác khi demo. Trên iPhone, nếu laptop không thấy mạng thì bật
  "Maximize Compatibility" (chuyển sang 2.4 GHz).
- **Dung lượng 4G:** tải ISO Ubuntu, NiFi, Connector/J trên mạng khác trước rồi chép vào máy, ghi checksum.
  Hotspot chỉ dùng cho `apt`, `pip` và NTP. Demo chạy hoàn toàn trong LAN, không cần Internet.
- **Phân giải tên:** `/etc/hosts` trên 4 VM và trên máy chạy browser (Mac: `/etc/hosts`; Windows:
  `C:\Windows\System32\drivers\etc\hosts`). Browser phải vào đúng tên có trong SAN của certificate NiFi.
- **Giờ:** đồng bộ NTP trong từng VM (systemd-timesyncd) khi có Internet; đo lệch giờ giữa các VM
  trước demo. Nghiệp vụ dùng `Asia/Ho_Chi_Minh`.
- **Firewall:** UFW trong từng VM là lớp kiểm soát chính. Firewall của host chỉ ảnh hưởng tiến trình
  chạy trên host (browser, simulator, SSH client); xác nhận thực tế ở TC-04.

## 7. Ma trận kết nối và firewall

| # | Nguồn | Đích | TCP | Đi qua máy vật lý | Mục đích | UFW trên đích cho phép từ |
|---|---|---|---|---|---|---|
| 1 | 3 host của thành viên | VM1–VM4 | 22 | có, trừ host tự vào VM của mình | SSH quản trị/kiểm tra (mục 7.1) | `<IP_MAC>`, `<IP_WIN_A>`, `<IP_WIN_B>` |
| 2 | HOST-MAC (browser) | VM1 | 8443 | trong Mac | NiFi UI/API | `<IP_MAC>` |
| 3 | VM1 | VM2 | 3306 | Mac → WIN-A | JDBC | `<IP_VM1>` |
| 4 | VM1 | VM4 | 5000 | Mac → WIN-A | REST | `<IP_VM1>` |
| 5 | VM1 | VM3 | 21, 40000–40010 | Mac → WIN-B | ListFTP/FetchFTP | `<IP_VM1>` |
| 6 | HOST-WIN-B (simulator) | VM3 | 21, 40000–40010 | trong WIN-B | Upload CSV | `<IP_WIN_B>` |

Mọi VM mặc định chặn incoming, cho established/related. Bind và tài khoản đi cùng firewall:

- MySQL `bind-address = <IP_VM2>`; user nguồn `'<db_reader>'@'<IP_VM1>'` chỉ SELECT, không dùng root từ xa.
- Gunicorn bind `<IP_VM4>:5000`, debug off.
- vsftpd `pasv_enable=YES`, `pasv_min_port=40000`, `pasv_max_port=40010`, `pasv_address=<IP_VM3>`.

Ca phải bị chặn để kiểm thử ở TC-04, ví dụ: HOST-WIN-B → VM2:3306, HOST-WIN-A → VM4:5000,
HOST-WIN-A → VM3:21, HOST-MAC → VM2:3306, VM4 → VM2:3306 (cùng host WIN-A nhưng API không cần DB). Kiểm tra bằng kết nối TCP/ứng dụng, không chỉ ping.

### 7.1. Thành viên kiểm tra server của nhau

Mỗi thành viên xem được cả 4 VM, nhưng chỉ toàn quyền trên VM mình phụ trách. Cổng dịch vụ
(3306, 5000, 21) vẫn chỉ mở cho NiFi và simulator như bảng trên; thành viên kiểm tra qua SSH.

| Lớp | Cấu hình |
|---|---|
| Tài khoản | Mỗi thành viên một user Linux riêng trên cả 4 VM; không dùng chung một user |
| Đăng nhập | SSH bằng public key; `PasswordAuthentication no`, `PermitRootLogin no`; private key chỉ ở máy từng người |
| Người phụ trách VM | Thuộc nhóm `sudo` trên VM đó |
| Thành viên khác | Không sudo; thuộc nhóm chỉ xem để đọc log (`systemd-journal`, `adm`), chạy `systemctl status`, đọc cấu hình không chứa secret |
| Secrets | File env, keystore, mật khẩu DB/FTP mode 0600, chủ là service user → nhóm chỉ xem không đọc được |
| NiFi UI | Thành viên dùng client certificate role operator hoặc manager; chỉ admin sửa flow/policy |

Thành viên khác kiểm tra được, ví dụ:

- VM2: `systemctl status mysql`, `journalctl -u mysql`, `ss -ltnp` để xem MySQL bind đúng IP lab.
  Truy vấn dữ liệu cần user MySQL chỉ đọc riêng cho thành viên, đăng nhập qua socket cục bộ trên VM2.
- VM4: `curl http://<IP_VM4>:5000/health` chạy ngay trên VM4, `journalctl -u <API_UNIT>`.
- VM3: `systemctl status vsftpd`, xem file trong `<FTP_ROOT>/checkin`.
- VM1: `systemctl status nifi`, đọc `nifi-app.log`, nếu nhóm log được cấp quyền đọc.
- Muốn dùng công cụ GUI như MySQL Workbench thì đi qua SSH tunnel, ví dụ
  `ssh -L 3307:localhost:3306 <user>@db.lab`, không mở thêm cổng 3306 cho máy thành viên.

Thành viên chỉ vào được khi máy mình nằm trong cùng mạng lab (cùng hotspot). Làm online mỗi người
một nơi thì cần VPN overlay; phương án này chưa chốt, xem mục 13.

## 8. Phần mềm và thư mục trên từng VM

Đề xuất, xác minh lại khi cài; đường dẫn `/srv/nt132/...` đã cố định trong SPECS 5.5.

| VM | Thành phần | systemd | Cấu hình · dữ liệu · log |
|---|---|---|---|
| VM1 | NiFi 2.12.0, OpenJDK 21, MySQL Connector/J `<version>` | `nifi.service` | NiFi home `/opt/nifi/nifi-2.12.0`; repositories + state `<NIFI_DATA_DIR>`; output `/srv/nt132/output`; rejected `/srv/nt132/rejected`; log `<NIFI_LOG_DIR>` |
| VM2 | `mysql-server` 8.0 từ Ubuntu | `mysql.service` | `/etc/mysql`, `/var/lib/mysql`, `/var/log/mysql` |
| VM3 | `vsftpd` từ Ubuntu | `vsftpd.service` | `/etc/vsftpd.conf`; inbox `<FTP_ROOT>/checkin`, nhìn từ FTP là `/checkin` |
| VM4 | Python 3.12 venv, Flask, Gunicorn | `<API_UNIT>.service` | code `/opt/nt132-api`; API key trong file env mode 0600; log journald |

## 9. Ánh xạ flow NiFi → triển khai

| Process Group | Component chạm mạng/đĩa | Đích | Host vật lý |
|---|---|---|---|
| PG-JDBC | DBCPConnectionPool | `jdbc:mysql://db.lab:3306/hr_db` | HOST-WIN-A |
| PG-REST | InvokeHTTP | `http://api.lab:5000/api/shifts` | HOST-WIN-A |
| PG-FTP | ListFTP, FetchFTP | `ftp.lab:21`, `/checkin`, passive | HOST-WIN-B |
| PG-OUTPUT | PutFile | `/srv/nt132/output/<dataset>/` trên VM1 | HOST-MAC |
| PG-ERROR | PutFile | `/srv/nt132/rejected/...` trên VM1 | HOST-MAC |

Hostname, port, path đặt trong Parameter Context: khi đổi IP chỉ sửa hosts/parameter, không sửa Processor.

## 10. Bảo mật trong triển khai

- **NiFi HTTPS:** CA riêng của lab; private key CA giữ trên HOST-MAC, ngoài repo. Server certificate có SAN
  `nifi.lab` và `<IP_VM1>`. Ba client certificate admin/operator/manager import vào browser trên máy demo.
- **Secrets:** mật khẩu DB/FTP, API key, mật khẩu keystore nằm trong sensitive parameter và file cục bộ
  mode 0600; không commit, không gửi qua chat.
- **Giao thức không mã hóa:** HTTP API và FTP đi qua Wi-Fi của hotspot. Hotspot đặt WPA2/WPA3 với mật khẩu
  mạnh, chỉ 3 laptop của nhóm kết nối, chỉ dùng dữ liệu giả, và ghi giới hạn này trong báo cáo.
  FTPS/SFTP là mở rộng.

## 11. Backup và restore

- Backup NiFi theo [SPECS 7.3](../SPECS.md#73-backuprestore-drill) lưu ngoài repo tại `<BACKUP_DIR>` trên
  HOST-MAC, kèm một bản sao ở ổ hoặc máy khác.
- Restore drill (TC-28) dùng một VM riêng, chỉ bật khi VM1 đã dừng để hai NiFi không cùng poll nguồn.
  Đề xuất đặt trên HOST-MAC (cùng kiến trúc arm64 với VM1, còn đủ disk); nếu đặt host khác thì ghi rõ kiến trúc CPU trong evidence.
- Snapshot của hypervisor trước test phá hủy chỉ là tiện ích, không thay cho backup NiFi.

## 12. Rủi ro khi chạy trên 3 máy

| Rủi ro | Giảm thiểu |
|---|---|
| Thiếu một máy khi demo → mất nguồn tương ứng | Script provision chạy lại được để dựng lại VM trên host khác (VM x86_64 không chạy native trên Mac arm64 nên dựng lại thay vì chép image); diễn tập trước demo |
| Host sleep hoặc Windows Update khởi động lại | Tắt sleep, hoãn update trong buổi demo; dịch vụ autostart (TC-27) |
| IP đổi khi sang mạng khác | Luôn dùng cùng điện thoại; IP tĩnh; hostname trong Parameter Context và hosts |
| Hotspot bật client isolation hoặc đổi subnet mỗi lần bật | Kiểm tra trước khi tạo VM (mục 6); đổi sang điện thoại khác |
| Điện thoại hết pin, tự tắt hotspot, rời phòng | Cắm sạc, tắt auto-off; demo chỉ cần LAN nên mất 4G không ảnh hưởng nếu hotspot vẫn bật (kiểm tra trước) |
| Bridged qua Wi-Fi không nhận DHCP hoặc không thông | IP tĩnh; thử hypervisor khác; nếu vẫn hỏng thì cần switch + cáp, hoặc đổi sang NAT + port forward (phải cập nhật SPECS 4.2 và firewall theo IP nguồn) |
| Mac không vào được VM1 bridged trên chính nó | Kiểm tra sớm; nếu gặp, thêm NIC shared/host-only cho đường Mac ↔ VM1 và ghi vào inventory |
| Lệch giờ giữa các VM | NTP, đo lệch giờ trước demo |
| Khác kiến trúc arm64/x86_64 | Manifest riêng từng VM, cùng phiên bản phần mềm |

## 13. Thông tin còn thiếu

| Mục | Trạng thái | Bàn giao |
|---|---|---|
| Cấu hình 2 máy Windows và hypervisor | PENDING_ENVIRONMENT | [MA-01](MANUAL_ACTIONS.md#ma-01--máy-ảo-và-card-mạng) |
| Loại điện thoại làm hotspot, subnet thật, kết quả kiểm tra client isolation, IP host/VM, SSH | PENDING_ENVIRONMENT | [MA-01](MANUAL_ACTIONS.md#ma-01--máy-ảo-và-card-mạng), [MA-02](MANUAL_ACTIONS.md#ma-02--ip-ssh-và-quyền-quản-trị-linux) |
| Username và SSH public key của Trường, Trung, Phước | PENDING_ENVIRONMENT | [MA-02](MANUAL_ACTIONS.md#ma-02--ip-ssh-và-quyền-quản-trị-linux) |
| Làm việc từ xa (VPN overlay Tailscale/ZeroTier) | Chưa chốt; nếu dùng phải cập nhật SPECS 4.2 và mục 6–7 | — |
| Thầy chấp nhận 4 VM trên 3 máy vật lý | Chưa xác nhận | [MA-05](MANUAL_ACTIONS.md#ma-05--rubric-phạm-vi-và-yêu-cầu-nộp-của-giảng-viên) |
| Exact version từng package, checksum | NOT_RUN | [SPECS 4.1](../SPECS.md#41-profile-và-phiên-bản) |
