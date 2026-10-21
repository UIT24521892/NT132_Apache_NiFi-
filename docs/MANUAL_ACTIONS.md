# Các điều kiện môi trường và thao tác cần phối hợp

Cập nhật: 19/10/2026 (Asia/Ho_Chi_Minh).

Tại thời điểm bắt đầu rà soát, dự án chỉ có kế hoạch, chưa có runtime được kiểm chứng, inventory SSH hoặc lần provision nào. Những mục dưới đây là **PENDING_ENVIRONMENT** hoặc **NOT_RUN**, chưa phải lỗi triển khai đã quan sát được. Chưa có căn cứ để báo lỗi sudo, hypervisor, firewall hay API.

Claude Code có thể tự động cấu hình VM, Linux, firewall, NiFi và chứng chỉ khi có CLI/API, kết nối, quyền và công cụ phù hợp. Chỉ chuyển cho người dùng phần thực sự cần thao tác thủ công sau khi kiểm tra năng lực môi trường. Không chạy lệnh Ubuntu/systemd trên máy macOS hiện tại để thay cho việc kiểm tra VM đích.

Apache NiFi là trung tâm đề tài: các điều kiện mạng, service, quyền và TLS dưới đây chỉ phục vụ cài đặt, kết nối và vận hành NiFi cùng ba nguồn JDBC/REST/FTP. Không mở rộng thành lab hardening hạ tầng, PKI doanh nghiệp hoặc hệ thống monitoring riêng. Dữ liệu nhân sự/chấm công chỉ là fixtures; ghép dữ liệu nâng cao không phải điều kiện để bắt đầu kiểm chứng ba flow Get/Transform.

Các artifact triển khai mang nhãn **PLANNED: chưa tạo hoặc chưa triển khai được xác minh** là yêu cầu Claude chuẩn bị trong các bước tiếp theo. Tài liệu đã có được ghi riêng ở MA-05; không dùng sự tồn tại của tài liệu để chứng minh cấu hình đã chạy. Sau khi tạo artifact, cập nhật đường dẫn thực tế và trạng thái.

## MA-01 — Máy ảo và card mạng

- **Trạng thái:** PENDING_ENVIRONMENT; liên quan G1–G2.
- **Prerequisite:** biết hypervisor hoặc nền tảng VM, kiến trúc CPU, RAM/disk khả dụng; được cấp quyền tạo máy và chọn 4 VM hay phương án gộp. Không tự coi số VM là yêu cầu đã được thầy chốt.
- **Artifact Claude cần chuẩn bị — PLANNED:** inventory mẫu, sơ đồ NIC/subnet/IP, phân bổ tài nguyên, cấu hình/script provision phù hợp nền tảng và hướng dẫn khởi tạo thủ công tương ứng.
- **Thao tác người dùng tối thiểu:** cung cấp nền tảng và giới hạn tài nguyên; chỉ tạo VM/NIC hoặc bật hỗ trợ virtualization bằng GUI nếu môi trường không cung cấp CLI/API đủ quyền. Nếu có CLI/API đã được cấp quyền, Claude tiếp tục tự làm trong phạm vi dự án.
- **Kiểm chứng:** inventory của hypervisor xác nhận VM/NIC; trên VM chạy `cat /etc/os-release`, `uname -m`, `ip -br address`, `ip route`, `free -h`, `df -h`. So sánh địa chỉ/interface/route với sơ đồ và kiểm tra TCP giữa đúng các host. Ping đơn lẻ không đủ để kết luận đạt.
- **Tác động:** chưa có VM/mạng phù hợp thì chưa thể xác minh provisioning và dịch vụ Linux; vẫn làm được code, cấu hình mẫu, fixtures và runbook.

## MA-02 — IP, SSH và quyền quản trị Linux

- **Trạng thái:** PENDING_ENVIRONMENT; liên quan G1–G2.
- **Prerequisite:** IP/hostname từng VM, cổng SSH, username, phương thức xác thực, host key fingerprint tin cậy, phạm vi sudo và đường console khôi phục khi thay đổi mạng.
- **Artifact Claude cần chuẩn bị — PLANNED:** inventory không chứa secrets, script preflight SSH/sudo, cấu hình mạng/firewall theo nguồn–đích, script provision/verify có thể chạy lại và phương án rollback.
- **Thao tác người dùng tối thiểu:** cung cấp endpoint và tài khoản quản trị qua cơ chế an toàn; cài SSH hoặc thêm public key bằng console khi SSH chưa có. Chỉ cấp những quyền thực sự cần; không gửi private key vào chat hoặc commit vào Git. Nếu sudo cần nhập mật khẩu tương tác mà công cụ không hỗ trợ, người dùng chạy chính xác bước đã chuẩn bị trong VM.
- **Kiểm chứng:** từ host quản trị chạy `ssh -o BatchMode=yes <user>@<vm> 'id; hostname'` khi dùng khóa đã thiết lập. Trên VM kiểm tra `sudo -l`; `sudo -n true` chỉ kiểm tra quyền sudo không tương tác, thất bại không tự chứng minh tài khoản không có sudo. Trước khi bật firewall phải có rule SSH đúng nguồn và console/rollback; sau đó mở phiên SSH thứ hai để kiểm tra.
- **Tác động:** thiếu endpoint/quyền thì chưa thể provision hoặc kiểm chứng runtime từ xa. Một lệnh thực sự bị từ chối phải được ghi lại với exit code và log đã che secrets; không suy đoán từ việc chưa được cấp inventory.

## MA-03 — Credentials và danh tính nội bộ

- **Trạng thái:** PENDING_ENVIRONMENT; liên quan G2–G5.
- **Prerequisite:** cơ chế lưu/truyền secrets được chấp nhận, người sở hữu tài khoản; baseline NiFi X.509 cho ba identity + managed authorizer; phạm vi tài khoản DB nguồn, FTP, API và quyền ghi thư mục PutFile. DB đích chỉ cần nếu làm mở rộng `report_db`.
- **Artifact Claude cần chuẩn bị — PLANNED:** mẫu cấu hình chỉ có placeholder, script sinh/nạp secrets cục bộ, cấu hình quyền file, SQL grants tối thiểu, cấu hình identity/policy NiFi và runbook cấp/đổi/thu hồi credentials.
- **Thao tác người dùng tối thiểu:** chọn hoặc cung cấp nơi nạp secrets; cung cấp tài khoản có sẵn nếu phải tích hợp hệ thống ngoài lab. Với tài khoản lab mới và quyền đã cấp, Claude có thể tự sinh credentials mạnh và cấu hình; người dùng không cần nhập thủ công từng tài khoản.
- **Kiểm chứng:** NiFi kết nối được bằng tài khoản được cấp; DB nguồn đọc được và bị từ chối ghi; service user ghi đúng thư mục PutFile; API key đúng được chấp nhận/key sai bị từ chối; FTP đúng phạm vi thư mục; role NiFi bị từ chối đúng thao tác ngoài quyền. Chỉ kiểm tra account DB sink nếu thực hiện mở rộng. Các lệnh/ảnh/log kiểm chứng phải che token, mật khẩu và private key.
- **Tác động:** thiếu secret của hệ thống có sẵn làm các integration tương ứng chưa chạy được; vẫn chuẩn bị được phần mềm, cấu hình placeholder và test. Không dùng single-user mặc định rồi tuyên bố đã đạt RBAC ba người dùng.

## MA-04 — Trust CA và chứng chỉ client trên trình duyệt

- **Trạng thái:** NOT_RUN; liên quan G5, phụ thuộc endpoint TLS và identities thực tế.
- **Prerequisite:** CA của lab, certificate có SAN khớp hostname/IP thực tế, thời hạn hợp lệ; X.509 client identity/certificate riêng cho từng role và kênh bàn giao khóa an toàn theo baseline SPECS.
- **Artifact Claude cần chuẩn bị — PLANNED:** script tạo/kiểm chứng TLS theo phiên bản cho NiFi, bundle CA công khai của lab, gói client certificate ba role, bảng ánh xạ identity–policy NiFi và hướng dẫn import theo OS/browser. Chỉ cần phương án tin cậy tối thiểu của lab, không tự dựng PKI doanh nghiệp. Private key phải có quyền file hạn chế và không được lưu trong Git.
- **Thao tác người dùng tối thiểu:** import CA và client certificate vào đúng profile khi browser/OS yêu cầu UI hoặc xác nhận cục bộ mà công cụ không thao tác được. Nếu công cụ quản trị certificate được cấp quyền và hỗ trợ đầy đủ, Claude có thể tự làm. Không thêm LDAP/OIDC ngoài baseline khi chưa có yêu cầu thay đổi.
- **Kiểm chứng:** `openssl s_client -connect <host>:8443 -servername <hostname> -CAfile <ca.pem> -verify_return_error -verify_hostname <hostname>` cho certificate dùng DNS; nếu endpoint dùng IP thì kiểm tra SAN IP và dùng `-verify_ip <ip>` khi công cụ hỗ trợ. Bổ sung client certificate/key theo runbook mTLS. Trình duyệt không có cảnh báo TLS; từng identity đăng nhập và kiểm tra quyền thành công. Không dùng bỏ kiểm tra certificate để kết luận đạt.
- **Tác động:** thiếu trust/import ở browser có thể chỉ chặn demo browser; kiểm thử TLS/API bằng trust store riêng vẫn tiếp tục nếu công cụ hỗ trợ. Thiếu authentication backend chặn kiểm thử identities tương ứng.

## MA-05 — Rubric, phạm vi và yêu cầu nộp của giảng viên

- **Trạng thái:** PENDING_ENVIRONMENT theo nghĩa đang chờ thông tin đầu vào; liên quan quyết định phạm vi G0–G6, không phải lỗi runtime.
- **Prerequisite:** rubric/đề bài gốc hoặc phản hồi của giảng viên về số server, giao thức, đầu ra, tự dựng API, bảo mật FTP, cluster, hình thức nộp và deadline.
- **Artifact đã có:** giả định/baseline trong SPECS mục 1–2 và câu hỏi cho thầy ở plan Phần J. **PLANNED:** ghi nhận câu trả lời thật, mapping rubric chính thức với thiết kế/test/evidence sau khi được cung cấp; chưa có xác nhận của thầy.
- **Thao tác người dùng tối thiểu:** cung cấp đề bài/rubric hoặc phản hồi đã nhận. Claude không tự liên hệ giảng viên hay gửi tin nhắn nếu chưa được chỉ thị rõ.
- **Kiểm chứng:** mỗi quyết định ghi nguồn xác nhận, ngày, nội dung và tác động tới plan/specs; yêu cầu chưa xác nhận được gắn nhãn giả định/baseline đề xuất, không biến thành lời thầy.
- **Tác động:** tiếp tục baseline khả thi đã ghi giả định; không tự thêm cluster, LDAP hoặc dịch vụ ngoài phạm vi chỉ vì chưa có phản hồi. Chưa thể tuyên bố đáp ứng đầy đủ rubric chính thức.

## MA-06 — Evidence GUI và demo trực tiếp

- **Trạng thái:** NOT_RUN; liên quan G3–G6.
- **Prerequisite:** các dịch vụ/flow cần chứng minh đã chạy; có browser/session phù hợp hoặc công cụ browser được cấp quyền và dữ liệu giả để demo.
- **Artifact Claude cần chuẩn bị — PLANNED:** kịch bản demo ba flow NiFi và controller services, provenance của một FlowFile, queue/back pressure, retry và đầu ra; danh sách ảnh theo test, hướng dẫn thao tác cho ba role, mẫu evidence manifest, lệnh thu log/metrics và bước che secrets trước khi chia sẻ.
- **Thao tác người dùng tối thiểu:** chỉ chụp/quay/thao tác GUI những bước Claude không truy cập được bằng công cụ hiện có; không phải tự làm lại phần đã chứng minh được qua CLI/API. Đăng nhập hoặc chọn chứng chỉ bằng UI nếu session cần người dùng thao tác.
- **Kiểm chứng:** evidence có test ID, thời điểm, môi trường, expected/actual và đối chiếu log/API khi có; ảnh flow phải cho thấy trạng thái thực tế phù hợp kịch bản. Ảnh cấu hình không chứng minh rằng test đã chạy; không dùng ảnh minh họa hoặc dữ liệu giả lập kết quả làm evidence runtime.
- **Tác động:** nếu chỉ thiếu GUI thì giữ riêng phần GUI/demo là NOT_RUN, đồng thời báo các kiểm thử CLI/API đã thực sự thực hiện. Không đánh dấu toàn bộ gate hoàn tất khi evidence bắt buộc còn thiếu.

## Quy tắc báo phần chưa thực hiện được

Ngay khi phát hiện một tác vụ cần thiết không thực hiện được trong môi trường thực tế, Claude phải **báo rõ trong chat**, cập nhật tài liệu trạng thái và tiếp tục các việc độc lập. Nếu mới thiếu thông tin/môi trường chưa thử chạy, dùng PENDING_ENVIRONMENT/NOT_RUN. Chỉ dùng BLOCKED khi có rào cản thực tế đã quan sát và nêu được bằng chứng; không bịa lỗi sudo, VM, network hoặc API.

Mỗi lần báo dùng đủ các trường sau:

```text
Task / gate / test ID:
Observed cause: chưa thử vì thiếu ... HOẶC lệnh đã chạy + lỗi/exit code thực tế
Prerequisite còn thiếu:
Artifact: đường dẫn đã tạo, hoặc PLANNED — chưa tạo; nêu trạng thái đúng thực tế
Manual steps tối thiểu: người dùng làm gì, ở host/VM/browser nào
Verify: lệnh hoặc thao tác + kết quả mong đợi sau khi bổ sung prerequisite
Effect: bước nào chưa chạy; việc độc lập nào vẫn tiếp tục
Status: PENDING_ENVIRONMENT | NOT_RUN | BLOCKED | RESOLVED
Evidence: thời điểm, môi trường và log/ảnh đã che secrets; ghi chưa có nếu chưa chạy
```

Không yêu cầu người dùng làm thủ công một việc chỉ vì chưa kiểm tra công cụ/quyền hiện có. Không tuyên bố đã triển khai, PASS hoặc hoàn thành phục hồi khi mới viết cấu hình/runbook. Sau khi người dùng bổ sung điều kiện hoặc hoàn tất bước thủ công, Claude phải chạy lại kiểm chứng thích hợp trước khi cập nhật kết quả.
