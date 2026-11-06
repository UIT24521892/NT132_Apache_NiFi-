# sql/ — nguồn MySQL `hr_db` cho PG-JDBC (VM2 db.lab)

Phụ trách: Trung. Hợp đồng: [SPECS 5.2](../SPECS.md#52-mysql-và-dataset-employees). Toàn bộ là dữ liệu giả.

| File | Tác dụng | Chạy trên VM2 |
|---|---|---|
| `01_schema.sql` | Tạo `hr_db`, bảng `departments`, `employees` (utf8mb4, `updated_at` DATETIME(6) tự cập nhật) | `sudo mysql < 01_schema.sql` |
| `02_seed.sql` | 50 nhân viên, 5 phòng ban, 45 active / 5 resigned, ca S1/S2/S3 = 17/17/16, 2 email NULL/rỗng. `INSERT IGNORE`: chạy lại không nhân đôi, không ghi đè dữ liệu đã sửa | `sudo mysql < 02_seed.sql` |
| `03_grants.sql.template` | User `db_reader`@`<IP_VM1>` chỉ SELECT theo cột cần thiết (TC-05). Thay placeholder trên VM, **không commit bản có mật khẩu** | `sudo mysql < 03_grants.sql` |
| `10_nifi_select_employees.sql` | Câu SELECT cho `ExecuteSQLRecord` (không lọc status; NiFi lọc và mask) | dán vào NiFi |
| `90_reset.sql` | Xóa dữ liệu để seed lại — chỉ chạy khi cố ý reset | `sudo mysql < 90_reset.sql && sudo mysql < 02_seed.sql` |
| `99_verify.sql` | Đếm/kiểm tra seed | `sudo mysql --default-character-set=utf8mb4 -t < 99_verify.sql` |
| `tools/gen_seed.py` | Sinh lại `02_seed.sql` (seed cố định 13213) | `python3 tools/gen_seed.py > 02_seed.sql` |

Cấu hình mysqld đi kèm: [`infra/db/zz-nt132.cnf`](../infra/db/zz-nt132.cnf) → `/etc/mysql/mysql.conf.d/`
(`default-time-zone='+00:00'` để `updated_at` lưu UTC; `bind-address` bật khi có IP lab).

Lưu ý cho PG-JDBC: vì quyền theo cột, `SELECT *` bị từ chối. Dùng `ExecuteSQLRecord` với câu SELECT
liệt kê cột ở trên (hoặc `QueryDatabaseTableRecord` có đặt *Columns to Return*).
DBCPConnectionPool: `jdbc:mysql://db.lab:3306/hr_db`, user `db_reader`, mật khẩu là sensitive parameter.
