# Khung flow NiFi — cấu hình đã dựng thủ công trên VM1

Cập nhật: 17/11/2026 (Asia/Ho_Chi_Minh). NiFi 2.12.0 trên VM1 Kali ARM64, HTTPS `localhost:8443`.

**Trạng thái 17/11:** PG-REST, PG-JDBC, PG-OUTPUT, PG-ERROR đã dựng và chạy tới PutFile
([evidence G3](../evidence/G3/2026-11-17_pg-rest-jdbc_first-run.md)); PG-FTP còn dở (chưa chạy).
Flow export thật: [`flows/nt132-flow_2026-11-17.json`](flows/nt132-flow_2026-11-17.json) — import bằng
*Upload flow definition*, sau đó nạp lại 3 sensitive parameter. Cấu hình qua REST API bằng
[`tools/nifi_api.py`](tools/nifi_api.py) (chạy `sudo` trên VM1, đọc tài khoản từ `/root/nt132-secrets/`).
Các mục "DỰ KIẾN" bên dưới giữ làm thiết kế; chỗ khác với bản đã dựng được ghi ở mục *Đã dựng 17/11*.

File này ghi lại cấu hình **đã dựng bằng UI** để người khác dựng lại khi chưa có flow export.
Trạng thái: theo xác nhận của Trường ngày 09–10/11/2026; evidence xem
[evidence/G2/2026-11-09_vm1_nifi-bootstrap.md](../evidence/G2/2026-11-09_vm1_nifi-bootstrap.md).
Chưa có flow definition export trong repo. Khi export từ NiFi thật, lưu vào thư mục này
và thay bảng dưới bằng file export; giá trị sensitive không được xuất ra file.

## Parameter Context `nt132-params`

Gán cho cả 5 PG. Hostname `*.lab` sẽ được map trong `/etc/hosts` của VM1 khi có IP lab,
để đổi IP không phải sửa Processor.

| Parameter | Giá trị hiện tại | Sensitive |
|---|---|---|
| `db_url` | `jdbc:mysql://db.lab:3306/hr_db` | No |
| `db_user` | `db_reader` | No |
| `db_password` | đã nạp 17/11 | Yes |
| `db_driver_path` | `/opt/nifi/drivers` | No |
| `api_base_url` | `http://api.lab:5000` | No |
| `api_key` | đã nạp 17/11 | Yes |
| `ftp_host` | `ftp.lab` (17/11; trước là IP hotspot) | No |
| `ftp_port` | `21` | No |
| `ftp_user` | `nifi_fetch` | No |
| `ftp_password` | đã nạp 17/11 (reader `nifi_fetch` VM ftp mới) | Yes |
| `ftp_remote_path` | `/checkin` | No |
| `output_dir` | `/srv/nt132/output` | No |
| `rejected_dir` | `/srv/nt132/rejected` | No |

## Process Groups và ports

| PG | Input Port | Output Port |
|---|---|---|
| `PG-JDBC` | — | `to-output`, `to-error` |
| `PG-REST` | — | `to-output`, `to-error` |
| `PG-FTP` | — | `to-output`, `to-error` |
| `PG-OUTPUT` | `in` | `to-error` |
| `PG-ERROR` | `in` | — |

Connection ở canvas gốc (7): ba PG nguồn `to-output` → `PG-OUTPUT/in`; ba PG nguồn `to-error`
→ `PG-ERROR/in`; `PG-OUTPUT/to-error` → `PG-ERROR/in`. Mỗi connection: Back Pressure Object
Threshold `100`, Size Threshold `10 MB`, FlowFile Expiration `0 sec`, không load balance.

## PG-OUTPUT

`in` → `PutFile` → (`failure`) → `to-error`.

| Property / thiết lập | Giá trị |
|---|---|
| Directory | `#{output_dir}/${dataset}` |
| Conflict Resolution Strategy | `ignore` |
| Create Missing Directories | `true` |
| Relationship `success` | auto-terminate (đã ghi file; vết nằm trong Provenance) |
| Relationship `failure` | retry 3 lần, Penalize; hết lượt → `to-error` |

Chưa làm: canonical JSON/hash/envelope trước PutFile; chặn FlowFile thiếu attribute `dataset`
(hiện sẽ ghi thẳng vào `/srv/nt132/output`); nội dung `PG-ERROR`, `PG-JDBC`, `PG-REST`, `PG-FTP`.

## Cấu hình demo đợt 1 — DỰ KIẾN, chưa chạy (16/11/2026)

Mục tiêu đợt này: mỗi PG có một luồng cơ bản chạy được để demo trước với giảng viên;
chưa có canonical/envelope/`batch_id` theo SPECS 5.1, chưa có retry đầy đủ theo SPECS 6.
Tên property/relationship đã đối chiếu tài liệu chính thức NiFi 2.12.0 (nifi.apache.org/components)
ngày 16/11; chưa kiểm tra trên VM1. Khi dựng xong, chụp/ export và chuyển mục này thành cấu hình đã dựng.

### Controller Services (tạo ở canvas gốc *NiFi Flow* → Controller Services, để 5 PG dùng chung)

| Tên | Loại | Property cần đặt |
|---|---|---|
| `CSVReader-attendance` | CSVReader | Schema Access Strategy = `Use String Fields From Header`; CSV Format = `RFC 4180`; Treat First Line as Header = `true` |
| `JsonTreeReader-default` | JsonTreeReader | Schema Access Strategy = `Infer Schema` |
| `JsonWriter-default` | JsonRecordSetWriter | Schema Write Strategy = `Do Not Write Schema`; Output Grouping = `Array`; Pretty Print JSON = `false` |
| `JsonWriter-employees` | JsonRecordSetWriter | Như trên + Timestamp Format = `yyyy-MM-dd'T'HH:mm:ss.SSSSSS'+00:00'` (cần kiểm tra giá trị UTC thực tế) |
| `DBCP-hr_db` | DBCPConnectionPool | Database Connection URL = `#{db_url}`; Database Driver Class Name = `com.mysql.cj.jdbc.Driver`; Database Driver Locations = `#{db_driver_path}`; Database User = `#{db_user}`; Password = `#{db_password}`; Validation Query = `SELECT 1` |

Driver: tải MySQL Connector/J từ dev.mysql.com vào `/opt/nifi/drivers/`, `chown nifi:nifi`,
ghi version + `sha256sum` vào `docs/DEPLOYMENT_ARCHITECTURE.md`.

### PG-FTP — `ListFTP → FetchFTP → SplitRecord → UpdateAttribute → to-output`

| Processor | Property / thiết lập | Relationship |
|---|---|---|
| `ListFTP-checkin` | Hostname `#{ftp_host}`, Port `#{ftp_port}`, Username `#{ftp_user}`, Password `#{ftp_password}`, Remote Path `#{ftp_remote_path}`, File Filter Regex `.*\.csv`, Search Recursively `false`, Connection Mode `Passive`, Listing Strategy `Tracking Timestamps`, Record Writer để trống; Run Schedule `60 sec`, Execution `Primary node` | `success` → FetchFTP |
| `FetchFTP` | Hostname/Port/Username/Password như ListFTP; Remote File `${path}/${filename}`; Completion Strategy `None` | `success` → SplitRecord; `comms.failure`, `not.found`, `permission.denied` → `to-error` |
| `SplitRecord` | Record Reader `CSVReader-attendance`, Record Writer `JsonWriter-default`, Records Per Split `1` | `splits` → UpdateAttribute; `failure` → `to-error` (file không parse được); `original` auto-terminate (file gốc còn trên FTP và trong Provenance) |
| `UpdateAttribute` | thêm `dataset` = `attendance_events` | `success` → `to-output` |

Chưa làm ở đợt này: ValidateRecord/route lỗi record, chuẩn hóa `event_time` +07:00/`work_date`, `event_id`, dedup.

### PG-REST — `GenerateFlowFile → InvokeHTTP → JoltTransformJSON → UpdateAttribute → to-output`

| Processor | Property / thiết lập | Relationship |
|---|---|---|
| `GenerateFlowFile-request` | để mặc định (FlowFile rỗng làm request); Run Schedule `60 sec` hoặc *Run Once* khi demo | `success` → InvokeHTTP |
| `InvokeHTTP-shifts` | HTTP Method `GET`; HTTP URL `#{api_base_url}/api/shifts`; Connection Timeout `3 secs`; Socket Read Timeout `5 secs`; dynamic property `X-API-Key` = `#{api_key}` (chọn Sensitive khi thêm property) | `Response` → Jolt; `Original` auto-terminate (tránh ghi output lần hai); `Retry`, `No Retry`, `Failure` → `to-error` |
| `JoltTransformJSON` | Jolt Transform `Chain`; Jolt Specification như dưới | `success` → UpdateAttribute; `failure` → `to-error` |
| `UpdateAttribute` | `dataset` = `shifts` | `success` → `to-output` |

```json
[
  {"operation": "shift", "spec": {"shifts": {"*": {
    "id": "[&1].shift_id", "name": "[&1].shift_name",
    "start": "[&1].start_time", "end": "[&1].end_time",
    "grace": "[&1].grace_minutes"}}}},
  {"operation": "modify-overwrite-beta", "spec": {"*": {
    "start_time": "=concat(@(1,start_time),':00')",
    "end_time": "=concat(@(1,end_time),':00')"}}}
]
```

Kết quả mong đợi: array 3 ca, ví dụ `{"shift_id":"S1","shift_name":"Ca hành chính","start_time":"08:00:00","end_time":"17:00:00","grace_minutes":10}`.
Chờ: API của Trung bind ra IP lab (hiện mặc định `127.0.0.1:5000`). Retry 3 lần/5 s cho 5xx/timeout làm ở đợt sau.

### PG-JDBC — `ExecuteSQLRecord → QueryRecord → UpdateRecord → UpdateAttribute → to-output`

| Processor | Property / thiết lập | Relationship |
|---|---|---|
| `ExecuteSQLRecord-employees` | Database Connection Pooling Service `DBCP-hr_db`; SQL Query = nội dung `sql/10_nifi_select_employees.sql` (nhánh `trung/db-api`); Record Writer `JsonWriter-employees`; Run Schedule `60 sec`, không cần upstream | `success` → QueryRecord; `failure` → `to-error` |
| `QueryRecord-active` | Record Reader `JsonTreeReader-default`, Record Writer `JsonWriter-employees`; dynamic property `active` = SQL dưới | `active` → UpdateRecord; `failure` → `to-error`; `original` auto-terminate (raw chưa mask, không được xuất) |
| `UpdateRecord-mask` | Reader/Writer như trên; Replacement Value Strategy `Literal Value`; `/full_name_masked` = `${field.value:trim():replaceAll('\s+\S+', ' ***')}`; `/email_masked` = `${field.value:replaceAll('^(.)[^@]*@', '$1***@')}` | `success` → UpdateAttribute; `failure` → `to-error` |
| `UpdateAttribute` | `dataset` = `employees` | `success` → `to-output` |

```sql
SELECT employee_id, full_name AS full_name_masked, department_id, department_name,
       email AS email_masked, shift_id, status, updated_at
FROM FLOWFILE WHERE status = 'active'
```

Mong đợi: 45 record active, `Tran Thi B` → `Tran *** ***`, `tran.b@lab.invalid` → `t***@lab.invalid`.
Cần kiểm tra: email null phải giữ null (EL có thể trả chuỗi rỗng), định dạng `updated_at`.
Chờ: VM DB của Trung có IP lab, grant `db_reader` theo IP VM1, driver.

### PG-OUTPUT và PG-ERROR (bản demo)

PG-OUTPUT: `in → RouteOnAttribute → CryptographicHashContent → UpdateAttribute → PutFile`.

| Processor | Property / thiết lập | Relationship |
|---|---|---|
| `RouteOnAttribute-dataset` | Routing Strategy `Route to Property name`; dynamic `valid` = `${dataset:in('employees','shifts','attendance_events')}` | `valid` → hash; `unmatched` → `to-error` |
| `CryptographicHashContent` | Hash Algorithm `SHA-256` (ghi attribute `content_SHA-256`; kiểm tra tên attribute trong Provenance) | `success` → UpdateAttribute; `failure` → `to-error` |
| `UpdateAttribute-filename` | `filename` = `${content_SHA-256}.json` | `success` → PutFile |
| `PutFile` | giữ cấu hình ở mục PG-OUTPUT trên | như trên |

Tên file theo hash nội dung để cùng nội dung giữ cùng tên; đây là bước tạm, chưa phải
`batch_id` canonical của SPECS 5.1.

PG-ERROR: `in → PutFile-rejected` với Directory `#{rejected_dir}/dead-letter`, Conflict Resolution
Strategy `ignore`, Create Missing Directories `true`; `success` auto-terminate (đã ghi file);
`failure` → Funnel `error-hold` để FlowFile nằm lại trong queue, không bị mất.

## Đã dựng 17/11/2026 — khác biệt so với thiết kế đợt 1

| Thành phần | Cấu hình thật |
|---|---|
| Controller Services | Gốc: `JsonWriter-output` (JsonRecordSetWriter mặc định), `CSVReader-attendance-raw` (header-derived). PG-REST: `JsonTreeReader` (Schema Text = record `shift`). PG-JDBC: `DBCP-hr_db-source` (Max Total Connections 2, `SELECT 1`), `JsonTreeReader-infer`, `JsonWriter-employees-source` (Timestamp Format `yyyy-MM-dd'T'HH:mm:ss.SSSSSS'+00:00'`) |
| PG-REST | Như thiết kế + `ValidateRecord-shifts` (Allow Extra Fields `false`, Strict Type Checking `true`, `validation.details`). InvokeHTTP: Connection Timeout 3 s, Socket Read Timeout 5 s, `Original` auto-terminate (đã có Response làm output); framework retry `Retry`,`Failure` 3 lần, PENALIZE_FLOWFILE 5 s → max 30 s; `No Retry`/hết lượt → `to-error`. GenerateFlowFile 60 s (test dùng Run Once) |
| PG-JDBC | ExecuteSQLRecord giữ SQL JOIN của nhóm (chọn cột, không lọc status), writer `JsonWriter-employees-source`, Use Avro Logical Types `true`, 60 s, failure retry 3 → `to-error`. `QueryRecord-active`: `TRIM(full_name) AS full_name_masked`, `CASE WHEN TRIM(email)='' THEN NULL ELSE TRIM(email) END AS email_masked`, `WHERE status='active'`; `original` auto-terminate (raw chưa mask không được xuất). `UpdateRecord-mask` (Record Path Value): `/full_name_masked = replaceRegex(/full_name_masked, '[ ]+[^ ]+', ' ***')`, `/email_masked = replaceRegex(/email_masked, '^(.)[^@]*@', '$1***@')` — email null giữ null |
| PG-OUTPUT | `in → RouteOnAttribute-dataset → CryptographicHashContent-sha256 → UpdateAttribute-filename → PutFile`; `unmatched`/`failure` → `to-error`. Tên file = SHA-256 nội dung (tạm, chưa phải `batch_id` canonical) |
| PG-ERROR | `in → PutFile-dead-letter` (`#{rejected_dir}/dead-letter`, ignore, `success` auto-terminate); `failure` → funnel giữ FlowFile |
| Queues | Mọi connection đã tạo/sửa: 100 FlowFiles / 10 MB, expiration 0 |
| PG-FTP | Mới có `ListFTP-checkin → FetchFTP` và processor rời (`SplitRecord`, `GenerateFlowFile`) chưa nối — chờ fixture CSV |

Còn thiếu so với SPECS: envelope + `batch_id`/canonical JSON (5.1), sort records, validation `HH:mm:ss`
và regex ID, sidecar lý do lỗi + reason code trong PG-ERROR, thử retry bằng `/api/error`/`/api/slow`.
