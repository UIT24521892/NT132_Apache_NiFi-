# Quy tắc cho Claude Code — đồ án Apache NiFi, NT132

## 1. Mục tiêu và phạm vi

Hoàn thiện đồ án **Apache NiFi: thu thập và biến đổi dữ liệu từ JDBC, REST API và FTP**.
Môn học là Quản trị mạng; thể hiện năng lực cài đặt, kết nối, bảo vệ và vận hành NiFi.
Dữ liệu nhân sự/chấm công chỉ dùng để minh họa, toàn bộ là dữ liệu giả.

- NiFi phải thực hiện Get, Transform, định tuyến, quản lý queue và truy vết.
- Flask chỉ cung cấp nguồn JSON; SQL cung cấp nguồn quan hệ; vsftpd cung cấp file.
- Không chuyển ETL chính sang Python/API/SQL rồi dùng NiFi chỉ gọi script.
- Không xây website, dashboard riêng, ứng dụng HR, tính lương, Kubernetes, cluster,
  LDAP/OIDC hoặc bộ monitoring ngoài khi chưa có yêu cầu. Dùng UI/REST API NiFi sẵn có.
- Ưu tiên ba connector, transform có thể giải thích, Controller Services, retry,
  back pressure, Provenance, HTTPS/RBAC và khôi phục NiFi.
- Ghép ba nguồn thành bảng chấm công, `report_db`, FTPS/SFTP và tính giờ là mở rộng.

## 2. Tài liệu phải đọc và thứ tự giải quyết mâu thuẫn

Đọc `SPECS.md` trước khi code; đọc `REVIEW.md` để tránh lặp lại lỗi thiết kế.
Plan mô tả tiến độ; specs quy định hành vi và tiêu chí kỹ thuật.
`docs/IMPLEMENTATION_STATUS.md` ghi thực trạng; `docs/MANUAL_ACTIONS.md` ghi bàn giao.

Yêu cầu trực tiếp mới nhất của người dùng và rubric thầy được cung cấp có ưu tiên.
Sau đó áp dụng specs, rồi plan. Không tự nhận các đề xuất là yêu cầu đã được thầy duyệt.
Nếu rubric mới mâu thuẫn specs, cập nhật quyết định và tài liệu liên quan trước khi làm tiếp.
Không dựa vào “code đã có trong lịch sử chat”; mọi thứ để dựng lại phải nằm trong repo.

## 3. Bắt đầu bằng kiểm tra môi trường

1. Đọc file hiện có; không ghi đè công việc người dùng. Kiểm tra Git nếu repo đã có Git.
2. Kiểm tra OS/CPU, công cụ VM/container sẵn có, Java/Python và tài nguyên cần thiết.
3. Xác minh inventory, IP thật, đường SSH, tài khoản quản trị, quyền sudo và NiFi endpoint.
4. Kiểm tra có thể dùng CLI/SSH/NiFi REST API hay không; không mặc định mọi thao tác GUI
   đều bất khả thi. Không cài systemd/apt trực tiếp trên máy macOS.
5. Ghi trạng thái G1 và cấu hình thiếu; tiếp tục viết các artifact độc lập trong repo.

Không yêu cầu người dùng gửi mật khẩu/private key vào chat. Dùng secret cục bộ có quyền hạn chế.
Chỉ thao tác đúng các máy lab được chỉ định; việc tạo tài liệu không đồng nghĩa đã được cấp
quyền thay đổi firewall, tài khoản hoặc dịch vụ trên máy cá nhân/mạng trường.
Khi đã có ủy quyền và đủ công cụ thì tự thực hiện, không đẩy việc tự động được cho người dùng.

## 4. Thứ tự thực hiện

1. G1: chốt profile, inventory, version manifest và các giả định còn chờ xác nhận.
2. G2: dựng các dịch vụ phục vụ NiFi; kiểm tra kết nối, quyền truy cập và autostart.
3. G3: xây và kiểm tra lần lượt PG-JDBC, PG-REST, PG-FTP trong NiFi thật.
4. G4: chuẩn hóa, đầu ra PutFile, rejected, retry hữu hạn và idempotency theo specs.
5. G5: kiểm tra NiFi TLS/RBAC, queues, back pressure, Provenance, restart và restore.
6. G6: hoàn thiện hướng dẫn tái dựng, báo cáo, slide và kịch bản demo Apache NiFi.
7. Chỉ làm mở rộng sau khi các phần baseline đã đạt hoặc người dùng đổi ưu tiên.

Ở mỗi bước: tạo cấu hình/script → kiểm tra cục bộ → triển khai khi có môi trường →
kiểm tra thực tế → lưu evidence → cập nhật trạng thái. Không dừng ở việc đề xuất kế hoạch.

## 5. Artifact cần bàn giao khi triển khai

Tạo các thư mục dưới đây khi thực sự có nội dung; đây chưa phải các artifact đã tồn tại:

| Vị trí | Nội dung cần có |
|---|---|
| `infra/` | inventory mẫu, provision/config templates, systemd, firewall theo máy |
| `sql/` | schema/seed giả, source grants, truy vấn; phần sink tách riêng nếu làm |
| `api/` | Flask nguồn dữ liệu, health/test endpoints, dependency lock |
| `simulator/` | CSV fixtures và upload `.tmp` rồi rename `.csv` |
| `schemas/` | schema raw, normalized và envelope, fixture đầu ra mong đợi |
| `nifi/` | flow export từ NiFi thật, manifest processor/bundle, parameters mẫu |
| `scripts/` | preflight, kiểm thử kết nối/đối chiếu kết quả, backup/restore |
| `tests/` | kiểm thử có ý nghĩa cho hợp đồng API, transform và nghiệm thu |
| `docs/` | triển khai, vận hành, mapping flow, báo cáo và nội dung slide |
| `evidence/` | kết quả test/log đã che secrets; ảnh thật khi có công cụ/người chụp |

README phải dẫn tới lệnh thật đang tồn tại. Không bịa lệnh `make`/script hay screenshot.
Script provisioning chạy lại an toàn; việc reset dữ liệu/state phải có lệnh riêng, phạm vi rõ.
Không tải JDBC driver bằng wildcard không biết phiên bản; ghi URL, checksum và version thật.

## 6. Quy tắc kỹ thuật NiFi

- Baseline NiFi 2.12.0, JDK 21. Kiểm tra tài liệu đúng bản và version manifest trước cài.
- Xác minh component/bundle/property/relationship bằng NiFi đang chạy hoặc tài liệu đúng bản.
  Không phát minh property, relationship `failure` chung, UUID, flow JSON hay kết quả import.
- Có thể chuẩn bị flow skeleton trước; phải ghi UNVERIFIED cho tới khi import, validate và chạy.
- Dùng Parameter Context cho host/path/config; sensitive parameter/property cho secrets.
- Tách Controller Services đọc nguồn và ghi đích; nguồn MySQL chỉ SELECT, FTP consumer chỉ đọc.
- Source JDBC baseline đọc snapshot nhỏ; không tuyên bố `updated_at` là CDC đầy đủ.
- Luồng REST có request FlowFile để retry; chỉ body response thành công đi vào transform.
- FTP `FetchFTP` dùng completion không sửa nguồn; state listing phải tồn tại qua restart.
- Listing state không thay thế dedup đầu ra. Không đánh dấu “processed thành công” ngay sau fetch.
  Backup/restore phải giữ cả output/rejected cùng state/queue; output cũng là ledger chống trùng.
- Phân biệt lỗi cú pháp toàn file, lỗi schema từng record, lỗi nghiệp vụ và duplicate.
  `ValidateRecord` có thể tách valid/invalid nếu đọc được record, không tự kiểm tra mọi quy tắc.
- Tất cả relationship có đích/auto-terminate có lý do; không âm thầm hủy lỗi hoặc loop vô hạn.
- Mọi queue có back pressure và chính sách lưu rõ; không dùng expiration để làm biến mất lỗi.
- `LookupRecord` cần lookup service; `QueryRecord` chỉ gộp trong FlowFile hiện tại.
- NiFi single-user chỉ dùng bootstrap; demo 3 vai trò phải có identity và policies riêng.
- Manager không được xem raw content/replay; Provenance cũng có thể tiết lộ dữ liệu trước masking.
- Python hỗ trợ tạo fixture và kiểm chứng; không thay NiFi thực hiện pipeline cốt lõi.

## 7. Bắt buộc thông báo khi không chạy/cấu hình được

**Thông báo ngay trong chat khi phát hiện bước cần thiết chưa thể thực hiện**, đồng thời cập nhật
`docs/MANUAL_ACTIONS.md` và gate/test liên quan. Không chỉ để cảnh báo trong file.

Mỗi thông báo phải có:

1. Tác vụ và máy/thành phần NiFi liên quan.
2. Nguyên nhân quan sát được hoặc thông tin cụ thể còn thiếu; không bịa lỗi đã chạy.
3. Prerequisite cần có: endpoint, CLI, quyền, SSH, secret được cấp cục bộ hoặc thao tác GUI.
4. File/script đã chuẩn bị, và phần nào vẫn mới là dự kiến.
5. Các bước/lệnh người dùng cần làm, thực hiện trên máy nào, quyền nào và giá trị cần thay.
6. Lệnh/tiêu chí xác minh sau thao tác và ảnh/log cần thu.
7. Ảnh hưởng: gate/test nào chưa đạt, việc độc lập nào vẫn làm tiếp được.

Phân biệt `PENDING_ENVIRONMENT` (chưa được cung cấp môi trường), `BLOCKED` (đã có trở ngại
cụ thể), `NOT_RUN` (chưa chạy), `FAIL` (đã chạy và sai), `PASS` (đã chạy và có evidence).
Không gọi cấu hình firewall/NiFi/VM là “không thể” nếu chưa kiểm tra công cụ và quyền sẵn có.
Không đánh PASS bằng kiểm tra cú pháp hoặc test mock cho một yêu cầu tích hợp thực tế.
Sau khi prerequisite được đáp ứng, tự kiểm chứng lại rồi mới đóng mục bàn giao.

## 8. Kiểm thử, evidence và hoàn thành

Chạy test trong SPECS, gồm cả truy cập bị từ chối, lỗi nguồn/đích, restart/replay và restore.
Mỗi test lưu ID, môi trường/version, thời gian có timezone, bước/lệnh, expected, actual,
exit code/log/ảnh phù hợp và đường dẫn evidence. Không ghi secret/token trong log hoặc ảnh.

Không tuyên bố exactly-once, HA hay “không mất dữ liệu” vượt kịch bản đã kiểm chứng.
Không tạo log/ảnh giả, không cập nhật checkbox hoàn thành chỉ vì đã viết cấu hình.
Các thao tác GUI chưa có công cụ phải có kịch bản chụp ảnh bàn giao, trạng thái NOT_RUN.

Chỉ kết luận baseline hoàn thành khi có môi trường tái dựng được, flow NiFi import/running
và đủ evidence acceptance. Nếu thiếu, báo rõ phần đã làm và phần chờ; không che bằng “đã xong”.
Chưa có rubric chính thức thì không cam kết điểm số hoặc kết luận đã đạt mọi yêu cầu môn.

## 9. Cách phản hồi

Trao đổi và viết báo cáo bằng tiếng Việt; giữ tên component/property theo NiFi.
Khi kết thúc mỗi đợt: nêu thay đổi, test thực chạy, kết quả, hạn chế và manual actions còn mở.
Giải thích được mỗi Processor làm gì và vì sao cần nó trong demo Apache NiFi.
Hướng dẫn này được nạp qua `CLAUDE.md`; nếu chưa rõ ngữ cảnh, đọc lại specs và trạng thái.

