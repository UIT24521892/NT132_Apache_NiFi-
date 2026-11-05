# NT132 — Apache NiFi: thu thập và biến đổi dữ liệu từ JDBC, REST API và FTP

Đồ án môn **Quản trị mạng và hệ thống (NT132)** — Nhóm 13.

Dự án dùng **Apache NiFi** làm trung tâm để **lấy (Get)** dữ liệu từ ba nguồn với ba kiểu kết nối
khác nhau, **biến đổi (Transform)** thành các dataset JSON chuẩn hóa, đồng thời chứng minh năng lực
cài đặt, kết nối, bảo vệ và vận hành NiFi. Dữ liệu nhân sự/chấm công chỉ là **dữ liệu giả** để
minh họa; sản phẩm chính là các flow NiFi, không phải ứng dụng quản lý nhân sự.

## Trạng thái hiện tại

> **Giai đoạn tài liệu.** Repo hiện chỉ có kế hoạch, đặc tả và tài liệu trạng thái. Chưa có mã
> nguồn, cấu hình triển khai, flow NiFi export hay kết quả kiểm thử runtime.

| Gate | Nội dung | Trạng thái |
|---|---|---|
| G0 | Rà soát plan, phạm vi và giả định | DONE_DOCUMENT_REVIEW |
| G1 | Inventory, topology, version manifest, preflight | PENDING_ENVIRONMENT |
| G2 | Dựng NiFi và ba dịch vụ nguồn, mạng/firewall, autostart | NOT_RUN |
| G3 | Ba flow PG-JDBC, PG-REST, PG-FTP chạy trong NiFi thật | NOT_RUN |
| G4 | Transform/output đúng hợp đồng, rejected, retry, idempotency | NOT_RUN |
| G5 | TLS/RBAC, Provenance, back pressure, restart, backup/restore | NOT_RUN |
| G6 | Báo cáo, slide, demo gắn với evidence thật | NOT_RUN |

Toàn bộ bộ nghiệm thu **TC-01..TC-30** đang ở trạng thái `NOT_RUN`. Chi tiết và evidence cập nhật
tại [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md).

## Ba nguồn dữ liệu

| Nguồn | Hệ thống giả lập | Kết nối | Processor NiFi chính | Dataset đầu ra |
|---|---|---|---|---|
| MySQL `hr_db` | Phần mềm nhân sự | JDBC | QueryDatabaseTableRecord / ExecuteSQLRecord | `employees` |
| Flask API | Hệ thống ca làm việc | REST (HTTP) | InvokeHTTP | `shifts` |
| vsftpd `/checkin` | Máy chấm công xuất CSV | FTP (passive) | ListFTP → FetchFTP | `attendance_events` |

## Kiến trúc

```text
MySQL hr_db --JDBC--> PG-JDBC --normalize/mask---+--> PG-OUTPUT --> PutFile
Flask shifts --HTTP--> PG-REST --normalize------+       |
vsftpd inbox --FTP--> PG-FTP --CSV/validate-----+       +--> rejected/
                           |
                    bounded retry / queues / provenance

Browser admin/operator/manager --HTTPS + client identity--> NiFi UI
```

- **Process Groups:** `PG-JDBC`, `PG-REST`, `PG-FTP`, `PG-OUTPUT`, `PG-ERROR`.
- **Controller Services tối thiểu:** DBCPConnectionPool, CSVReader, JsonTreeReader,
  JsonRecordSetWriter.
- Ba flow baseline xuất **ba dataset riêng** theo một envelope JSON chung, có `batch_id` là
  SHA-256 của nội dung canonical để chống trùng ở đầu ra.
- Toàn bộ transform và xử lý lỗi nằm trong NiFi; các dịch vụ nguồn chỉ trả dữ liệu thô.
- Bảo mật NiFi: HTTPS và ba X.509 client identity (admin / operator / manager) với managed
  authorizer và policy riêng.

## Môi trường baseline

| Thành phần | Phiên bản dự kiến |
|---|---|
| OS các VM | Ubuntu Server 24.04 LTS |
| NiFi | Apache NiFi Standard 2.12.0 |
| JVM | OpenJDK 21 |
| Database | MySQL 8.0 + MySQL Connector/J (chốt exact version trước khi cài) |
| API | Python 3.12 + Flask + Gunicorn, chạy bằng systemd |
| FTP | vsftpd từ repository Ubuntu |

Nhóm chọn profile 4 VM (NiFi, DB, FTP, API) chạy trên 3 máy vật lý (1 Mac, 2 Windows) nối bằng LAN
riêng là hotspot điện thoại; xem [docs/DEPLOYMENT_ARCHITECTURE.md](docs/DEPLOYMENT_ARCHITECTURE.md). Profile dự phòng gộp
DB/FTP/API vào một VM. Địa chỉ IP trong tài liệu chỉ là ví dụ, sẽ thay bằng inventory thật khi dựng môi trường.

## Tài liệu trong repo

| File | Nội dung |
|---|---|
| [SPECS.md](SPECS.md) | Đặc tả kỹ thuật: kiến trúc, hợp đồng dữ liệu, thiết kế flow/lỗi, bảo mật, khôi phục và bảng nghiệm thu TC-01..TC-30 |
| [NiFi_Project_Plan_Full.md](NiFi_Project_Plan_Full.md) | Kế hoạch tổng thể: kiến thức nền, kiến trúc, thiết kế từng nguồn, lộ trình 6 tuần, câu hỏi cần xác nhận với giảng viên |
| [REVIEW.md](REVIEW.md) | Rà soát kỹ thuật bản plan v3.0 và các phát hiện đã đưa vào SPECS |
| [docs/DEPLOYMENT_ARCHITECTURE.md](docs/DEPLOYMENT_ARCHITECTURE.md) | Kiến trúc triển khai: 4 VM trên 3 máy vật lý, mạng, ma trận cổng/firewall, bảo mật, backup |
| [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md) | Trạng thái thật của từng gate và bộ test |
| [docs/MANUAL_ACTIONS.md](docs/MANUAL_ACTIONS.md) | Các điều kiện môi trường và thao tác cần phối hợp (MA-01..MA-06) |
| [agent.md](agent.md), [CLAUDE.md](CLAUDE.md) | Quy tắc làm việc cho Claude Code trong dự án |

Thứ tự ưu tiên khi có mâu thuẫn: yêu cầu/rubric của giảng viên → `SPECS.md` → plan.

## Cấu trúc thư mục dự kiến

Các thư mục dưới đây **chưa tồn tại**; sẽ được tạo khi có nội dung thật.

| Thư mục | Nội dung dự kiến |
|---|---|
| `infra/` | Inventory mẫu, template provision/cấu hình, systemd, firewall theo máy |
| `sql/` | Schema và seed dữ liệu giả, grants cho tài khoản nguồn chỉ đọc |
| `api/` | Flask API nguồn ca làm việc, dependency lock |
| `simulator/` | CSV fixtures và script upload `.tmp` rồi rename `.csv` |
| `schemas/` | Schema raw/normalized/envelope và fixture đầu ra mong đợi |
| `nifi/` | Flow export từ NiFi thật, manifest processor/bundle, parameters mẫu |
| `scripts/` | Preflight, kiểm thử kết nối, đối chiếu kết quả, backup/restore |
| `tests/` | Kiểm thử hợp đồng API, transform và nghiệm thu |
| `evidence/` | Log/kết quả kiểm thử đã che secrets |

## Nguyên tắc

- Chỉ dùng dữ liệu giả; không đưa thông tin cá nhân thật vào repo.
- Không commit mật khẩu, API key, private key hay certificate riêng tư.
- Một test chỉ được ghi `PASS` khi đã chạy trên môi trường thật và có evidence; kiểm tra cú pháp
  hoặc mock không thay cho kiểm thử tích hợp.
- Không tuyên bố exactly-once, HA hay "không mất dữ liệu" vượt ngoài kịch bản đã kiểm chứng.
