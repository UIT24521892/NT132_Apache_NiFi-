# Trạng thái triển khai và kiểm chứng

Cập nhật: 19/10/2026 (Asia/Ho_Chi_Minh).

**Kết luận hiện tại: đã rà soát tài liệu; chưa triển khai hoặc kiểm chứng runtime.** Điểm xuất phát là file `NiFi_Project_Plan_Full.md`. Chưa có inventory SSH, chưa provision VM/dịch vụ và chưa chạy integration tests. Việc tạo thêm tài liệu trong đợt rà soát không thay đổi trạng thái runtime.

Chưa có bằng chứng lỗi sudo, VM, firewall hoặc API, vì vậy không ghi các hạng mục đó là BLOCKED. Mọi test runtime hiện là NOT_RUN. Tình trạng thiếu đầu vào/môi trường được ghi PENDING_ENVIRONMENT.

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
| G1 | Chốt inventory, topology, host/IP/NIC, tài nguyên, endpoint SSH, quyền quản trị; khóa phiên bản và nguồn cài phù hợp; preflight môi trường đích. | PENDING_ENVIRONMENT | Chưa có inventory SSH, version lock hoặc kết quả preflight VM. Chưa chạy bất kỳ provisioning nào. |
| G2 | NiFi và ba dịch vụ nguồn chạy bằng user/quyền phù hợp trên Linux; IP/SSH, bind address và firewall cho kết nối NiFi; API có WSGI/service; startup và health checks. | NOT_RUN | Chưa provision Linux, NiFi, MySQL, FTP hay API. Chưa có log service/network/firewall hoặc kiểm thử allow/deny cho các đường kết nối của NiFi. |
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

## Đầu vào cần bổ sung và bước tiếp theo

| Mục | Trạng thái | Việc tiếp theo |
|---|---|---|
| VM, NIC, CPU/RAM/disk và topology thực tế | PENDING_ENVIRONMENT | Thu thập thông tin và chọn phương án 4 VM hoặc gộp theo [MA-01](MANUAL_ACTIONS.md#ma-01--máy-ảo-và-card-mạng). |
| IP/hostname, SSH, host key và sudo | PENDING_ENVIRONMENT | Hoàn thiện inventory, chạy preflight theo [MA-02](MANUAL_ACTIONS.md#ma-02--ip-ssh-và-quyền-quản-trị-linux). |
| Nơi nạp secrets và identities lab | PENDING_ENVIRONMENT | Chuẩn bị cấu hình placeholder, cơ chế sinh/nạp secrets và quyền theo [MA-03](MANUAL_ACTIONS.md#ma-03--credentials-và-danh-tính-nội-bộ). |
| Trust CA/client certificate browser | NOT_RUN | Thực hiện sau khi endpoint TLS và phương án identity có thật; xem [MA-04](MANUAL_ACTIONS.md#ma-04--trust-ca-và-chứng-chỉ-client-trên-trình-duyệt). |
| Rubric, phản hồi phạm vi, hình thức nộp và deadline | PENDING_ENVIRONMENT | Người dùng cung cấp thông tin; ghi nguồn xác nhận theo [MA-05](MANUAL_ACTIONS.md#ma-05--rubric-phạm-vi-và-yêu-cầu-nộp-của-giảng-viên). |
| Evidence GUI/demo | NOT_RUN | Chuẩn bị script/kịch bản, thu evidence thật khi môi trường sẵn sàng theo [MA-06](MANUAL_ACTIONS.md#ma-06--evidence-gui-và-demo-trực-tiếp). |

Các artifact triển khai được yêu cầu trong MANUAL_ACTIONS hiện mang trạng thái PLANNED; chưa xác minh tồn tại hoặc đã chạy. MA-05 dẫn các tài liệu giả định/câu hỏi đã có, chưa có phản hồi thầy. Claude tiếp tục chuẩn bị code, fixtures, cấu hình, provision/verify scripts và runbook trong repo khi chưa có runtime, đồng thời ghi rõ từng artifact mới tạo. Không dùng tiến độ tài liệu để thay thế kết quả kiểm thử thực tế.

## Kiểm tra tài liệu đã thực hiện

Đã đối chiếu chéo phạm vi/thiết kế NiFi và các file bàn giao. Kiểm tra tự động trên bộ tài liệu
xác nhận code fences cân bằng, liên kết nội bộ/anchors hợp lệ, JSON mẫu parse được, hai hash
golden đúng, TC-01..TC-30 không thiếu/trùng và CLAUDE.md import agent.md. Đây là kiểm tra
tài liệu, không phải kết quả PASS của bất kỳ test runtime nào.

## Nhật ký rào cản thực tế

**Chưa có rào cản runtime được quan sát.** Không có mục BLOCKED được xác nhận tại thời điểm cập nhật.

Khi một bước thực sự không chạy được, phải báo ngay trong chat và thêm một mục gồm task/gate/test, nguyên nhân quan sát được, prerequisite thiếu, artifact hiện có hoặc PLANNED, thao tác người dùng tối thiểu, cách kiểm chứng lại, ảnh hưởng và trạng thái. Dùng mẫu đầy đủ tại [MANUAL_ACTIONS.md](MANUAL_ACTIONS.md#quy-tắc-báo-phần-chưa-thực-hiện-được), rồi tiếp tục các việc độc lập. Khi điều kiện đã được bổ sung, chạy lại bước kiểm chứng trước khi đổi trạng thái.
