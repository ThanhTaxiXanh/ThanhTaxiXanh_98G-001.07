# Rà soát mã nguồn và bảo mật — 0.5.0

Kiểm tra ngày 30/10/2026 (UTC), repository `ThanhTaxiXanh/ThanhTaxiXanh_98G-001.07`,
nhánh `feature/initial-setup`, baseline `99e90d4dbbffaa75d888fb1134b48a5359ec97f5`.
Bằng chứng sau sửa là mã 0.5.0 trong commit chứa báo cáo này.

Phạm vi gồm các module app/core/map/calendar/payment/media/settings, Kotlin,
JavaScript, manifest, lưu trữ, API mạng, lockfile và Actions. Quét chữ ký bí mật
trong tệp theo dõi/lịch sử Git, đối chiếu phụ thuộc Pub/Maven runtime với OSV.
Không xem đây là kiểm toán firmware, hệ điều hành hoặc mã mọi thư viện bên ngoài.

## Phát hiện và xử lý

| ID | Phát hiện | Xử lý / bằng chứng |
| --- | --- | --- |
| E1 | AudioSession và Chromium cùng xin audio focus. Xung đột được xác nhận từ mã; quan hệ với lỗi Play trên Redmi là suy luận chưa có log thiết bị. | Bỏ request trùng; app chỉ nghe tháo tai nghe. [initializeAudioEvents](../lib/features/media/presentation/youtube_audio_handler.dart#L17). |
| E2 | Bộ lọc cũ tua media đến cuối và mute khi có trạng thái ad, có thể làm kẹt preroll. | Chỉ bấm Skip đang hiện, không tua/mute. [tick](../assets/scripts/youtube_filter.js#L23). Chromium HTML5 đã quan sát phát tiếp khi bật lọc. |
| E3 | MapWithContentTemplate cũ để host sắp pane, không thực hiện ba hàng 60/40. | Dashboard sở hữu vùng app được cấp. [onMeasure](../android/app/src/main/kotlin/vn/thanhtaxixanh/car98g00107/car/CarDashboardLayout.kt#L140): đo 480/320 trong vùng rộng 800px; ba hàng có tỷ lệ lưu được. |
| E4 | Kênh JS chỉ kiểm tra URL trang chính, iframe vẫn có thể gửi metadata giả. | Nonce riêng từng document, giới hạn 8KB, kiểm tra dữ liệu và không cài script trong iframe. [decode](../lib/features/media/data/youtube_bridge_codec.dart#L16). Chưa thấy đường thực thi lệnh tùy ý từ metadata. |
| E5 | Giới hạn API bản đồ được kiểm tra sau tải cả body; ngân hàng chưa giới hạn body. | [boundedGet](../lib/core/network/bounded_http.dart#L6) giới hạn lúc stream, deadline/abort và hủy stream. Mức 4MB cho bản đồ, 512KB cho ngân hàng; giới hạn số bản ghi và độ dài trường. |
| E6 | WebView/backup dựa nhiều vào mặc định Android. | Tắt file/content access, mixed content và HTTP; tắt backup, thêm quy tắc cloud/device transfer. [Manifest](../android/app/src/main/AndroidManifest.xml#L12). Kiểm tra kích thước ảnh trước đọc. Đây là hardening, không phải bằng chứng đã rò rỉ. |
| E7 | Runtime dùng Guava 31.1-android, khớp GHSA-5mg8-w23w-74h3 (LOW), GHSA-7g45-4rm6-3mm3 (MODERATE), GHSA-xxph-c9ww-hj94 (HIGH). | Constraint 33.7.2-android trong [Gradle](../android/app/build.gradle.kts); graph xác nhận bản mới, native tests qua. Chưa thấy luồng Java deserialization trong app; không kết luận đã bị khai thác. |
| E8 | Năm dependency không dùng. Mẫu mt_carplay có ALLOW_ALL_HOSTS_VALIDATOR nhưng không đăng ký trong manifest app. | Loại mt_carplay/flutter_map/latlong2/vietqr_widget/just_audio và tổng 20 gói thừa. Dịch vụ thật giữ [allowlist host](../android/app/src/main/kotlin/vn/thanhtaxixanh/car98g00107/car/TaxiCarService.kt#L15). Mẫu chưa đăng ký không phải endpoint đang lộ. |
| E9 | Actions dùng tag thay đổi được, checkout giữ credential không cần thiết. | Ghim SHA các action cấp trên, persist-credentials false; quyền vẫn contents:read. |

OSV cuối: **126 gói Pub + 115 tọa độ Maven runtime = 241 truy vấn, không còn
advisory khớp** tại thời điểm kiểm tra. Có thể tái chạy bằng
`tool/audit_dependencies.py` với báo cáo releaseRuntimeClasspath mới. Kết quả
không loại trừ lỗi chưa công bố. Quét mẫu token AWS/Google/GitHub và private-key
PEM cho kết quả 0 trong phạm vi nêu trên; không phát hiện được mọi bí mật tự đặt.

## Luồng thực thi đã đối chiếu

| Thành phần | Điểm vào / phụ thuộc | Trạng thái và I/O |
| --- | --- | --- |
| Phone YouTube | Screen → Session → WebView → JS | Host HTTPS cho phép; app-link YouTube đổi thành URL công khai, không theo intent fallback. |
| Âm thanh | JS xác thực → Session → AudioHandler → audio_service | Trạng thái thật cho notification/media browser; lệnh quay về cùng WebView. |
| Dashboard xe | CarBridge → CarRuntime → CarSurfaceMap → CarDashboardLayout | Lịch/QR/media cùng nguồn với phone; map và bố cục trong Surface host cấp. |
| Chuyển video | [showOnCar](../lib/features/media/presentation/youtube_session.dart#L400) → nhường view → prepare → native attach → xác nhận | Một WebView/một parent, timeout 8 giây, trả phone nếu không nhận xác nhận; có chế độ thu nhỏ. |
| Lưu trữ | SQLite whereArgs/transaction; SharedPreferences | Kiểm tra BIN/tài khoản/tiền/CRC; sửa thông tin ẩn QR cũ. Chưa thấy ghép dữ liệu người dùng vào SQL thực thi. |
| GPS/API | Người dùng bật GPS/tìm địa chỉ/xem tuyến/cập nhật ngân hàng | HTTPS, tọa độ hữu hạn, timeout/body cap; không tự bật GPS khi chỉ kết nối xe. |

[Chromium AudioFocusDelegate](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/content/public/android/java/src/org/chromium/content/browser/AudioFocusDelegate.java)
xin focus và suspend khi mất focus. audio_session 0.2.4 tạo request riêng nếu gọi
setActive; đó là căn cứ bỏ request trùng. Nguồn xác nhận cấu trúc, chưa xác nhận
mọi hành vi của WebView đang cài trên Redmi.

## Đối chiếu Master Prompt

| Yêu cầu | Trạng thái sau sửa |
| --- | --- |
| Trái map 60%, phải 40%, ba hàng | Có trong vùng app; không kiểm soát thanh hệ thống/vùng app khác của host. |
| Tỷ lệ hàng, tài khoản, sự kiện | Preset trên xe/tùy chỉnh phone; CRUD tài khoản/sự kiện trên phone, phản chiếu dữ liệu sang xe. |
| Video xe/thu nhỏ | Có mã chuyển/render WebView bằng external API của plugin, test parent handoff; GPU/decoder/tương tác bộ nhận thực chưa xác nhận. |
| Hết mọi quảng cáo | Chưa bảo đảm, chỉ xử lý selector/Skip đã biết. |
| Dẫn đường/biển báo | GPS, 3D, route preview, tag OSM gần vị trí; chưa voice turn-by-turn/rerouting, camera AI hoặc xác nhận giới hạn đúng đường/làn. |
| Offline toàn bộ bản đồ | Chưa tải gói bản đồ offline. Ngân hàng/dữ liệu cá nhân có offline. |
| Media local/radio, nhập ảnh QR bất kỳ | Chưa triển khai; hiện YouTube, sinh VietQR và chọn logo. |
| mt_carplay/Flutter template | Adapter native AndroidX cho Surface map/video; không tuyên bố gọi API AAPane/AATabBar của plugin đã loại. |

## Kiểm tra đã chạy và giới hạn

- Analyze sạch; **67 Flutter**, **12 JavaScript**, **7 Android** tests qua.
- Native tests đo 60/40 và ba hàng, chế độ thu nhỏ, chuyển parent, manifest/PiP,
  stale QR và giải mã bitmap QR bằng ZXing.
- `tool/browser_smoke.py`: Chromium **151.0.7922.34** phát HTML5 WebM thật từ
  fixture cục bộ với JS hiện tại. Play/pause/resume/seek/compact/lọc qua; không
  mute hoặc nhảy cuối. Đây không phải kiểm tra YouTube thật.
- Build release/kiểm tra APK được ghi ở Actions và mô tả PR của bản vá.

Chưa có Redmi/head unit/DHU đính kèm. Cần thử YouTube thật, MIUI, audio routing,
virtual display/decoder, ngắt-kết nối và hành vi host. Car App Library còn cần
nguồn cài tin cậy; build không có nghĩa Play chấp thuận. Bản thử dùng debug
signing; production keystore/update signing và xuất/nhập dữ liệu chưa cấu hình.
Hướng dẫn: [kiểm tra phone và màn hình khách](youtube-compatibility.md).
