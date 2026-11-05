# KẾ HOẠCH HOÀN CHỈNH – ĐỒ ÁN NT132
## Apache NiFi – Thu thập, biến đổi và quản trị luồng dữ liệu đa nguồn

**Bối cảnh minh họa:** dữ liệu nhân sự và chấm công giả. **Sản phẩm chính:** Apache NiFi và các flow, không phải ứng dụng quản lý nhân sự.

> Môn: System and Network Administration (NT132) · Quản trị mạng
> Phiên bản tài liệu: v3.1 (đã rà soát kỹ thuật, bổ sung specs) – 19/10/2026
> Mục đích file này: bất kỳ thành viên nào trong nhóm đọc vào cũng hiểu toàn bộ đề tài và biết phải làm gì, theo thứ tự nào.

> Đọc cùng [SPECS.md](SPECS.md) để triển khai/nghiệm thu và [REVIEW.md](REVIEW.md) để biết các thiếu sót của bản v3.0. [agent.md](agent.md) hướng dẫn Claude Code; [CLAUDE.md](CLAUDE.md) nạp hướng dẫn đó. Đây là baseline kỹ thuật đề xuất, chưa có rubric/ảnh ghi chú gốc của thầy để đối chiếu. Chưa có bằng chứng triển khai runtime; trạng thái nằm ở [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md).

---

## MỤC LỤC

- Phần A – Tóm tắt nhanh (đọc cái này trước)
- Phần B – Đề tài là gì và vì sao làm
- Phần C – Kiến thức nền cần nắm (NiFi, JDBC, REST API, FTP)
- Phần D – Bối cảnh ứng dụng: nhân sự và chấm công
- Phần E – Kiến trúc hệ thống
- Phần F – Thiết kế chi tiết từng nguồn (có hướng dẫn việc cần làm)
- Phần G – Kế hoạch 6 tuần và phân công
- Phần H – Bảng test case
- Phần I – Rủi ro và cách xử lý
- Phần J — Câu hỏi cần xác nhận với thầy (QUAN TRỌNG)
- Phần K – Checklist hoàn thành

---

# PHẦN A – TÓM TẮT NHANH

**Đề tài:** Dùng Apache NiFi làm trung tâm để **lấy (Get)** dữ liệu từ 3 nguồn khác nhau và **biến đổi (Transform)** thành các dataset JSON chuẩn hóa, chứng minh kết nối và quản trị luồng dữ liệu. Nhân sự/chấm công chỉ cung cấp dữ liệu minh họa.

**Ba nguồn và ba kiểu kết nối:**

| Nguồn | Hệ thống giả lập | Kết nối |
|---|---|---|
| Cơ sở dữ liệu `hr_db` | Phần mềm nhân sự | **JDBC** |
| REST API | Hệ thống ca làm việc | **REST API** |
| FTP server | Máy chấm công xuất file | **FTP** |

**Profile đề xuất:** 4 VM cho NiFi, Database (MySQL), FTP (vsftpd), API (Flask + Gunicorn). Có profile 2 VM nếu máy yếu; cần thầy chấp nhận cách bố trí. Phân biệt bốn dịch vụ với bốn máy ảo.

**Phạm vi theo lời thầy:** chỉ "Get" và "Transform", không đi sâu phân tích hay lưu trữ phức tạp. Toàn bộ dữ liệu là **dữ liệu giả** do nhóm tạo.

**Kết quả baseline:** ba Process Group NiFi lấy và transform JDBC/REST/FTP, xuất ba dataset riêng theo envelope chung qua PutFile. Có Controller Services, schema, rejected/retry, queue/back pressure, Provenance, HTTPS/RBAC và backup/restore được kiểm tra. Kèm flow export, bằng chứng, báo cáo, slide và demo Apache NiFi. Bảng chấm công hợp nhất và `report_db` là mở rộng.

**Việc quan trọng nhất phải làm sớm:** hỏi thầy 6 câu ở Phần J, vì câu trả lời quyết định khối lượng công việc.

---

# PHẦN B – ĐỀ TÀI LÀ GÌ VÀ VÌ SAO LÀM

## B.1. Bối cảnh

Trong một công ty, dữ liệu nằm rải rác ở nhiều hệ thống: phần mềm nhân sự (cơ sở dữ liệu), hệ thống quản lý ca làm việc, và máy chấm công (xuất ra file). Mỗi nơi lưu một kiểu, dùng một giao thức khác nhau. Muốn trả lời một câu đơn giản như "hôm nay ai đi trễ?" thì phải tra cả ba nơi rồi đối chiếu bằng tay.

Bài toán này gọi là **tích hợp dữ liệu (data integration)**: thu thập dữ liệu từ nhiều nguồn không đồng nhất, làm sạch, chuẩn hóa và đưa về một dạng thống nhất.

## B.2. NiFi làm vai trò gì

Apache NiFi là "trung tâm gom và làm sạch dữ liệu". Nó tự động lấy dữ liệu từ ba nguồn, biến đổi về một định dạng chung, rồi giao kết quả cho người quản lý. Đây là một **hệ thống chạy ngầm (backend)**, **không phải website** — người quản lý nhận kết quả (file hoặc bảng), không cần một giao diện web do nhóm tự xây.

## B.3. Phạm vi (theo đúng ghi chú của thầy)

Theo phần ghi lại trong plan, thầy nêu ba ý (chưa có ảnh ghi chú gốc trong repo để đối chiếu):

1. **Chỉ "Get" và "Transform":** lấy dữ liệu từ nhiều nguồn và biến đổi, không đi sâu vào phân tích hay lưu trữ phức tạp.
2. **Build ứng dụng:** tự dựng Database và Server để có nguồn dữ liệu thật.
3. **Test các kiểu kết nối:** JDBC, REST API, File qua FTP... (ghi chú có dấu "...", nên có thể còn kiểu khác).

**Phần nhóm tự hiểu (chưa được thầy xác nhận):**

| Server | Mức chắc chắn | Lý do |
|---|---|---|
| Database server | Chắc chắn cần | Thầy nói rõ "dựng database", cần cho JDBC |
| NiFi server | Chắc chắn cần | NiFi là ứng dụng của đề tài |
| FTP server | Gần như chắc chắn | Cần nơi chứa file để test FTP |
| API server | Tùy chọn | Có thể dùng API có sẵn thay vì tự dựng |

## B.4. Lý do chọn đề tài

- Tích hợp dữ liệu là nhu cầu phổ biến thực tế (ngân hàng, bán lẻ, nhà máy, y tế, vận hành IT).
- Đề tài có đủ các mảng của môn Quản trị mạng: cài đặt dịch vụ, cấu hình mạng, quản lý người dùng và phân quyền, bảo mật, giám sát, sao lưu.
- Kết quả dễ kiểm chứng và dễ demo: dữ liệu vào, dữ liệu ra, quan sát được từng bước.

---

# PHẦN C – KIẾN THỨC NỀN CẦN NẮM

## C.1. Apache NiFi

**Hiểu đơn giản:** NiFi giống một **hệ thống ống nước cho dữ liệu**. Dữ liệu chảy vào từ nhiều nơi, đi qua các van và bộ lọc để được làm sạch, rồi chảy ra đúng chỗ. Người dùng chỉ cần kéo thả và nối các khối trên màn hình.

**Định nghĩa:** NiFi là nền tảng mã nguồn mở (Apache License 2.0) để tự động hóa luồng dữ liệu giữa các hệ thống. Có giao diện web kéo-thả để thu thập, định tuyến, biến đổi và phân phối dữ liệu, kèm truy vết nguồn gốc (provenance), xử lý lỗi, back pressure và mở rộng theo cụm.

**Phiên bản baseline:** **NiFi Standard 2.12.0 + JDK 21**. Trang [download chính thức](https://nifi.apache.org/download/) kiểm tra ngày 19/10/2026 ghi bản 2.12.0 phát hành ngày 13/09/2026. Khóa phiên bản, patch/architecture và JDBC driver trong manifest trước khi cài; không tự đổi sang `latest` hoặc suy ra mọi JDK mới hơn đều phù hợp. [Yêu cầu hệ thống](https://nifi.apache.org/nifi-docs/administration-guide.html#system_requirements).

**Các khái niệm cốt lõi phải thuộc:**

| Khái niệm | Nghĩa |
|---|---|
| FlowFile | Đơn vị dữ liệu chạy trong NiFi (nội dung + thuộc tính mô tả) |
| Processor | Khối xử lý: lấy, biến đổi, định tuyến, gửi |
| Connection | Đường nối hai Processor, có hàng đợi (queue) |
| Relationship | "Cửa ra" của Processor: success, failure, retry |
| Process Group | Nhóm các Processor thành một module |
| Controller Service | Dịch vụ dùng chung (ví dụ kết nối cơ sở dữ liệu) |
| Data Provenance | Nhật ký truy vết nguồn gốc và các bước biến đổi |
| Back pressure | Tự "đóng van" khi hàng đợi quá đầy |

**Kiến trúc bên trong NiFi:** chạy trên JVM, gồm Web Server (giao diện + REST API quản trị), Flow Controller (điều phối chạy Processor), Extensions (plugin), và các kho FlowFile Repository, Content Repository, Provenance Repository. Các kho bền vững hỗ trợ khôi phục và truy vết; phải kiểm tra restart/restore, lưu state/repository đúng cách và chống trùng tại output. Không mặc định bảo đảm không mất dữ liệu hoặc exactly-once cho mọi sự cố.

**Ví dụ đời thường:** NiFi giống trung tâm phân loại bưu kiện — bưu kiện đến từ nhiều nơi, được mở ra, dán nhãn chuẩn chung, chia vào đúng xe. Mỗi bưu kiện có mã vạch để tra đã đi qua bước nào.

## C.2. Ba kiểu kết nối trong đề tài

### JDBC
- **Hiểu đơn giản:** cây cầu giúp chương trình Java nói chuyện với cơ sở dữ liệu.
- **Định nghĩa:** JDBC (Java Database Connectivity) là API chuẩn của Java để kết nối và truy vấn cơ sở dữ liệu quan hệ, qua driver riêng của từng hệ quản trị (MySQL, PostgreSQL…).
- **Trong đề tài:** NiFi dùng tài khoản chỉ đọc lấy hồ sơ nhân viên từ MySQL.
- **Ví dụ đời thường:** như thủ thư tra sổ danh mục rồi đưa đúng cuốn cần tìm.

### REST API
- **Hiểu đơn giản:** quầy phục vụ — hỏi bằng một địa chỉ, quầy trả lại đúng thông tin.
- **Định nghĩa:** giao diện truy cập dữ liệu qua HTTP theo kiến trúc REST, trả JSON kèm mã trạng thái (200 ok, 401 chưa xác thực, 404 không tìm thấy, 500 lỗi server).
- **Trong đề tài:** nhóm tự dựng API nguồn ca làm tối thiểu; ngày lễ là mở rộng.
- **Lưu ý:** NiFi cũng có REST API riêng để quản trị chính nó (đường dẫn `/nifi-api`), khác với API ca làm việc là nguồn dữ liệu. Đây là phần tùy chọn (Use-case 6).
- **Ví dụ đời thường:** như gọi món ở quầy order; hết món thì báo "hết rồi" (lỗi 404).

### FTP
- **Hiểu đơn giản:** cái tủ gửi đồ chung — người này bỏ file vào, người kia đến lấy sau, hai bên không cần gặp nhau.
- **Định nghĩa:** FTP (File Transfer Protocol) là giao thức truyền tệp theo mô hình client-server. Client đăng nhập để upload hoặc download; bên gửi và bên nhận tách rời nhau về thời gian (lưu rồi chuyển – store-and-forward).
- **Trong đề tài:** máy chấm công (giả lập) upload file lên FTP server, NiFi đến lấy về.
- **Lưu ý:** FTP **không mã hóa** dữ liệu, hướng cải thiện là SFTP/FTPS.
- **Ví dụ đời thường:** như tủ locker ở trung tâm thương mại — shipper bỏ hàng vào ngăn rồi đi, khách đến sau quét mã lấy.

---

# PHẦN D – BỐI CẢNH ỨNG DỤNG: NHÂN SỰ VÀ CHẤM CÔNG

## D.1. Ba nguồn và vai trò

| Nguồn | Trả lời câu hỏi |
|---|---|
| Database nhân sự (JDBC) | Nhân viên là ai, thuộc phòng nào, làm ca nào? |
| REST API ca làm việc | Ca đó bắt đầu/kết thúc lúc mấy giờ, có grace bao nhiêu phút? |
| FTP (máy chấm công) | Ai quẹt thẻ lúc mấy giờ? |

## D.2. Ba nguồn ghép lại thế nào

Đây là minh họa **mở rộng enrichment**, không phải điều kiện baseline. Baseline tập trung vào việc NiFi lấy và biến đổi từng nguồn.

```
FTP:  E0012, 2026-10-06 08:05:12      ← ai quẹt lúc nào
        │ tra employee_id
        ▼
DB:   E0012 → Tran Thi B, Kinh doanh, ca S1            ← người đó là ai, làm ca nào
        │ tra shift_id
        ▼
API:  S1 → 08:00–17:00, cho phép trễ 10 phút           ← ca đó giờ nào
        ▼
Kết quả: giờ vào 08:05 → trễ 0 phút → "Đúng giờ"
```

**Khóa liên kết (quan trọng):** chấm công có `employee_id` và (qua DB) `shift_id`; hồ sơ nhân viên có `shift_id`; API trả dữ liệu khớp `shift_id`. Nhờ các khóa này ba nguồn mới ghép được với nhau.

## D.3. Đầu ra chấm công hợp nhất (mở rộng)

| Trường | Ví dụ |
|---|---|
| employee_id | E0012 |
| full_name | Tran T*** B (đã che bớt) |
| department | Kinh doanh |
| work_date | 2026-10-06 |
| check_in / check_out | 08:05 / 17:12 |
| worked_hours | 9.12 (elapsed, chưa trừ nghỉ, không dùng tính lương) |
| late_minutes | 0 |
| status | Đúng giờ |

## D.4. Hai mức thực hiện

- **Baseline đề xuất:** mỗi nguồn có schema riêng (nhân viên, ca, lượt quẹt), dùng chung quy ước UTF-8, timestamp và envelope đầu ra. Không giả định dữ liệu ca/nhân viên tự có các trường chấm công. Vận hành NiFi là phần baseline.
- **Mở rộng:** attendance làm fact → lookup nhân viên từ DB → lookup ca từ API. `QueryRecord` chỉ tổng hợp trong từng FlowFile; nếu nhiều file/ngày phải thiết kế state/window trước. Quy tắc giờ/ca/thiếu lượt nằm trong SPECS.

---

# PHẦN E – KIẾN TRÚC HỆ THỐNG

## E.1. Sơ đồ tổng thể

```
[Máy chấm công]      [FTP Server]        [NiFi Server]                 [Đích cho quản lý]
  Client A  ─upload─▶ /checkin ─fetch─▶ Get → Transform → Put ──┬──▶ JSON theo dataset (baseline)
 (giả lập)                               ▲   ▲                  └──▶ report_db (mở rộng)
                                         │   │
 [DB Server: hr_db] ───────JDBC──────────┘   │
 [API Server: ca làm việc] ───────HTTP───────┘
```

Dòng lỗi (file hỏng, dòng dữ liệu sai) được tách sang thư mục `rejected/`.

## E.2. Bốn server và triển khai mạng

| Thành phần | Máy ảo | Phần mềm | Cổng | Vai trò |
|---|---|---|---|---|
| NiFi Server | VM1 | Ubuntu 24.04 + JDK 21 + NiFi 2.12.0 | 8443 (HTTPS) | Lấy, biến đổi, quản trị flow |
| Database Server | VM2 | Ubuntu + MySQL | 3306 | `hr_db` nguồn; `report_db` mở rộng |
| FTP Server | VM3 | Ubuntu + vsftpd | 21 + dải passive | Nhận file chấm công |
| API Server | VM4 | Ubuntu + Flask/Gunicorn + systemd | 5000 | Cung cấp nguồn ca làm giả |

- Nhóm chạy 4 VM trên 3 máy vật lý (Mac — Trường: NiFi; Windows A — Trung: DB + API, hai VM riêng; Windows B — Phước: FTP), VM bridged vào LAN riêng của nhóm là hotspot điện thoại; chi tiết ở [docs/DEPLOYMENT_ARCHITECTURE.md](docs/DEPLOYMENT_ARCHITECTURE.md).
- Các VM đặt chung một mạng (ví dụ `192.168.56.0/24`, IP `.10` đến `.13` — địa chỉ ví dụ, thay bằng IP thật khi dựng).
- Laptop nhóm: trình duyệt vào NiFi qua HTTPS `:8443`, và chạy script giả lập máy chấm công.
- **Nếu máy yếu:** gộp VM2 + VM3 + VM4 thành một VM, NiFi để riêng (tổng 2 VM).
- Mạng lab và IP trên là ví dụ: phải ghi inventory, NIC, route, IP máy quản trị/upload thật; firewall chỉ cho nguồn được phép theo ma trận SPECS. Không mở dịch vụ ra Internet.

## E.3. Bảng kết nối giữa các thành phần

| # | Từ → Đến | Giao thức · cổng | Công cụ NiFi | Nội dung |
|---|---|---|---|---|
| 1 | Máy chấm công → FTP | FTP · 21 (+passive) | – | Upload file .csv |
| 2 | NiFi → FTP | FTP · 21 (+passive) | ListFTP, FetchFTP | Lấy file chấm công |
| 3 | NiFi → DB | JDBC · 3306 | QueryDatabaseTableRecord / ExecuteSQLRecord | Snapshot nhân viên |
| 4 | NiFi → API | HTTP/REST · 5000 | InvokeHTTP | Lấy nguồn ca làm việc |
| 5 | Bên trong NiFi | – | Record processors, UpdateRecord, QueryRecord | Chuẩn hóa, che, validate |
| 6 | NiFi → đích | Ghi file / JDBC · 3306 | PutFile; PutDatabaseRecord mở rộng | Ghi kết quả |
| 7 | Người dùng → NiFi | HTTPS · 8443 | Giao diện web | Xây dựng, theo dõi luồng |

## E.4. Bên trong NiFi – các Process Group

```
PG-FTP   : ListFTP → FetchFTP → raw CSV → split/validate → normalize → PG-OUTPUT
PG-JDBC  : snapshot → QueryRecord/UpdateRecord (lọc active, mask, schema) → PG-OUTPUT
PG-REST  : request trigger → InvokeHTTP → response JSON → normalize → PG-OUTPUT
PG-OUTPUT: canonical/hash/envelope → PutFile theo dataset
PG-ERROR : phân loại → retry hữu hạn hoặc rejected/dead-letter có lý do
```

**Controller Services baseline:** DBCPConnectionPool, CSVReader, JsonTreeReader/JsonRecordSetWriter. DatabaseRecordLookupService/RestLookupService chỉ cần khi làm enrichment. Reader/writer dùng schema rõ; ghi properties/relationships/bundle thật và Parameter Context trong artifact NiFi.

## E.5. Phân quyền người dùng trên NiFi

| Vai trò | Quyền | Mục đích |
|---|---|---|
| admin (nhóm) | Toàn quyền | Cài đặt, xây luồng |
| operator | Xem, operate các PG được cấp | Không sửa flow/users/policies |
| manager | Chỉ xem canvas/status phạm vi được cấp | Không operate, sửa, tải raw content hoặc replay |

Baseline dùng HTTPS + ba X.509 client identities và managed authorizer/policies; không dựng thêm LDAP/OIDC. Single-user chỉ dùng bootstrap, không tự hỗ trợ ba user như bảng. Admin demo Provenance; kiểm tra policy content riêng để tránh lộ dữ liệu trước masking. Chi tiết TLS/trust/SAN và test âm trong SPECS.

Quản lý thực tế nhận kết quả ở thư mục/bảng đích, không cần vào NiFi. Tài khoản `manager` chỉ để demo phân quyền.

## E.6. Nguyên tắc thiết kế (nhớ kỹ)

- NiFi dùng tài khoản **chỉ đọc** với nguồn; FetchFTP completion None, không move/delete file nguồn trong baseline. Nếu archive nguồn về sau phải mô tả quyền và thời điểm riêng.
- Kết quả ghi vào **nơi riêng** (`report_db` hoặc thư mục báo cáo).
- Dữ liệu nhạy cảm (lương, số điện thoại, email) **bỏ hoặc che** trước khi giao.
- Dữ liệu lỗi tách riêng, không làm dừng cả luồng.
- Chỉ dùng **dữ liệu giả**, không dùng thông tin thật của ai.

---

# PHẦN F – THIẾT KẾ CHI TIẾT TỪNG NGUỒN

> Phần này là kế hoạch công việc; chưa có code trong repo lúc rà soát. Claude Code phải tạo SQL, fixtures, API, cấu hình và flow export theo SPECS, không phụ thuộc lịch sử chat ngoài repo.

## F.1. FTP server và máy chấm công (Use-case 3)

**Cách hoạt động:** máy chấm công (client A) upload file lên FTP server; file nằm chờ; NiFi (client B) đến lấy sau. Hai bên không cần chạy cùng lúc.

**Việc cần làm:**
1. Cài `vsftpd` trên Ubuntu, tắt đăng nhập ẩn danh, tạo tài khoản FTP cho lab.
2. Tạo inbox nhìn từ FTP consumer là `/checkin`, ghi mapping với OS/chroot. Tách uploader được upload/rename và consumer chỉ list/read; giữ file gốc để reprocess.
3. Mở cổng 21 và dải passive cố định 40000–40010 chỉ từ NiFi và máy uploader được chỉ định. **Thiếu dải passive thường làm đăng nhập được nhưng không tải được file.**
4. Viết script giả lập máy chấm công: tự tạo file CSV và upload lên FTP (hoặc upload tay bằng FileZilla khi demo).
5. **Mẹo tránh file ghi dở:** upload với đuôi `.tmp` rồi mới đổi tên sang `.csv`. NiFi chỉ lấy `.csv`.

**File chấm công (minh họa):** mỗi dòng là một lần quẹt — `employee_id, timestamp, device_id` (ví dụ `E0012, 2026-10-06 08:05:12, GATE-1`).

**Phía NiFi:**

| Processor | Cấu hình chính |
|---|---|
| ListFTP | Địa chỉ/tài khoản, `/checkin`, chỉ `.csv`, không recursive, Passive, Record Writer trống, persist state |
| FetchFTP | Remote file theo attributes path/filename thực tế, Completion Strategy None; không đổi nguồn |
| Record processors + UpdateRecord | Raw CSV schema chuỗi → validate/split → JSON normalized, timestamp có offset, event_id ổn định |

Fetch thành công chưa có nghĩa transform/output thành công; không gọi archive ngay sau fetch là `processed`. Listing state không thay idempotency đầu ra. File sai cú pháp có thể lỗi nguyên file; dòng đọc được nhưng sai schema/giá trị tách reject có lý do.

**Các loại file (làm CSV trước):** bắt buộc `.csv`; nếu còn thời gian thêm `.xlsx` (một chi nhánh gửi Excel) và `.zip` (nhiều file nén). Dùng `RouteOnAttribute` theo `filename` để tách loại.

## F.2. Database nhân sự (Use-case 1)

**Hai bảng trong `hr_db`:**
- `departments(department_id, department_name)`
- `employees(employee_id, full_name, dob, gender, department_id, position, email, phone, base_salary, shift_id, hire_date, status, updated_at)`
- `shift_id` là **cầu nối** sang API ca làm việc. `updated_at` giúp NiFi chỉ lấy dòng mới/vừa sửa.

**Việc cần làm:**
1. Cài MySQL, tạo `hr_db` với 2 bảng, seed xác định 50 nhân viên (45 active, 5 resigned), 5 phòng ban bằng **dữ liệu giả**; ca khớp API.
2. Tạo tài khoản **chỉ đọc** (`SELECT`) cho NiFi, đúng tinh thần "chỉ get".
3. MySQL bind IP lab; firewall 3306 chỉ từ IP NiFi, account giới hạn đúng host; không dùng root remote/user `%` mặc định. Test SELECT được và ghi bị từ chối.
4. `report_db` là mở rộng, user ghi riêng nếu làm. **Không ghi vào `hr_db`.**

**Phía NiFi:**
- `DBCPConnectionPool`: URL `jdbc:mysql://<ip>:3306/hr_db`, Driver `com.mysql.cj.jdbc.Driver`, trỏ tới file `mysql-connector-j-*.jar`, user chỉ đọc.
- Baseline: `QueryDatabaseTableRecord` đọc snapshot với maximum-value columns trống, hoặc `ExecuteSQLRecord` SELECT rõ cột/join phòng ban. Mỗi 60s hoặc Run Once để demo. Với 50 người chưa cần incremental.
- `updated_at` chỉ hỗ trợ incremental có giới hạn: phải kiểm tra trùng watermark, commit muộn và deletes trước khi tuyên bố đồng bộ. Không tự coi thêm `employee_id` là giải quyết mọi trường hợp.

**Transform trong NiFi:** lọc `status = 'active'`, che full_name/email, chuẩn hóa field/time. Không SELECT lương/phone/dob nếu không cần; đầu ra không có raw names/emails. Snapshot là lịch sử theo batch, không tự coi là bảng trạng thái HR hiện hành.

## F.3. REST API hệ thống ca làm việc (Use-case 2)

Nhóm **tự dựng API mini bằng Flask** (dữ liệu ca làm không có công khai).

**Endpoint:**
- `GET /api/shifts` – danh sách ca (nguồn chính)
- `GET /api/shifts/{id}` – một ca
- `GET /health` – trạng thái dịch vụ tối thiểu; ngày lễ là mở rộng
- `GET /api/slow` (chậm 10s) và `GET /api/error` (lỗi 500) – để test
- Có kiểm tra khóa truy cập qua header `X-API-Key`.

**Dữ liệu mẫu ca làm:** S1 Ca hành chính 08:00–17:00 (grace 10 phút), S2 Ca sáng 06:00–14:00 (grace 0), S3 Ca chiều 14:00–22:00 (grace 0). Endpoint `/api/shifts/{id}` hỗ trợ lookup mở rộng. Chạy Gunicorn/systemd, debug off.

**Phía NiFi:** request trigger → `InvokeHTTP` (GET, header khóa nhạy cảm) → body `Response` → record transform/validate → JSON ca. Phân biệt Original/Response, 4xx, 5xx, timeout; tối đa ba retry sau lần đầu, delay tối thiểu 5s.

**API ngoài:** chỉ thêm khi thầy yêu cầu. Baseline dùng nguồn và endpoint lỗi nội bộ để demo NiFi không phụ thuộc Internet; không mở rộng thành ứng dụng API phức tạp.

## F.4. Hợp nhất và giao kết quả (Use-case 4)

- **Baseline:** ba luồng chuẩn hóa riêng, dùng envelope JSON chung và schema record theo dataset, PutFile tới đường dẫn có hash nội dung ổn định.
- **Mở rộng:** attendance → lookup nhân viên (`employee_id`) → lookup ca (`shift_id`); `QueryRecord` tổng hợp trong một FlowFile hoàn chỉnh cho ngày. Các vấn đề nhiều file, ca qua đêm, lượt thiếu, grace, elapsed time phải theo quy tắc SPECS; không làm hệ thống tính lương.

**Đầu ra để quan sát NiFi:** `PutFile` bắt buộc; `PutDatabaseRecord` vào `report_db` là mở rộng có khóa unique/upsert nếu làm. Email, web/API giao kết quả không thuộc baseline.

## F.5. Monitoring, lỗi và bảo mật (Use-case 5)

- **Dữ liệu bẩn:** schema validation tách valid/invalid nếu reader đọc được; malformed CSV có thể quarantine nguyên file. Missing id/invalid date cần test rõ; unknown employee cần lookup nghiệp vụ khi làm mở rộng, duplicate xử lý bằng khóa ổn định.
- **Retry:** nối đúng relationship từng Processor; InvokeHTTP có retry bounded, còn QueryDatabaseTableRecord lỗi SQL log/yield rồi poll lại, không có failure FlowFile chung. Test lỗi nguồn, lỗi đích, reprocess và đối chiếu output.
- **Back pressure:** ngưỡng queue object/bytes rõ; thử downstream stop/resume, không dùng expiration để bỏ lỗi.
- **Provenance:** admin truy vết success/rejected và Replay kiểm tra không nhân đôi output.
- **Bảo mật:** HTTPS có trust/SAN, ba client identities + policies, kiểm tra quyền âm; bảo vệ secrets/content trước masking.
- **Backup:** export thiết kế cộng backup nhất quán config/keys/policies/state/repositories cần cho queue; restore thử trên instance cô lập. Kiểm tra service autostart/reboot, log/retention/disk NiFi. Không cam kết ngoài các ca đã thử.

## F.6. (Tùy chọn) Use-case 6 – REST API của chính NiFi

Dùng `/nifi-api` để theo dõi và điều khiển NiFi bằng script, xác minh endpoint/method theo API đúng phiên bản. Với baseline client certificates, dùng client identity và CA trust tương ứng; không tự thêm bước username/password lấy JWT. Chỉ mở rộng tự động hóa điều khiển sau khi xong baseline; API vẫn có thể dùng để cấu hình/kiểm chứng flow trong quá trình triển khai.

---

# PHẦN G – KẾ HOẠCH 6 TUẦN VÀ PHÂN CÔNG

> Đây là kế hoạch tương đối sáu tuần, chưa có deadline hay evidence để kết luận nhóm đã hoàn thành tuần nào. Cập nhật trạng thái thật trong docs/IMPLEMENTATION_STATUS.md; không suy ra tiến độ từ ngày tài liệu.

| Tuần | Nội dung | Sản phẩm |
|---|---|---|
| 1 | Chốt phạm vi, **hỏi thầy (Phần J)**, tìm hiểu NiFi và kiến thức nền, lập kế hoạch và thiết kế kiến trúc | Kế hoạch chốt, sơ đồ |
| 2 | Dựng profile đã chọn; NiFi HTTPS/JDK, nguồn MySQL/FTP/API, mạng/firewall/service users và autostart | NiFi và nguồn kết nối được; inventory/version manifest |
| 3 | Làm quen NiFi (flow thử) + Use-case 1 (JDBC) | Flow JDBC + test case |
| 4 | Use-case 2 (REST) và Use-case 3 (FTP) | Flow REST + FTP + test case |
| 5 | Đầu ra ba dataset; retry/idempotency, RBAC, Provenance, queue/back pressure, restart/restore NiFi | Flow baseline + bảng test/evidence; enrichment chỉ khi còn thời gian |
| 6 | Kiểm thử, hoàn thiện báo cáo, slide, demo (tùy chọn Use-case 6) | Báo cáo + slide + demo |

**Thứ tự ưu tiên:** NiFi chạy và kết nối được → ba use-case Get/Transform + PutFile → vận hành/bảo mật/khôi phục NiFi có evidence → mở rộng ghép dữ liệu/DB đích/Use-case 6. Không ưu tiên tính công hơn nội dung Apache NiFi của môn.

## Phân công

Nhóm 3 người, mỗi người phụ trách máy của mình (chốt 05/11/2026):

| Thành viên | Máy | Phụ trách chính |
|---|---|---|
| Trường | Mac — VM1 | NiFi: cài đặt, flow chung, bảo mật, phân quyền, vận hành; ghép báo cáo |
| Trung | Windows A — VM2, VM4 | MySQL, dữ liệu giả, API Flask; Use-case 1 (JDBC) và 2 (REST) |
| Phước | Windows B — VM3 | FTP, simulator chấm công; Use-case 3 (FTP) |

### Việc theo giai đoạn

**Bước 0 — cả nhóm, làm ngay**

- Hỏi thầy các câu ở Phần J, nhất là việc chạy 4 VM trên 3 máy.
- Chọn điện thoại làm hotspot, thử 3 laptop kết nối được với nhau.
- Trung và Phước gửi cấu hình máy (RAM, CPU, disk) để biết có chạy nổi VM không.
- Cả 3 clone repo GitHub chung để dùng chung script.

**Giai đoạn 1 — dựng server**

| Trường | Trung | Phước |
|---|---|---|
| VM1: cài NiFi 2.12.0 + JDK 21, mở được UI qua HTTPS | VM2: cài MySQL, tạo `hr_db` với 50 nhân viên giả, 5 phòng ban; user chỉ đọc cho NiFi. VM4: Flask API trả 3 ca làm việc, có API key | VM3: vsftpd, thư mục `/checkin`; script simulator upload CSV (file đúng, file lỗi, file trùng) |

Mốc chung: từ NiFi kết nối được cả 3 nguồn (TC-03).

**Giai đoạn 2 — làm flow NiFi**

Mỗi người làm flow cho nguồn của mình, để ai cũng giải thích được NiFi:

- Trường: khung flow chung, Parameter Context, phần ghi output và rejected, hướng dẫn hai bạn.
- Trung: PG-JDBC — đọc nhân viên, lọc active, che tên và email; PG-REST — đọc ca làm, retry khi API lỗi.
- Phước: PG-FTP — đọc CSV, tách dòng lỗi, chống trùng.

**Giai đoạn 3 — test và vận hành**

- Trường: phân quyền 3 vai trò, back pressure, Provenance/Replay, restart và backup/restore NiFi.
- Trung: tắt DB, sai mật khẩu, sửa dữ liệu nguồn; API lỗi 500/chậm/sai key — rồi xem NiFi xử lý.
- Phước: CSV lỗi, upload trùng, file đang upload dở, tắt FTP rồi bật lại.
- Mỗi người chụp ảnh, lưu log làm evidence cho phần test của mình.

**Giai đoạn 4 — báo cáo, slide, demo**

- Mỗi người viết phần server và flow của mình.
- Trường viết phần kiến trúc NiFi, bảo mật, vận hành và ghép bản cuối.
- Cả nhóm diễn tập demo ít nhất một lần trước buổi thật.

### Chi tiết từng người: dựng gì, làm gì, commit gì

Các thư mục dưới đây là nơi sẽ commit; hiện chưa tạo. Test case theo [SPECS mục 8](SPECS.md#8-nghiệm-thu-và-evidence).

#### Trường — NiFi (Mac, VM1)

**Dựng**

- VM1 Ubuntu Server 24.04 arm64 trên UTM.
- JDK 21 + NiFi 2.12.0, chạy bằng systemd, tự khởi động khi bật VM.
- NiFi HTTPS: CA của lab, certificate cho server, 3 client certificate admin / operator / manager.
- MySQL Connector/J (ghi rõ version và checksum).
- Thư mục output `/srv/nt132/output` và rejected `/srv/nt132/rejected`.

**Làm**

- Parameter Context và Controller Services dùng chung cho cả 3 flow.
- PG-OUTPUT (tạo envelope, hash, PutFile) và PG-ERROR (ghi rejected, dead-letter).
- Hướng dẫn và review PG-JDBC, PG-REST của Trung, PG-FTP của Phước.
- Phân quyền 3 vai trò; back pressure trên các queue; Provenance và Replay.
- Restart NiFi, backup và restore NiFi sang VM riêng.
- Export flow sau mỗi thay đổi lớn.
- Ghép báo cáo, slide, kịch bản demo.

**Test phụ trách:** TC-01, TC-02, TC-19 đến TC-26, TC-28 đến TC-30.

**Commit**

- `nifi/`: flow export từ NiFi thật, danh sách processor/bundle, file parameter mẫu (không có giá trị sensitive).
- `infra/nifi/`: script cài NiFi, systemd unit, script tạo certificate (không commit key/cert thật).
- `scripts/`: backup/restore NiFi, script đối chiếu output.
- `docs/`: báo cáo, slide, kịch bản demo.
- `evidence/`: ảnh và log của các test mình phụ trách.

#### Trung — MySQL + API (Windows A, VM2 và VM4)

**Dựng**

- VM2: Ubuntu Server 24.04 + MySQL 8.0, database `hr_db`.
- VM4: Ubuntu Server 24.04 + Python 3.12, Flask chạy bằng Gunicorn + systemd.

**Làm**

- Tạo bảng `departments`, `employees` theo SPECS 5.2.
- Script dữ liệu giả: 50 nhân viên, 5 phòng ban, 45 active, 5 resigned. Chạy lại không bị nhân đôi.
- User MySQL chỉ SELECT cho NiFi.
- API theo SPECS 5.3: `/health`, `/api/shifts`, `/api/shifts/{id}`, `/api/slow`, `/api/error`. Cần `X-API-Key`, sai key trả 401.
- PG-JDBC trong NiFi: đọc nhân viên, lọc active, che tên và email.
- PG-REST trong NiFi: đọc 3 ca làm, chuẩn hóa giờ, retry có giới hạn khi API lỗi.
- Gây lỗi để test: tắt DB, sai mật khẩu, sửa dữ liệu nguồn; API trả 500, chậm 10 giây, sai key.

**Test phụ trách:** TC-05 đến TC-13.

**Commit**

- `sql/`: schema, seed, lệnh cấp quyền (mật khẩu để placeholder), câu SELECT mà NiFi dùng.
- `api/`: code Flask, file dependency đã khóa version, `.env.example`, systemd unit.
- `tests/`: test hợp đồng API (đúng key, sai key, 404, 500).
- `evidence/`: ảnh và log của các test mình phụ trách.

#### Phước — FTP + simulator (Windows B, VM3)

**Dựng**

- VM3: Ubuntu Server 24.04 + vsftpd, thư mục `/checkin`, chế độ passive.
- 2 tài khoản FTP: `clock_uploader` (được upload) và `nifi_fetch` (chỉ đọc).
- Simulator chạy trên máy Windows của Phước.

**Làm**

- Script simulator: upload file `.tmp`, xong mới đổi tên thành `.csv`.
- Bộ CSV mẫu theo SPECS 5.4:
  - file chuẩn 10 dòng (7 đúng, 1 trùng, 2 lỗi);
  - file hỏng định dạng;
  - file chứa event trùng với file trước.
- PG-FTP trong NiFi: list và fetch file, tách dòng lỗi, tạo `event_id`, chống trùng.
- Gây lỗi để test: CSV lỗi, upload trùng, file đang upload dở, sai mật khẩu FTP, tắt FTP rồi bật lại.

**Test phụ trách:** TC-14 đến TC-18.

**Commit**

- `simulator/`: script upload và thư mục `simulator/fixtures/` chứa các file CSV mẫu.
- `infra/ftp/`: file `vsftpd.conf` mẫu, script tạo tài khoản (không ghi mật khẩu).
- `tests/`: kiểm tra số dòng và kết quả mong đợi của từng file CSV mẫu.
- `evidence/`: ảnh và log của các test mình phụ trách.

#### Cả nhóm cùng làm

- **TC-03:** từ NiFi kết nối được cả 3 nguồn.
- **TC-04:** mỗi người thử firewall cho VM của mình, gồm cả máy được phép và máy bị chặn.
- **TC-27:** mỗi người reboot VM của mình, dịch vụ phải tự chạy lại.
- Mỗi người viết phần báo cáo về server và flow của mình.

### Quy tắc commit chung

- `git pull` trước khi bắt đầu làm; commit nhỏ và thường xuyên, không dồn đến cuối.
- Mỗi người chủ yếu sửa trong thư mục của mình để tránh conflict.
- **Không commit:**
  - file máy ảo (`.utm`, `.vdi`, `.vmdk`, `.qcow2`);
  - mật khẩu, API key, private key, keystore/truststore NiFi;
  - dữ liệu NiFi đang chạy (repositories, state), file backup, thư mục output thật.
  - Các loại file này đưa vào `.gitignore` chung.
- Secrets chỉ commit file mẫu có placeholder (ví dụ `.env.example`); file thật để trong VM.
- Flow NiFi phải export từ NiFi đang chạy rồi mới commit. Không viết tay file flow JSON.
- Ảnh và log phải che mật khẩu, key trước khi commit vào `evidence/`.
- Trước buổi demo, commit bản cuối và ghi rõ commit đó dùng để demo.

---

# PHẦN H – BẢNG TEST CASE

**Bảng nghiệm thu thống nhất là TC-01..TC-30 tại [SPECS.md, mục 8](SPECS.md#8-nghiệm-thu-và-evidence).** Bảng dưới chỉ nhóm công việc, không tạo lại bộ ID cũ của v3.0.

| Nhóm test | Nội dung chứng minh |
|---|---|
| TC-01..TC-05 | Version/inventory, HTTPS NiFi, ba kết nối, firewall allow/deny, DB read-only |
| TC-06..TC-09 | JDBC snapshot, transform/masking trong NiFi, cập nhật nguồn, lỗi DB |
| TC-10..TC-13 | REST transform, API key, 500/timeout/offline, retry/reprocess |
| TC-14..TC-18 | FTP passive, file đang upload, CSV đúng/lỗi, quyền/path, listing và duplicate |
| TC-19..TC-23 | Schema/hash/output, lỗi đích, back pressure, Provenance, Replay |
| TC-24..TC-25 | Ba identity và kiểm tra quyền âm/content/TLS |
| TC-26..TC-30 | Restart/reboot/restore NiFi, retention, artifacts và demo tái lập |

Mỗi test có expected/actual, thời gian, môi trường/version và evidence thật. Hiện mọi test runtime là `NOT_RUN`; xem [trạng thái](docs/IMPLEMENTATION_STATUS.md). Không dùng mock/ảnh cấu hình làm bằng chứng test integration đã đạt.

---

# PHẦN I – RỦI RO VÀ CÁCH XỬ LÝ

| Rủi ro | Cách xử lý |
|---|---|
| Máy yếu, VM chậm | Gộp DB/FTP/API vào 1 VM, cấp NiFi ≥ 4 GB RAM |
| Sai phiên bản Java | NiFi 2.x cần Java 21, kiểm tra `java -version` trước khi cài |
| Không truy cập được NiFi | Kiểm tra bind/port, SAN/trust, thời hạn cert, client identity và policies; reset single-user credentials chỉ áp dụng giai đoạn bootstrap single-user |
| JDBC driver không nhận | Kiểm tra đường dẫn file driver và quyền đọc |
| FTP đăng nhập được nhưng không tải được file | Mở dải cổng passive + bật `pasv_enable=YES` |
| NiFi không kết nối được nguồn | Kiểm tra IP/route/DNS, bind, firewall theo nguồn/đích, credential; test cả dịch vụ chứ không chỉ ping |
| NiFi lấy phải file ghi dở | Upload đuôi `.tmp` rồi đổi tên sang `.csv` |
| Quá nhiều use-case, không kịp | Ưu tiên NiFi 3 connectors/transform, output và vận hành; hoãn enrichment/DB sink/web ngoài đề tài |
| Chưa có quyền/công cụ chạy cấu hình | Claude báo ngay trong chat, ghi MANUAL_ACTIONS, chuẩn bị script/bước verify và tiếp tục việc độc lập; không ghi PASS |
| Lẫn dữ liệu thật | Chỉ dùng dữ liệu giả do script tạo |

---

# PHẦN J – CÂU HỎI CẦN XÁC NHẬN VỚI THẦY (QUAN TRỌNG)

> Đây là những điểm nhóm đang **tự giả định**. Câu trả lời của thầy quyết định khối lượng công việc, nên hỏi sớm (ngay tuần 1). Hai câu quan trọng nhất là câu 3 và câu 4.

**1. "Dựng database và server" là dựng những server nào?**
Nhóm đề xuất 4 dịch vụ NiFi, MySQL, FTP, API trên 4 VM. Thầy có yêu cầu bốn VM độc lập không; nếu máy yếu có được gộp ba nguồn vào một VM để tập trung demo NiFi không?

**2. Ngoài JDBC, REST API, FTP, thầy còn dặn kiểu kết nối nào nữa?**
Ghi chú của thầy có dấu "..." sau ba kiểu này.

**3. (Quan trọng) "Chỉ get và transform" có cần ghi kết quả ra đâu không?**
Nhóm định ghi kết quả ra một thư mục hoặc bảng đích đơn giản để demo. Như vậy có bị coi là quá phạm vi không, hay thầy muốn dừng hẳn ở bước transform.

**4. (Quan trọng) REST API: tự dựng hay dùng API có sẵn?**
Nhóm định tự dựng API nguồn ca làm tối thiểu để demo InvokeHTTP/JSON transform và lỗi ngay trong lab. Thầy muốn tự dựng hay dùng API có sẵn? Nhóm ưu tiên không phụ thuộc Internet khi demo NiFi.

**5. FTP có cần bảo mật (SFTP/FTPS) không,** hay FTP thường là đủ.

**6. Có yêu cầu chạy NiFi dạng cụm (cluster/HA) không,** hay một node là đủ.
*(Nếu có: cần thiết kế lại topology, tài nguyên, cơ chế coordination và test theo đúng phiên bản; không mặc định chỉ thêm một số VM cố định là có HA.)*

**Câu hành chính:** rubric chấm Apache NiFi và các nội dung quản trị mạng là gì; hình thức nộp gồm những gì (báo cáo, slide, demo), số thành viên và hạn chót khi nào. Các câu hỏi này chưa có câu trả lời xác nhận trong repo.

---

# PHẦN K – CHECKLIST HOÀN THÀNH

**Hạ tầng:**

- [ ] Profile 4 VM hoặc 2 VM được ghi nhận; inventory/version manifest và preflight đủ
- [ ] NiFi 2.12.0/JDK21 chạy qua HTTPS với trust hợp lệ, service user và autostart
- [ ] Ba client identities admin/operator/manager, policies và test quyền âm đúng
- [ ] MySQL `hr_db` + seed giả, user SELECT giới hạn host, firewall đúng đường JDBC
- [ ] FTP inbox/chroot, uploader/consumer riêng, list/read passive đúng, file nguồn giữ lại
- [ ] API nguồn tối thiểu chạy WSGI/systemd, key/timeout/error; NiFi gọi được
- [ ] Firewall có test allow/deny, cấu hình không mở quá phạm vi kết nối NiFi

**Luồng NiFi:**

- [ ] PG-JDBC snapshot + filter/mask trong NiFi, Controller Services hợp lệ
- [ ] PG-REST Get/transform, status/timeout và bounded retry có evidence
- [ ] PG-FTP CSV Get/transform, raw/record errors tách đúng, listing state bền vững
- [ ] Ba dataset theo schema riêng/envelope chung, PutFile idempotent và kiểm đếm được
- [ ] Relationships, queue/back pressure, rejected/dead-letter, Provenance/Replay đúng
- [ ] Export flow/manifest/properties/parameters không chứa secrets, có hướng dẫn import
- [ ] Restart/reboot và backup/restore NiFi có test, đối chiếu queue/output/state

**Hoàn thiện:**

- [ ] Đã hỏi thầy đủ 6 câu ở Phần J và cập nhật plan
- [ ] TC-01..TC-30 có evidence thật; ghi đúng NOT_RUN/BLOCKED/FAIL/PASS
- [ ] Phần Claude chưa chạy được đã báo trong chat và MANUAL_ACTIONS có bước bàn giao/verify
- [ ] Báo cáo + slide + demo tập trung Apache NiFi, có hướng dẫn tái dựng
- [ ] Đã điền tên nhóm, thành viên, thầy vào các chỗ trống

**Mở rộng riêng, không chặn baseline:** enrichment chấm công, `report_db`, SFTP/FTPS, incremental và NiFi API automation nếu được yêu cầu hoặc còn thời gian.
