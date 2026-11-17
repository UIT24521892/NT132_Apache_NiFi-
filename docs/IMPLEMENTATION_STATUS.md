# Trạng thái triển khai và kiểm chứng

Cập nhật: 10/11/2026 (UTC+07:00).

**Kết luận hiện tại: đã có nguồn DB/API và artifact triển khai; chưa nghiệm thu qua NiFi.** Nhật ký 06/11 bên dưới ghi tiến độ VM2/VM4. Kết quả lịch sử chưa được kiểm chứng lại trong phiên Windows 07/11; thiếu inventory lab/NiFi và evidence tích hợp.

Chưa có bằng chứng lỗi sudo, VM, firewall hoặc API, vì vậy không ghi các hạng mục đó là BLOCKED. Mọi test nghiệm thu NiFi hiện là NOT_RUN; kiểm thử mã nguồn/HTTP loopback được ghi riêng bên dưới. Tình trạng thiếu đầu vào/môi trường được ghi PENDING_ENVIRONMENT.

Mục tiêu nghiệm thu là **NiFi lấy và biến đổi dữ liệu qua JDBC, REST và FTP**, với controller services, flow/error handling và vận hành NiFi được chứng minh. Các phần Linux/mạng chỉ phục vụ mục tiêu này; không tự thêm một đề tài hạ tầng riêng. Dữ liệu nhân sự là fixtures, còn enrichment/ghép nguồn là nâng cao khi phạm vi cho phép.

## Quy ước cập nhật

| Trạng thái | Ý nghĩa và điều kiện dùng |
|---|---|
| DONE_DOCUMENT_REVIEW | Đã thực hiện rà soát tài liệu; không chứng minh môi trường chạy được hoặc thầy đã duyệt phạm vi. |
| PENDING_ENVIRONMENT | Chưa đủ inventory, quyền, endpoint hoặc thông tin cần thiết để bắt đầu việc tương ứng; chưa có lỗi runtime được quan sát. |
| NOT_RUN | Chưa chạy bước/test; có thể đang chờ gate trước. |
| IN_PROGRESS | Đã bắt đầu thực hiện; ghi rõ bước đã chạy và phần còn lại. |
| PASS | Kiểm chứng thực tế đạt tiêu chí, có evidence và môi trường cụ thể. Chỉ dùng cho những phần đã kiểm chứng. |
| FAIL | Đã chạy kiểm chứng và kết quả không đạt expected; lưu log/actual và hướng sửa. |
| BLOCKED | Tác vụ không tiếp tục được do rào cản thực tế đã quan sát; ghi đủ mẫu báo trong MANUAL_ACTIONS. |

Không suy ra PASS của gate sau từ PASS của gate trước. Không coi cấu hình/script đã viết, package đã tải, service đang listen hoặc ảnh màn hình đơn lẻ là bằng chứng cho toàn bộ hệ thống.

## Các gate nghiệm thu

| Gate | Phạm vi và điều kiện kết thúc | Trạng thái hiện tại | Evidence hiện có / còn thiếu |
|---|---|---|---|
| G0 | Rà soát plan theo phạm vi Get/Transform và định hướng quản trị mạng; nhận diện giả định, mâu thuẫn và phần thiếu. | DONE_DOCUMENT_REVIEW | Đã đọc và rà soát plan. Phản hồi giảng viên/rubric và phê duyệt phạm vi chưa có; không coi là đã xác nhận. |
| G1 | Chốt inventory, topology, host/IP/NIC, tài nguyên, endpoint SSH, quyền quản trị; khóa phiên bản và nguồn cài phù hợp; preflight môi trường đích. | PENDING_ENVIRONMENT | Đã chọn topology 4 VM trên 3 máy vật lý, có thiết kế [DEPLOYMENT_ARCHITECTURE.md](DEPLOYMENT_ARCHITECTURE.md) và số liệu HOST-MAC (28/10/2026). Đã có thông tin HOST-WIN-A/VM2/VM4 trong nhật ký 06/11; còn thiếu HOST-WIN-B, inventory mạng/SSH lab, manifest thống nhất và preflight toàn bộ VM. |
| G2 | NiFi và ba dịch vụ nguồn chạy bằng user/quyền phù hợp trên Linux; IP/SSH, bind address và firewall cho kết nối NiFi; API có WSGI/service; startup và health checks. | IN_PROGRESS | Nhật ký 06/11 ghi MySQL/API chạy cục bộ, có source/config trong repo. NiFi/FTP, mạng/firewall, reboot và các đường kết nối từ NiFi chưa có evidence. |
| G3 | Ba flow NiFi JDBC, REST và FTP hoạt động với fixtures; controller services/record readers-writers cần thiết hợp lệ; chứng minh authentication, grants, passive transfer và lỗi kết nối theo specs. | NOT_RUN | Chưa có flow/controller services được xác minh hoặc input/output runtime của ba nguồn. |
| G4 | Transform/output của ba flow đúng data contract; relationships và queue lỗi được xử lý, retry có giới hạn/đường xử lý, kiểm đếm kết quả và kiểm thử idempotency/restart đúng phạm vi. Enrichment không mặc định bắt buộc. | NOT_RUN | Chưa có flow được kiểm chứng, output, quarantine/rejected hoặc evidence chạy lại/restart. Không tuyên bố “không mất dữ liệu”. |
| G5 | Vận hành NiFi: TLS/trust và ba identity/RBAC; provenance, bulletin/log, queue/back pressure và retention; backup–restore cấu hình/flow/state cần thiết có diễn tập; reboot rồi kiểm chứng NiFi, kết nối nguồn và dữ liệu theo kịch bản. | NOT_RUN | Chưa cấu hình/xác minh TLS, identities, policy, provenance/queue monitoring, backup, restore hay reboot. Export flow riêng lẻ không đáp ứng toàn bộ gate này. |
| G6 | Báo cáo, slide và demo gắn với evidence thật; ghi rõ phần chưa đạt; đóng gói bàn giao và đối chiếu rubric/format/deadline đã biết. | NOT_RUN | Chưa có báo cáo/slide/demo được nghiệm thu. Chưa có rubric hoặc phản hồi giảng viên được xác nhận trong môi trường này. |

Thứ tự phụ thuộc mặc định: G1 → G2 → G3 → G4 → hoàn tất G5 → G6. Thiết kế TLS/RBAC, users/permissions, giám sát và phục hồi bắt đầu ngay từ G1–G2; G5 là gate tổng hợp bằng chứng, không phải lý do hoãn bảo mật tới cuối. Khi các công việc độc lập đã đủ điều kiện, có thể làm song song và ghi trạng thái theo đúng thực tế.

## Trạng thái bộ test

- Bộ nghiệm thu baseline: **TC-01 đến TC-30**, định nghĩa tại [SPECS.md, mục 8](../SPECS.md#8-nghiệm-thu-và-evidence).
- Trạng thái hiện tại của toàn bộ dải: **NOT_RUN**; chưa có test runtime PASS/FAIL.
- Dùng bảng test trong specs làm nguồn thống nhất về mô tả/kỳ vọng; nếu thay đổi mapping, cập nhật specs và evidence cùng lúc.
- Khi thực hiện, ghi kết quả theo từng ID, không chỉ ghi “tất cả ổn”. Bước bị bỏ qua hoặc thiếu môi trường phải giữ NOT_RUN/PENDING_ENVIRONMENT và nêu lý do.

Mẫu kết quả thực thi cho từng test:

```text
Test ID / tên theo specs:
Spec version / commit (nếu có):
Timestamp / timezone:
Environment / host / phiên bản dịch vụ:
Prerequisites:
Command / thao tác đã thực hiện:
Expected:
Actual / exit code:
Evidence path: log, kết quả dữ liệu hoặc ảnh đã che secrets
Status: NOT_RUN | PENDING_ENVIRONMENT | PASS | FAIL | BLOCKED
Remaining action / limitation:
```

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

## Đầu vào cần bổ sung và bước tiếp theo

| Mục | Trạng thái | Việc tiếp theo |
|---|---|---|
| VM, NIC, CPU/RAM/disk và topology thực tế | PENDING_ENVIRONMENT | Topology đã chọn: 4 VM trên HOST-MAC + 2 máy Windows, LAN riêng, NIC bridged. Thu thập cấu hình 2 máy Windows và thiết bị mạng theo [MA-01](MANUAL_ACTIONS.md#ma-01--máy-ảo-và-card-mạng). |
| IP/hostname, SSH, host key và sudo | PENDING_ENVIRONMENT | Hoàn thiện inventory, chạy preflight theo [MA-02](MANUAL_ACTIONS.md#ma-02--ip-ssh-và-quyền-quản-trị-linux). |
| Nơi nạp secrets và identities lab | PENDING_ENVIRONMENT | Chuẩn bị cấu hình placeholder, cơ chế sinh/nạp secrets và quyền theo [MA-03](MANUAL_ACTIONS.md#ma-03--credentials-và-danh-tính-nội-bộ). |
| Trust CA/client certificate browser | NOT_RUN | Thực hiện sau khi endpoint TLS và phương án identity có thật; xem [MA-04](MANUAL_ACTIONS.md#ma-04--trust-ca-và-chứng-chỉ-client-trên-trình-duyệt). |
| Rubric, phản hồi phạm vi, hình thức nộp và deadline | PENDING_ENVIRONMENT | Người dùng cung cấp thông tin; ghi nguồn xác nhận theo [MA-05](MANUAL_ACTIONS.md#ma-05--rubric-phạm-vi-và-yêu-cầu-nộp-của-giảng-viên). |
| Evidence GUI/demo | NOT_RUN | Chuẩn bị script/kịch bản, thu evidence thật khi môi trường sẵn sàng theo [MA-06](MANUAL_ACTIONS.md#ma-06--evidence-gui-và-demo-trực-tiếp). |

Các artifact chưa được liệt kê là đã có trong đợt DB/API vẫn mang trạng thái PLANNED. Artifact đã viết không đồng nghĩa đã áp dụng lên VM. MA-05 dẫn các tài liệu giả định/câu hỏi đã có, chưa có phản hồi thầy. Claude tiếp tục chuẩn bị code, fixtures, cấu hình, provision/verify scripts và runbook trong repo khi chưa có runtime, đồng thời ghi rõ từng artifact mới tạo. Không dùng tiến độ tài liệu để thay thế kết quả kiểm thử thực tế.

## Kiểm tra tài liệu đã thực hiện

Đã đối chiếu chéo phạm vi/thiết kế NiFi và các file bàn giao. Kiểm tra tự động trên bộ tài liệu
xác nhận code fences cân bằng, liên kết nội bộ/anchors hợp lệ, JSON mẫu parse được, hai hash
golden đúng, TC-01..TC-30 không thiếu/trùng và CLAUDE.md import agent.md. Đây là kiểm tra
tài liệu, không phải kết quả PASS của bất kỳ test runtime nào.

## Nhật ký rào cản thực tế

**Điều kiện môi trường 07/11 (sau khi bật VM):** TCP 2222/2223 đã mở, user trung; SSH exit 255 do chưa có khóa cục bộ được cấp. Chưa xác minh sudo/dịch vụ và chưa có endpoint NiFi. Giữ PENDING_ENVIRONMENT, không suy đoán lỗi firewall/sudo.

Khi một bước thực sự không chạy được, phải báo ngay trong chat và thêm một mục gồm task/gate/test, nguyên nhân quan sát được, prerequisite thiếu, artifact hiện có hoặc PLANNED, thao tác người dùng tối thiểu, cách kiểm chứng lại, ảnh hưởng và trạng thái. Dùng mẫu đầy đủ tại [MANUAL_ACTIONS.md](MANUAL_ACTIONS.md#quy-tắc-báo-phần-chưa-thực-hiện-được), rồi tiếp tục các việc độc lập. Khi điều kiện đã được bổ sung, chạy lại bước kiểm chứng trước khi đổi trạng thái.

## Hoàn thiện artifact DB/API — 07/11/2026

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

## Truy cập VM sau khi bật — 07/11/2026

- Người dùng xác nhận hai VM đã bật, username đều trung.
- TCP 127.0.0.1:2222/2223 reachable=true.
- SSH BatchMode=yes, StrictHostKeyChecking=yes trả Permission denied (publickey,password), exit 255 ở cả hai VM.
- Profile Windows ADMIN chỉ có known_hosts/known_hosts.old; không có identity mặc định và không có SSH agent.
- Chuẩn bị khóa riêng cho lab ngoài repo và scripts/authorize_lab_ssh.ps1; người dùng nhập mật khẩu tại terminal cục bộ để cấp public key.
- Chưa copy/apply bản sửa lên VM, chưa xác minh hostname/sudo/MySQL/Gunicorn. G1 PENDING_ENVIRONMENT; TC không đổi.

## Kiểm chứng lại và chuẩn bị triển khai — 10/11/2026

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
