# Rà soát plan và đặc tả đồ án Apache NiFi – NT132

Ngày rà soát: **19/10/2026**. Tài liệu gốc: [NiFi_Project_Plan_Full.md](NiFi_Project_Plan_Full.md), phiên bản v3.0.

**Kết luận:** plan phù hợp hướng tích hợp dữ liệu nhưng chưa đầy đủ để giao triển khai và nghiệm thu. Cần sửa thiết kế flow, xác thực/phân quyền, chống trùng, khôi phục và bổ sung yêu cầu quản trị mạng. Tại thời điểm bắt đầu kiểm tra, thư mục chỉ có plan; chưa có specs riêng, mã nguồn, cấu hình triển khai, kết quả chạy hoặc rubric chính thức của giảng viên. Vì vậy **chưa thể kết luận hệ thống chạy đúng hoặc đạt yêu cầu môn học**.

**Apache NiFi là trung tâm đề tài.** Dữ liệu nhân sự/chấm công chỉ là dữ liệu giả để minh họa JDBC, REST và FTP cùng các phép biến đổi trong NiFi. Cấu hình mạng và dịch vụ phục vụ việc kết nối, bảo mật và vận hành NiFi; không mở rộng thành một đồ án hạ tầng chung hoặc hệ thống quản lý nhân sự hoàn chỉnh.

[SPECS.md](SPECS.md) là đặc tả triển khai được đề xuất từ đợt rà soát này. Plan trong repo đã cập nhật thành v3.1 để thống nhất với specs; bảng phát hiện dưới đây nói về bản v3.0 được đọc lúc bắt đầu. Các giải pháp là yêu cầu thiết kế và kiểm chứng tiếp theo, chưa phải bằng chứng đã cài đặt hoặc chạy flow/test.

## Baseline đề xuất

- Bốn VM **Ubuntu 24.04 LTS** cho NiFi, MySQL, vsftpd và API. Gộp dịch vụ chỉ là phương án giảm tài nguyên, phải ghi nhận topology thực tế và xác nhận với giảng viên.
- **NiFi 2.12.0 + JDK 21**. Trang download Apache được kiểm tra ngày 19/10/2026 ghi NiFi 2.12.0 phát hành ngày 13/09/2026; hướng dẫn Apache yêu cầu Java 21. Pin phiên bản và checksum trong manifest triển khai. Không suy rộng “Java 21 trở lên” thành hỗ trợ mọi JDK mới. Nguồn: [Apache Download](https://nifi.apache.org/download/), [Admin Guide](https://nifi.apache.org/nifi-docs/administration-guide.html).
- Ba nguồn JDBC, REST và FTP chuẩn hóa theo **từng dataset**: nhân viên, ca làm, lượt quẹt. Dùng envelope metadata chung; ngày lễ và chấm công tổng hợp là mở rộng.
- **PutFile bắt buộc** để có đầu ra kiểm chứng được; `report_db` và chấm công được enrichment là phần mở rộng. Chưa mặc định yêu cầu cluster, dashboard hoặc ứng dụng web riêng.
- Baseline NiFi gồm ba connector và transform, Controller Services, queue/back pressure, provenance, failure/retry, HTTPS/RBAC và khôi phục. Mạng, firewall và tài khoản dịch vụ chỉ bổ trợ trực tiếp cho các nội dung này; giám sát dùng UI/bulletin/log sẵn có của NiFi, không thêm stack giám sát hoặc LDAP ngoài phạm vi.
- Các nội dung vận hành trên là **baseline nội bộ bắt buộc** để đồ án thể hiện nội dung Quản trị mạng. Đây chưa phải rubric do giảng viên xác nhận; không xếp chúng sau phần ghép dữ liệu nâng cao khi thiếu thời gian.

## Phát hiện cần xử lý

P1: có thể khiến triển khai hoặc kết quả sai. P2: còn thiếu để vận hành, demo hoặc nghiệm thu tin cậy.

| Mức | Vị trí trong plan | Vấn đề | Hướng đặc tả và nghiệm thu trong SPECS.md |
|---|---|---|---|
| P1 | A, D.4, F.4, TC-13 | Vừa hứa một bảng chấm công thống nhất, vừa coi ghép dữ liệu là tùy chọn; schema ba nguồn khác nhau. | Chốt ba dataset chuẩn hóa là baseline; envelope chung chỉ chứa metadata. Bảng chấm công enriched có tiêu chí riêng khi thực hiện mở rộng. |
| P1 | E.4, F.4 | Ba queue đổ vào `LookupRecord` không tự join ba luồng. | Lượt quẹt làm luồng chính; lookup DB theo `employee_id`, rồi lookup REST theo `shift_id` bằng hai bước và dịch vụ tương ứng. Chốt mapping, schema kết quả, unmatched và lỗi dịch vụ. [LookupRecord](https://nifi.apache.org/components/org.apache.nifi.processors.standard.LookupRecord/). |
| P1 | D.4, F.4 | `QueryRecord` chỉ aggregate trong từng FlowFile. Lượt vào và ra ở hai file sẽ không tự gộp đúng. | Mở rộng phải chốt dữ liệu một ngày đầy đủ trong một FlowFile, hoặc có cơ chế lưu trạng thái/đóng kỳ rõ ràng. Test hai file cùng nhân viên/ngày và file đến muộn. [QueryRecord](https://nifi.apache.org/components/org.apache.nifi.processors.standard.QueryRecord/). |
| P1 | E.5, F.5, K | Single User mặc định không cung cấp ba tài khoản đăng nhập độc lập. Thêm tên user trong policy không tự tạo thông tin xác thực. | Baseline chọn client certificate riêng cho từng identity và managed authorizer; lập ma trận admin/operator/manager, thử quyền cho phép và bị từ chối. Không cần dựng thêm LDAP. [Authentication và Authorization](https://nifi.apache.org/nifi-docs/administration-guide.html). |
| P1 | F.2, TC-02/03 | `updated_at` watermark chỉ lấy giá trị lớn hơn mốc cũ. Timestamp bằng mốc, update lùi thời gian hoặc commit muộn có thể bị bỏ qua; không phản ánh DELETE. | Với khoảng 50 người, ưu tiên full snapshot định kỳ. Nếu demo incremental, ghi giới hạn, thiết kế đối soát/dedup và test bằng timestamp/late commit; không coi đây là CDC hoàn chỉnh. [QueryDatabaseTableRecord](https://nifi.apache.org/components/org.apache.nifi.processors.standard.QueryDatabaseTableRecord/). |
| P1 | F.5, TC-12 | `ValidateRecord` không tự phát hiện nhân viên lạ hoặc lượt quẹt trùng. `ConvertRecord` trước nó có thể lỗi ngay khi đọc file. | Phân biệt lỗi parse nguyên file, lỗi schema từng record và lỗi nghiệp vụ. `ValidateRecord` có thể tách valid/invalid khi reader đọc được; parse/read/write lỗi đi `failure` với FlowFile gốc. Test riêng từng loại, giữ file gốc để xử lý lại. [ValidateRecord](https://nifi.apache.org/components/org.apache.nifi.processors.standard.ValidateRecord/). |
| P1 | C.1, F.5, TC-10 | Repository/listing state chưa đủ để hứa “không mất dữ liệu”, “không trùng” từ nguồn tới đích. Replay/restart có thể lặp ghi. | Chốt khóa sự kiện, tên file đầu ra ổn định và chính sách khi file đích tồn tại; nếu ghi DB, có unique key/upsert. Test chạy lại, restart và lỗi trong lúc ghi đích. Đây là yêu cầu thiết kế, không phải cam kết exactly once sẵn có. |
| P2 | F.1, E.6 | `FetchFTP` move sau fetch, chưa chứng minh transform/output thành công; move cũng cần quyền ghi/rename trên nguồn. | Chọn `Completion Strategy=None` cho tài khoản nguồn chỉ đọc hoặc ghi rõ ngoại lệ archive. Nếu move, đặt tên mang nghĩa đã nhận; chỉ rõ Remote File, path theo FTP chroot và quyền. [FetchFTP](https://nifi.apache.org/components/org.apache.nifi.processors.standard.FetchFTP/). |
| P2 | F.1, TC-09/10 | Chưa mô tả listing state, tái sử dụng filename, archive bị quét lại và mapping List/Fetch. | `ListFTP` xuất từng FlowFile bằng attributes, không cấu hình Record Writer cho mẫu List→Fetch này; `Search Recursively=false`, filename duy nhất, `.tmp`→`.csv`, persist state. FetchFTP Remote File lấy từ path/filename thật, kiểm tra dấu phân cách. [ListFTP](https://nifi.apache.org/components/org.apache.nifi.processors.standard.ListFTP/), [FetchFTP](https://nifi.apache.org/components/org.apache.nifi.processors.standard.FetchFTP/). |
| P2 | F.5, TC-05/07/08 | Ghi mọi lỗi vào `retry/failure` chưa đúng từng processor. | `InvokeHTTP`: 401→`No Retry`, 5xx→`Retry`, lỗi socket→`Failure`, body 2xx→`Response`; thiết kế request FlowFile để retry được, số lần hữu hạn và khoảng chờ. QDTR nguồn chỉ có `success`; lỗi SQL theo dõi qua bulletin/log/yield. [InvokeHTTP](https://nifi.apache.org/components/org.apache.nifi.processors.standard.InvokeHTTP/), [QDTR](https://nifi.apache.org/components/org.apache.nifi.processors.standard.QueryDatabaseTableRecord/). |
| P2 | E.2/E.3, F.2, I, K | Chung subnet và ping chưa chứng minh dịch vụ đúng hoặc firewall giới hạn được truy cập. `0.0.0.0` chưa kèm giới hạn nguồn. | Có inventory IP/FQDN/NIC, mạng quản trị và lab, rule theo nguồn/đích, SSH, DNS/hosts, đồng bộ giờ, FTP passive. Test cả cổng được phép và truy cập bị chặn; chốt certificate SAN/trust khi vào NiFi bằng hostname/IP thực tế. |
| P2 | F.5, K | Export Process Group chưa đủ khôi phục dịch vụ hoặc queue. | Đặc tả backup cấu hình, state, key/certificate, users/policies, DB và FTP archive; repository khi cần bảo toàn queue. Có bước restore vào môi trường sạch và đối chiếu dữ liệu. [NiFi cấu hình, state và repositories](https://nifi.apache.org/nifi-docs/administration-guide.html). |
| P2 | G, H, K | Thiếu chủ sở hữu, deadline thực, bằng chứng và tiêu chí định lượng; trạng thái “đã qua tìm hiểu/thiết kế” chưa có bằng chứng. | Theo dõi việc/chủ sở hữu/trạng thái; mỗi test có lệnh, input, expected, actual và evidence. Không đánh dấu hoàn thành nếu mới có template hoặc chưa chạy trên VM. |

## Các quyết định dữ liệu thiếu ở bản v3.0, đã đặc tả trong SPECS

- Schema và mapping đầy đủ cho từng dataset: kiểu dữ liệu, nullable, trường bắt buộc, CSV delimiter/header/encoding, cấu trúc JSON API, schema version và lỗi có reason code.
- Khóa sự kiện và quy tắc trùng trong file, giữa nhiều file, sau restart/replay; cách phân biệt file mới với file cùng tên/nội dung khác.
- Timezone `Asia/Ho_Chi_Minh`, định dạng timestamp, quy tắc thời gian DB/API/FTP và đồng bộ đồng hồ.
- Nếu thực hiện chấm công nâng cao: ca qua đêm, một lượt quẹt, nhiều lượt quẹt, trừ giờ nghỉ, dữ liệu đến muộn và công thức trễ sau grace period. `MIN/MAX` không tự giải quyết các quy tắc nghiệp vụ này.
- Xác định manager được xem provenance tới đâu: quyền xem nội dung trước masking có thể làm lộ trường đã bỏ ở output. Toàn bộ dữ liệu lab vẫn phải là dữ liệu giả.

## Cần xác nhận trước khi tuyên bố hoàn thành

**Với giảng viên:** rubric/nội dung chấm điểm, số VM bắt buộc, ba giao thức đã đủ chưa, có yêu cầu FTP mã hóa/cluster không, phạm vi output và enrichment, API tự dựng hay công khai, hình thức nộp và deadline. Sáu câu ở Phần J của plan vẫn chưa có câu trả lời trong workspace.

**Với môi trường triển khai:** CPU/RAM/disk và kiến trúc máy, hypervisor, IP/FQDN/subnet/NIC, quyền tạo VM/sudo/firewall, SSH/credentials, kho tải phần mềm và nơi lưu bằng chứng. Chưa có các thông tin này nên chưa xác nhận khả năng chạy cấu hình trên các VM.

**Với Claude Code khi triển khai:** phần nào không truy cập hoặc chạy được phải báo cụ thể môi trường/lệnh bị thiếu hoặc bị từ chối, việc đã chuẩn bị, thao tác người dùng cần làm, lệnh xác nhận lại và ảnh hưởng tới nghiệm thu. Tạo script/template không được tính là đã áp dụng cấu hình; test chưa chạy ghi `NOT_RUN`/`PENDING_ENVIRONMENT`, hoặc `BLOCKED` khi có rào cản cụ thể đã quan sát.
