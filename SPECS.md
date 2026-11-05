# Đặc tả triển khai và nghiệm thu — Apache NiFi, NT132

Phiên bản 1.0 · 19/10/2026 · Baseline kỹ thuật đề xuất, chưa thay rubric của giảng viên.

## 1. Chủ đề và giới hạn

**Apache NiFi là sản phẩm chính:** dựng một NiFi single node, thu thập qua JDBC/REST/FTP,
biến đổi bằng Processor/Controller Service, xử lý lỗi và chứng minh vận hành bằng NiFi UI.
Nhân sự/chấm công chỉ là bộ dữ liệu minh họa ba giao thức, không phải ứng dụng cần phát triển.

Baseline gồm:

- NIFI-01: NiFi HTTPS hoạt động; versions và cấu hình có thể tái dựng.
- NIFI-02: PG-JDBC lấy dữ liệu MySQL bằng tài khoản SELECT, có transform quan sát được.
- NIFI-03: PG-REST gọi API có xác thực, chuẩn hóa JSON và xử lý status/timeout.
- NIFI-04: PG-FTP liệt kê/lấy CSV passive, không đọc file đang upload.
- NIFI-05: ba dataset có hợp đồng đầu ra rõ, PutFile và rejected có thể đối chiếu.
- NIFI-06: queue, back pressure, retry, xử lý duplicate/replay được kiểm tra.
- NIFI-07: Provenance truy vết được từ nguồn đến output; quyền content được hạn chế.
- NIFI-08: admin/operator/manager là ba identity độc lập, policy có kiểm thử âm.
- NIFI-09: giám sát, reboot/restart và backup/restore NiFi có evidence.
- NIFI-10: báo cáo, flow export và demo giải thích được toàn bộ luồng.

Mạng, Linux, DB, FTP và Flask chỉ được bổ sung đủ để phục vụ các mục trên. Không yêu cầu
website/dashboard riêng, ứng dụng HR, tính lương, HA/cluster, NiFi Registry server, LDAP/OIDC
hay Prometheus/Grafana. Không chuyển pipeline Get/Transform sang Python thay NiFi.

Mở rộng sau baseline: enriched attendance, ghi `report_db`, SFTP/FTPS, incremental JDBC,
điều khiển NiFi qua API. Chỉ thực hiện khi thời gian cho phép hoặc thầy yêu cầu rõ.

## 2. Những giả định cần xác nhận

| Mục | Quyết định tạm dùng | Cần xác nhận |
|---|---|---|
| Phạm vi Get/Transform | PutFile chỉ để quan sát kết quả | Thầy chấp nhận đầu ra demo |
| Số máy | 4 VM cho 4 dịch vụ, chạy trên 3 máy vật lý (1 Mac + 2 Windows); nhóm chốt 28/10/2026 | Thầy chấp nhận 4 VM trên 3 máy vật lý |
| API | Flask nội bộ tối thiểu, dữ liệu tĩnh giả | Thầy có yêu cầu API công khai không |
| FTP | FTP thường chỉ trong mạng lab cô lập | Có yêu cầu FTPS/SFTP không |
| NiFi | Một node | Có yêu cầu cluster không |
| Nghiệm thu | Baseline ở tài liệu này | Rubric, deadline, mẫu báo cáo, số thành viên |

Chưa có ảnh ghi chú gốc/rubric trong repo; các lời thầy ở plan là thông tin nhóm ghi lại.
Không ghi “thầy đã duyệt” trước khi có xác nhận. Những điểm chưa chốt không ngăn viết code,
fixtures và cấu hình mẫu; không triển khai lên một hệ thống chưa được chỉ định.

## 3. Kiến trúc NiFi

```text
MySQL hr_db --JDBC--> PG-JDBC --normalize/mask---+--> PG-OUTPUT --> PutFile
Flask shifts --HTTP--> PG-REST --normalize------+       |
vsftpd inbox --FTP--> PG-FTP --CSV/validate-----+       +--> rejected/
                           |
                    bounded retry / queues / provenance

Browser admin/operator/manager --HTTPS + client identity--> NiFi UI
```

Không nối ba queue vào một LookupRecord rồi coi là join. Ba flow baseline xuất dataset riêng.
Các Processor transform và xử lý lỗi phải nằm trong NiFi; code nguồn chỉ trả dữ liệu thô.

Các Process Group: `PG-JDBC`, `PG-REST`, `PG-FTP`, `PG-OUTPUT`, `PG-ERROR`.
Mỗi group có chú thích mục tiêu, schema, lịch chạy, relationship và nguồn parameter.
Controller Services tối thiểu: DBCPConnectionPool, CSVReader, JsonTreeReader,
JsonRecordSetWriter; SSL context/lookup service chỉ thêm khi thật sự cần.

## 4. Môi trường triển khai hỗ trợ NiFi

### 4.1. Profile và phiên bản

| Thành phần | Baseline | Ghi chú |
|---|---|---|
| OS VM | Ubuntu Server 24.04 LTS | Ghi patch, CPU architecture và package versions thực tế |
| NiFi | Apache NiFi Standard 2.12.0 | Trang download xác minh ngày 19/10/2026; không dùng tag latest |
| JVM | OpenJDK 21 | Ghi vendor/patch; không suy ra mọi JDK >21 đều được hỗ trợ |
| MySQL | 8.0 từ repository Ubuntu phù hợp | Chốt exact version trước provision |
| JDBC | MySQL Connector/J tương thích MySQL/JDK | Chốt exact version, URL/checksum trước tải |
| API | Python 3.12 + Flask + Gunicorn | Khóa dependency; debug off; systemd |
| FTP | vsftpd từ Ubuntu repository | Ghi exact package version |

Không nâng version giữa demo nếu chưa kiểm thử lại. `infra/versions` hoặc manifest tương đương
phải chứa phiên bản thực, architecture, nguồn tải/checksum với binary tải ngoài package manager.
[Nguồn phát hành NiFi](https://nifi.apache.org/download/),
[yêu cầu hệ thống NiFi](https://nifi.apache.org/nifi-docs/administration-guide.html#system_requirements).

Profile chính (nhóm chọn): 4 VM trên 3 máy vật lý; vị trí VM, mạng và rủi ro ở
[docs/DEPLOYMENT_ARCHITECTURE.md](docs/DEPLOYMENT_ARCHITECTURE.md). Profile dự phòng: NiFi một VM,
DB/FTP/API chung một VM; vẫn giữ user, port, data directory và service độc lập. Ghi rõ đây là hai
máy có bốn dịch vụ; cần thầy chấp nhận.
Container chỉ hỗ trợ dev nếu có, không tự coi container là VM khi đề yêu cầu VM.

### 4.2. Inventory minh họa — phải thay bằng thông số thật

| Máy | Hostname | Máy vật lý (đề xuất) | IP lab ví dụ | Tài nguyên dự kiến |
|---|---|---|---|---|
| VM1 | nifi.lab | HOST-MAC | 192.168.56.10/24 | 2 vCPU, RAM 4 GiB, disk 30 GiB |
| VM2 | db.lab | HOST-WIN-A | 192.168.56.11/24 | 1 vCPU, RAM 1–2 GiB, disk 15 GiB |
| VM3 | ftp.lab | HOST-WIN-B | 192.168.56.12/24 | 1 vCPU, RAM 1 GiB, disk 15 GiB |
| VM4 | api.lab | HOST-WIN-A | 192.168.56.13/24 | 1 vCPU, RAM 1 GiB, disk 15 GiB |

Tài nguyên trên là đề xuất cho dữ liệu nhỏ, phải đo thực tế. Ghi IP máy quản trị và máy
upload riêng, tên NIC, subnet, route/default gateway và DNS/hosts. Kiểm tra subnet không trùng
mạng/VPN có sẵn; không mặc định hypervisor nào cũng có mạng `192.168.56.0/24`.
VM nằm trên ba máy vật lý nên NIC lab là bridged vào LAN riêng của nhóm (hotspot điện thoại của nhóm,
không thuộc mạng trường), IP tĩnh; không port forwarding qua host, không mở ra Internet.
Đồng bộ giờ VM; nghiệp vụ dùng `Asia/Ho_Chi_Minh`.

### 4.3. Ma trận kết nối

| Nguồn được phép | Đích | TCP | Mục đích |
|---|---|---|---|
| Máy của các thành viên đã chỉ định | Từng VM | 22 | SSH quản trị/kiểm tra, user riêng, key-only |
| Máy trình duyệt demo đã chỉ định | VM1 | 8443 | NiFi UI/API qua HTTPS |
| VM1 | VM2 | 3306 | NiFi JDBC |
| VM1 | VM4 | 5000 | NiFi lấy REST |
| VM1 và máy giả lập đã chỉ định | VM3 | 21, 40000–40010 | FTP control + passive data |

Firewall deny incoming mặc định, cho established/related; outbound theo nhu cầu lab.
Không mở cả subnet cho DB/API khi chỉ VM1 cần truy cập. MySQL bind IP lab, account giới hạn
theo IP NiFi; không dùng root từ xa hoặc user `%` mặc định. API bind IP lab; FTP passive trả
địa chỉ VM3 mà client truy cập được. Profile 2 VM phải thay IP trong toàn bộ inventory/rules.
Giữ SSH/console khôi phục và kiểm tra cấu hình trước khi bật firewall.
Kiểm tra TCP/ứng dụng cùng cả ca được phép và bị chặn; ping chỉ chứng minh ICMP.
[UFW](https://ubuntu.com/server/docs/how-to/security/firewalls/),
[MySQL account host](https://dev.mysql.com/doc/refman/8.0/en/account-names.html).

### 4.4. Dịch vụ và quyền

NiFi chạy bằng service user `nifi`, API bằng `nifi-source-api`, không dùng root.
Các dịch vụ có systemd/autostart, restart policy phù hợp và log truy cập được cho admin.
Tách thư mục cấu hình, dữ liệu và log; mặc định output chỉ service user ghi, secrets mode 0600.
Thư mục/repository NiFi phải bền qua restart, có owner/quota/retention được ghi rõ.
DB source user chỉ SELECT trên bảng/cột cần thiết; sink user riêng nếu làm mở rộng.
FTP tách `clock_uploader` và `nifi_fetch`: uploader được tạo/rename file trong inbox;
consumer chỉ list/read. Chroot root không writable; thư mục inbox con có quyền phù hợp.
Ghi rõ ánh xạ đường dẫn OS → đường dẫn FTP, kiểm tra quyền bằng hai tài khoản thật.
API dùng WSGI Gunicorn và systemd, không chạy Flask debug server làm dịch vụ demo.
[Flask deployment](https://flask.palletsprojects.com/en/stable/deploying/),
[vsftpd configuration](https://manpages.ubuntu.com/manpages/noble/man5/vsftpd.conf.5.html).

## 5. Hợp đồng dữ liệu

### 5.1. Quy ước chung

UTF-8, JSON/CSV xác định schema; không suy đoán kiểu từ vài dòng mẫu.
CSV có header `employee_id,timestamp,device_id`, dấu phẩy, quoting chuẩn CSV; BOM đầu file
được xử lý nếu có. Timestamp CSV là `YYYY-MM-DD HH:mm:ss`, được hiểu theo giờ Việt Nam.
Timestamp normalized là ISO 8601 có offset, ví dụ `2026-10-06T08:05:12+07:00`.
Ngày không hợp lệ phải reject, không chỉ kiểm tra regex; không âm thầm thay giờ lỗi bằng giờ hiện tại.

Ba nguồn có **schema record riêng**; chỉ dùng envelope chung để thống nhất cách xuất:

```json
{
  "schema_version": "1.0",
  "dataset": "attendance_events",
  "batch_id": "451e450c090647b30940282cd3ae57321d3b6246bb17e32cc3a7c91f4a90b5ba",
  "ingested_at": "2026-10-06T08:10:00+07:00",
  "records": [
    {
      "event_id": "1497d576e4bfd4038ae801f81440d143532e31787020a58d9260c2c8ee3a7f33",
      "employee_id": "E0012",
      "event_time": "2026-10-06T08:05:12+07:00",
      "work_date": "2026-10-06",
      "device_id": "GATE-1"
    }
  ]
}
```

`dataset` chỉ nhận `employees`, `shifts`, `attendance_events`. `records` luôn là array:
JDBC/REST xuất snapshot trọn bộ nhỏ; FTP xuất một event mỗi output để dedup xuyên file.
Không tự điền `check_in`, `worked_hours` cho dataset nhân viên/ca.
Quy tắc canonical/hash baseline, áp dụng sau transform và validation:

1. Chuỗi chuẩn Unicode NFC, trim khoảng trắng đầu/cuối; không gộp khoảng trắng bên trong
   tùy tiện. Riêng full_name dùng token để masking theo mục 5.2. ID/device cấm `|`.
2. Giữ đúng kiểu schema; null là JSON null, không chuyển thành chuỗi `"null"` hoặc bỏ field.
   Tất cả field normalized liệt kê trong specs phải xuất hiện, không có field dư.
3. Sort records tăng theo `employee_id` cho employees, `shift_id` cho shifts, `event_id`
   cho attendance_events. Khóa trong mỗi snapshot phải duy nhất.
4. Tạo object chỉ chứa `schema_version`, `dataset`, `records`; serialize compact JSON UTF-8,
   key object sort lexicographic, không indent/khoảng trắng thừa, không BOM/newline cuối,
   không escape Unicode thành ASCII, không escape `/`, không dùng NaN/Infinity.
5. `batch_id` là SHA-256 lowercase hex của đúng bytes ở bước 4. `ingested_at`, filename,
   source attributes và chính `batch_id` không nằm trong hash. `event_id` hash chuỗi ghép
   ở mục 5.4, cũng UTF-8 không BOM/newline, lowercase hex.

JSON trên là golden vector có hai hash đã tính độc lập để kiểm tra implementation NiFi.
Không hardcode chúng trong flow; thêm test cả Unicode, null và đảo thứ tự record/key.

| Dataset | Kiểu và ràng buộc record normalized |
|---|---|
| employees | Các field ở mục 5.2 là string NOT NULL, trừ `email_masked` có thể null; `status="active"`, `employee_id` khớp `E[0-9]{4}`, department_id `D[0-9]{2}`, shift_id S1/S2/S3; updated_at ISO8601 UTC với 6 chữ số phần giây và `+00:00` |
| shifts | shift_id/name/start_time/end_time string NOT NULL; shift_id S1/S2/S3; time là giờ hợp lệ `HH:mm:ss`; grace_minutes integer NOT NULL >=0 |
| attendance_events | Mọi field string NOT NULL; employee_id `E[0-9]{4}`, device_id `[A-Za-z0-9_-]{1,32}`, event_id hex64, event_time giờ Việt Nam với `+07:00`, work_date `YYYY-MM-DD` khớp event_time |

Envelope có đủ 5 field như mẫu, không có field dư; schema_version/dataset/batch_id/ingested_at
là string NOT NULL, records là array NOT NULL. Snapshot có thể rỗng (records=[]), vẫn cần
output để chứng minh nguồn đã được đọc; attendance output phải có đúng một event.
Source full_name/department_name/shift_name không rỗng; email null/blank → email_masked null.
Ví dụ masking: `Tran Thi B` → `Tran *** ***`, `tran.b@lab.invalid` → `t***@lab.invalid`.

### 5.2. MySQL và dataset employees

`hr_db.departments`: `department_id` PK, `department_name` NOT NULL.
`hr_db.employees`: `employee_id` PK, `full_name`, `dob`, `gender`, `department_id` FK,
`position`, `email`, `phone`, `base_salary`, `shift_id`, `hire_date`, `status`, `updated_at`.
`updated_at` có precision microsecond, tự cập nhật khi sửa; quy ước giá trị lưu UTC.
Seed xác định bằng seed cố định: 50 nhân viên, 5 phòng ban, 45 active và 5 resigned; 3 shift_id
khớp API. Seed chạy lại không nhân đôi dữ liệu; reset phải được chỉ định riêng.

NiFi JDBC chỉ đọc cột cần thiết: id, full_name, email, phòng ban, shift_id, status, updated_at.
Không đọc lương/phone/dob nếu không cần. SQL có thể join tên phòng; NiFi phải thực hiện
lọc active, masking và chuẩn hóa record. Output chỉ có `employee_id, full_name_masked,
department_id, department_name, email_masked, shift_id, status, updated_at`.
Masking deterministic: giữ token đầu của full_name, thay mỗi token còn lại bằng `***`;
email giữ ký tự đầu local-part + `***@` + domain. Không xuất các trường raw tương ứng.

Baseline đọc **full snapshot** mỗi 60 giây bằng QueryDatabaseTableRecord với maximum-value
columns để trống, hoặc ExecuteSQLRecord với SELECT rõ cột. Sau sửa fixture, snapshot kế tiếp
phải phản ánh sửa đổi. Output versioned là lịch sử snapshot, không phải bảng HR hiện hành.
Incremental `updated_at` là mở rộng: cần test cùng watermark, commit muộn, update/delete,
overlap/dedup; không gọi nó là CDC đầy đủ.
[QueryDatabaseTableRecord](https://nifi.apache.org/components/org.apache.nifi.processors.standard.QueryDatabaseTableRecord/).

### 5.3. REST API và dataset shifts

API chỉ cung cấp dữ liệu, không làm transform thay NiFi. Một object nguồn mẫu là
`{"id":"S1","name":"Ca hành chính","start":"08:00","end":"17:00","grace":10}`;
NiFi đổi tên field và chuẩn hóa time. Endpoint:

| Endpoint | Hợp đồng |
|---|---|
| `GET /health` | 200, JSON trạng thái tối thiểu, không trả secret |
| `GET /api/shifts` | Cần `X-API-Key`; 200 `{"shifts":[...]}` |
| `GET /api/shifts/{id}` | Cần key; 200 object ca; 404 nếu không tồn tại |
| `GET /api/slow` | Lab test: chờ 10s; cần key |
| `GET /api/error` | Lab test: 500 JSON; cần key |

Thiếu/sai key trả 401; JSON error không echo key. Test endpoints chỉ bật trong lab.
Snapshot đúng 3 ca S1 08:00–17:00 grace 10; S2 06:00–14:00 grace 0; S3 14:00–22:00 grace 0.
Record normalized: `shift_id, shift_name, start_time, end_time, grace_minutes`;
time dạng `HH:mm:ss`, grace integer không âm. NiFi bóc `shifts`, đổi tên/chuẩn hóa field,
validate rồi ghi envelope. Ngày lễ/API bên ngoài là tùy chọn; baseline demo chạy không cần Internet.

### 5.4. FTP và dataset attendance_events

Remote path nhìn từ FTP consumer là `/checkin`; OS mapping phải nằm trong inventory/runbook.
Producer upload tên duy nhất `.tmp` rồi rename `.csv`; không sửa đè một file `.csv` đã công bố.
NiFi chỉ list `.csv`, không recursive, không lấy `.tmp`; không di chuyển/xóa file nguồn baseline.
ListFTP để Record Writer trống cho flow từng-file; FetchFTP trỏ remote file theo `path/filename`
attributes thực tế, tránh ghép sai dấu `/`. Completion Strategy = None.
Persist listing state; reset state chỉ dùng trong test riêng sau khi ghi lại tác động.

Parse raw fields bằng schema chuỗi trước để không hỏng cả file vì một timestamp sai kiểu.
Có thể SplitRecord thành từng record cho lab, rồi validate/convert/router trong NiFi.
Thiếu id/time/device → reject; timestamp không tồn tại → reject; `work_date` lấy từ event_time local.
`event_id=SHA256(employee_id|event_time|device_id)` trên các giá trị normalized; dấu `|` bị cấm
trong id/device để khóa không mơ hồ. Quẹt cùng người, thiết bị và giây được coi là duplicate.
Baseline không cần lookup nhân viên để coi event hợp lệ; unknown id thuộc bài enrichment mở rộng.

Fixture baseline riêng: CSV có 10 record = 7 unique valid + 1 duplicate valid + 2 invalid
(một thiếu employee_id, một ngày không tồn tại). Thêm file malformed CSV riêng để test lỗi parse.
7 event hợp lệ ra 7 file; duplicate cùng file/xuyên file/replay không làm tăng số output duy nhất.
[ListFTP](https://nifi.apache.org/components/org.apache.nifi.processors.standard.ListFTP/),
[FetchFTP](https://nifi.apache.org/components/org.apache.nifi.processors.standard.FetchFTP/).

### 5.5. Output và rejected

Output trên VM NiFi: `/srv/nt132/output/<dataset>/<batch_id>.json`.
Hash từ nội dung canonical; dữ liệu giống nhau giữ cùng tên. PutFile xử lý conflict theo chế độ
ignore đã kiểm chứng; lần ingest đầu giữ metadata của nó. Nguồn của các lần replay xem qua Provenance.
Không dùng timestamp ngẫu nhiên làm tên file để rồi tuyên bố đã chống trùng.
Hash và envelope phải được tạo trong NiFi bằng Processor/script Processor phù hợp, có chú thích;
script chỉ được dùng cho phần nhỏ không thuận tiện bằng component sẵn có.

Record reject có `error_code, error_detail, source_filename/source_id, record_index` nếu có,
`observed_at`, và raw record giả đủ để sửa lỗi. Không đưa credential vào rejected.
Lỗi cú pháp đọc không được: giữ nguyên file trong `/srv/nt132/rejected/files/` kèm sidecar lý do;
lỗi record đọc được: `/srv/nt132/rejected/records/`; retry hết lượt tới
`/srv/nt132/rejected/dead-letter/`. Không gọi đây là hai dòng reject nếu parser
không đọc được số dòng. Tên reject ổn định theo source hash + index/error để replay không nhân bản.
`ValidateRecord` tách valid/invalid cho dữ liệu đọc được; lookup miss/duplicate cần logic riêng.
Reason codes tối thiểu: `MISSING_FIELD`, `INVALID_TIMESTAMP`, `INVALID_SCHEMA`, `PARSE_ERROR`,
`AUTH_DENIED`, `RETRY_EXHAUSTED`, `OUTPUT_ERROR`; thông tin chi tiết phải có context không lộ secret.
[ValidateRecord](https://nifi.apache.org/components/org.apache.nifi.processors.standard.ValidateRecord/).

## 6. Thiết kế flow và lỗi NiFi

| Group | Chuỗi xử lý tối thiểu |
|---|---|
| PG-JDBC | schedule → QueryDatabaseTableRecord/ExecuteSQLRecord → QueryRecord filter → UpdateRecord mask → schema/output |
| PG-REST | GenerateFlowFile request → InvokeHTTP → response JSON → record transform → schema/output |
| PG-FTP | ListFTP → FetchFTP → raw CSV reader → split/validate → normalize → schema/output |
| PG-OUTPUT | canonical/hash/envelope → PutFile, lỗi đích có retry hữu hạn |
| PG-ERROR | phân loại, counter/delay retry, rejected/dead-letter có nguyên nhân |

Được thay component tương đương khi ghi lý do và chứng minh vẫn đúng hợp đồng. Xác minh
component/bundle trong NiFi 2.12.0 thật; bảng này không thay danh sách properties cần export.
Mỗi Processor phải có schedule, concurrent tasks, reader/writer/schema, property, relationship,
parameter và queue config trong `nifi/`/runbook. Không ghi secrets vào flow export dùng để nộp.

Lịch source 60s, một concurrent task mỗi source cho lab; demo có thể Run Once.
Connect timeout 3s/read timeout 5s cho API để `/api/slow` gây timeout.
Retry tối đa 3 lần sau lần đầu, delay tối thiểu 5s mỗi lần; 401/403 và schema invalid không retry.
500/network timeout retry có giới hạn; quá giới hạn giữ request/data cùng nguyên nhân trong dead-letter.
Sau sửa lỗi có đường reprocess do operator được cấp quyền hoặc admin thực hiện.

`InvokeHTTP`: `Response` cho body thành công; `Original` thành công không đưa thành output lần hai;
`No Retry` xử lý 4xx; `Retry` xử lý 5xx; `Failure` cho lỗi kết nối/timeout. Xác minh status/attributes
thực tế, không nối tất cả về một vòng lặp.
`FetchFTP` phân biệt `comms.failure`, `not.found`, `permission.denied` theo component.
QueryDatabaseTableRecord không nhận input và không có relationship failure chung cho SQL lỗi:
ghi bulletin/log/yield và thử ở kỳ poll sau; nếu chọn ExecuteSQLRecord, đặc tả request/retry riêng.
[InvokeHTTP](https://nifi.apache.org/components/org.apache.nifi.processors.standard.InvokeHTTP/).

Mỗi queue đặt ví dụ back pressure 100 FlowFiles hoặc 10 MiB, expiration 0 cho baseline.
Đây là thông số lab để quan sát, phải đo và chỉnh nếu chia nhiều records. Test hạ ngưỡng xuống
10 để chứng minh upstream dừng khi downstream ngừng và chạy tiếp khi downstream phục hồi.
Không auto-terminate failure để làm flow xanh; mọi auto-termination phải có lý do trong manifest.

## 7. Vận hành NiFi, bảo mật và khôi phục

### 7.1. HTTPS và ba vai trò

Chọn X.509 client certificates cho admin/operator/manager, CA lab riêng + managed authorizer,
tránh thêm một LDAP/OIDC server ngoài đề tài. Single-user có thể dùng bootstrap, không đủ nghiệm thu RBAC.
Certificate server có SAN hostname/IP truy cập thật, còn hạn; client cert có identity khác nhau.
Ghi chính xác identity DN, identity mapping nếu có, initial admin và policy scopes; không bịa cấu hình.

| Identity | Được phép | Bị từ chối |
|---|---|---|
| admin | Cấu hình flow/services/users/policies trong lab | Không dùng để thay bài test role khác |
| operator | View + operate các PG được chỉ định | Modify flow, quản lý users/policies, raw content/replay nếu chưa cấp |
| manager | View canvas/status PG được chỉ định | Operate, modify, download raw content, replay, quản lý policies |

Quyền Provenance metadata/content có thể cần policy riêng; admin dùng nó demo truy vết.
Không cấp manager raw content chỉ để xem Provenance vì có dữ liệu trước masking.
API/curl kiểm tra bằng CA tin cậy và từng client certificate; browser demo phải có trust thực.
Không dùng `-k`/skip verification làm evidence TLS đạt. Private keys/API key/DB passwords được
giữ cục bộ ngoài artifacts công khai; ghi Parameter Context nhạy cảm, không log toàn bộ attributes.
HTTP nguồn và FTP thường chỉ dùng trong mạng lab cô lập, có giới hạn mã hóa được ghi trong báo cáo.

### 7.2. Theo dõi trực tiếp bằng NiFi

Phải quan sát được bulletin, processor run status/counters, queue object/bytes, back pressure,
Controller Services, Provenance của một FlowFile từ fetch đến PutFile và trường hợp reject.
Admin replay một FlowFile hợp lệ để kiểm tra idempotency; operator/manager không tự có quyền replay.
Theo dõi dung lượng repository, CPU/RAM, systemd và log liên quan NiFi/nguồn để giải thích lỗi.
Không cần xây dashboard mới. Mặc định giữ log/provenance 7 ngày trong giới hạn disk lab,
đặt dung lượng tối đa và kiểm tra option đúng bản; không xóa dữ liệu queue để giải phóng disk.

### 7.3. Backup/restore drill

Phân biệt export Process Group (thiết kế) với backup có khả năng khôi phục cấu hình/state/queue.
Tạo backup nhất quán khi NiFi đã dừng sạch, tạm ngừng producer và mutations nguồn trong lab:
flow/config, authorizer/user policies, state,
repositories cần cho queued data, sensitive properties key và TLS materials được bảo vệ.
Kèm manifest version/checksum, MySQL dump/seed, API fixtures/config và FTP files.
**Bắt buộc backup `/srv/nt132/output` và toàn bộ rejected/dead-letter cùng manifest/hash**:
output là kết quả và cũng là ledger chống trùng bằng tên file. Restore listing state mà thiếu
output cũ có thể bỏ sót các file đã được ghi nhận, nên không được coi là restore hoàn chỉnh.
Sensitive backup giữ ngoài repo nộp, có quyền truy cập hạn chế và cách cấp lại secret.

Restore sang VM/instance cô lập, cùng version và đường dẫn phù hợp; không khởi động bản sao
cùng lúc với production lab để tránh cùng poll nguồn. Chứng minh có thể mở UI, services hợp lệ,
policy còn đúng, queue khôi phục, tập khóa/file/hash output và rejected khớp backup trước restore.
Sau đó resume để chứng minh queued records đi tiếp và không làm tăng output trùng. Ghi RPO/RTO **đo được**;
không cam kết HA hoặc phục hồi dữ liệu chưa nằm trong backup.
Trước reboot test lưu số liệu input/output/rejected/queue; sau reboot đối chiếu số lượng/hashes.
Không tuyên bố exactly-once hoặc “không mất dữ liệu” ngoài các tình huống thực sự đã kiểm tra.

## 8. Nghiệm thu và evidence

Trạng thái test: `NOT_RUN`, `PENDING_ENVIRONMENT`, `BLOCKED`, `PASS`, `FAIL`.
PASS phải có timestamp có timezone, môi trường/version, thao tác/lệnh, expected, actual,
log/exit code/ảnh phù hợp và đường dẫn evidence. Check syntax/mock không thay integration test.

| ID | Nội dung kiểm thử | Kết quả mong đợi |
|---|---|---|
| TC-01 | Preflight + version/architecture/inventory | Khớp manifest, biết IP/route/port/path thật |
| TC-02 | NiFi UI HTTPS có trust | Đúng SAN, cert hợp lệ; browser/curl xác thực được |
| TC-03 | Kết nối NiFi → ba nguồn | JDBC query, HTTP request, FTP list+download thực sự thành công |
| TC-04 | Firewall thử từ host được phép và host bị cấm | Đúng ma trận; không chỉ ping |
| TC-05 | MySQL source user SELECT và thử INSERT/UPDATE | Đọc được, ghi bị từ chối; thử trong lab có kiểm soát |
| TC-06 | PG-JDBC full snapshot seed | Nguồn 50; normalized 45 active, đúng 5 phòng ban liên kết |
| TC-07 | Transform JDBC + leakage check | Mask đúng; không có salary/phone/dob/full_name/email raw ở output |
| TC-08 | Insert/update/đổi ca/đổi department/resigned | Snapshot mới phản ánh thay đổi, không lệ thuộc watermark |
| TC-09 | DB dừng/sai mật khẩu rồi phục hồi | Bulletin/log rõ; poll lại thành công, không bịa failure route |
| TC-10 | PG-REST key đúng + normalize | 3 ca, schema/time/grace đúng |
| TC-11 | Key thiếu/sai | 401, không retry vô hạn, không lộ key |
| TC-12 | API500 + timeout10s + API offline | Retry đúng giới hạn/delay, dead-letter còn request và lý do |
| TC-13 | Sửa API, reprocess một request lỗi | Đọc được 3 ca, không nhân bản output cùng nội dung |
| TC-14 | FTP `.tmp` rồi rename `.csv` | Chỉ lấy sau rename, passive list/download được |
| TC-15 | CSV baseline10 records | 7 output event, 1 duplicate, 2 rejects có lý do; tổng bằng10 |
| TC-16 | Malformed CSV, sai header/encoding | Quarantine file hoặc reject đúng cấp, không làm mất file gốc |
| TC-17 | Sai user/quyền/path FTP, FTP tắt rồi bật | Báo lỗi đúng loại, reprocess/poll theo thiết kế có kiểm chứng |
| TC-18 | Poll lại + cùng event ở filename mới | Listing đúng; output không tăng với event đã có |
| TC-19 | Output schema/hash/content | Envelope và 3 schema riêng đúng; hash khớp golden vector và ổn định khi đảo keys/records; empty snapshot có output |
| TC-20 | Tạm ngừng/thu hồi quyền ghi đích trong lab | FlowFile còn queue/retry/dead-letter; sửa quyền rồi ghi được |
| TC-21 | Back pressure có downstream stop/resume | Quan sát ngưỡng, upstream ngừng rồi chạy tiếp, queue drain |
| TC-22 | Provenance success + rejected | Truy vết đủ fetch/transform/route/output, thấy quan hệ input-output |
| TC-23 | Replay một event | Output unique không tăng; vẫn có provenance lần replay |
| TC-24 | Admin/operator/manager độc lập | Quyền đúng bảng; thao tác bị cấm bị từ chối thực tế |
| TC-25 | Thiếu/untrusted client cert, không có quyền content | Không truy cập trái phép; manager không tải raw/replay |
| TC-26 | Restart NiFi, có queued FlowFiles | State/queue được phục hồi theo thiết kế; số lượng/hash đối chiếu đúng |
| TC-27 | Reboot VM dịch vụ | Autostart, đường kết nối và NiFi flow dùng được sau reboot |
| TC-28 | Backup + restore vào instance cô lập | Khôi phục flow/config/state/queue/policies và output/rejected; so tập file/khóa/hash trước-sau, resume queue và đo thời gian |
| TC-29 | Disk/log/repository monitoring + export không secrets | Có cách kiểm tra và retention; backup nhạy cảm không lẫn artifact nộp |
| TC-30 | Demo tái lập từ runbook | Trình bày được 3 connectors, transforms và tình huống vận hành NiFi |

Nghiệm thu count ở TC-15 theo record đọc được: `10 = 7 unique accepted + 1 duplicate + 2 rejected`.
Malformed file là test riêng, không suy ra số record khi parse thất bại. Với crash/retry, so sánh
**tập khóa output** và rejected, không dùng counter Processor như bằng chứng duy nhất.
Ghi baseline trước từng test mutation; hoàn nguyên fixture có kiểm soát để các test không ảnh hưởng nhau.

## 9. Mở rộng enriched attendance — không chặn baseline

Nếu thực hiện: attendance là fact → LookupRecord nhân viên/phòng ban → LookupRecord ca
bằng DB/REST lookup services có key rõ. Writer phải chứa trường enrichment; lookup miss có route riêng.
Không phụ thuộc ba flow ngẫu nhiên chạy xong cùng lúc; có readiness/reference version trong test.
QueryRecord gộp chỉ trong FlowFile; lab mở rộng dùng một file đầy đủ cho một ngày, chỉ xử lý sau
khi file đã đóng. Nếu nhiều file/ngày phải thiết kế state/window và dữ liệu đến muộn trước khi code.

Quy tắc lab: ca trong ngày, không qua đêm; mỗi người/ngày có ít nhất hai lượt, sớm nhất/về
muộn nhất. Một lượt → `INCOMPLETE`, giờ ra và worked_hours null; không tính 0 giờ như đủ dữ liệu.
`worked_hours = round((check_out-check_in)/3600, 2)` là elapsed, không trừ nghỉ, không phải tính lương.
`late_minutes = max(0, ceil((check_in-shift_start)/60)-grace_minutes)`; S1 08:05→0, 08:15→5.
Ca/ngày tham chiếu cố định trong fixture; chưa hỗ trợ lịch sử đổi ca, overnight, ngày lễ/tăng ca.
Unknown employee/shift → reject nghiệp vụ. Nếu cần các trường hợp ngoài phạm vi, bổ sung specs/test trước.
[LookupRecord](https://nifi.apache.org/components/org.apache.nifi.processors.standard.LookupRecord/),
[QueryRecord](https://nifi.apache.org/components/org.apache.nifi.processors.standard.QueryRecord/).

## 10. Điều kiện hoàn thành

Gates và trạng thái thật nằm ở `docs/IMPLEMENTATION_STATUS.md`. NiFi baseline chỉ hoàn thành
khi TC-01..TC-30 có evidence đạt; một test thiếu môi trường chưa được đổi thành PASS.
Điểm rubric chưa được xác nhận vẫn phải ghi rõ; không tự cam kết đồ án đã đạt yêu cầu thầy.
Mọi phần chưa chạy được phải báo trong chat và ghi vào `docs/MANUAL_ACTIONS.md`, có prerequisite,
artifact đã chuẩn bị, bước bàn giao và cách kiểm chứng. Tiếp tục các việc độc lập còn làm được.

Bộ nộp tối thiểu: source/config có thể tái dựng, manifest, schemas/fixtures, flow export,
mapping Processor/Controller Services/parameters/relationships, báo cáo kiểm thử, runbook
vận hành/khôi phục, báo cáo môn học, nội dung slide và kịch bản demo Apache NiFi.
Ảnh/log phải lấy từ lab thật, che secrets. Báo cáo tập trung vào NiFi và giải thích cấu hình mạng
cần cho NiFi; không thay các trang kết quả NiFi bằng một ứng dụng nhân sự tự xây.
