# Hướng dẫn thử bản 0.5.0

Thiết bị: Redmi Note 12 Pro, Android 13, Android Auto 18.1.164344, màn hình riêng
dành cho khách nhận chiếu từ điện thoại. Chưa biết model bộ nhận. Môi trường phát
triển không kết nối thiết bị này.

## Điện thoại

1. Tìm video công khai, bấm Play. Nếu nút website không phản hồi, thử nút Play
   trên thanh công cụ ứng dụng. Thông báo media phải phản ánh phát thực tế.
2. Thử tắt/bật khiên lọc quảng cáo và video có preroll. Bộ lọc mới chỉ ẩn phần đã
   biết/bấm Skip; không tua video hoặc mute. Không cam kết hết mọi quảng cáo.
3. Thử nút PiP và Home với tự PiP bật. Muốn chỉ nghe nền: tắt tự PiP, giữ phát
   nền bật, thử Home và khóa máy. Thử điều khiển thông báo, tai nghe và cuộc gọi.
4. Nếu lỗi, ghi nguyên thông báo/mã media. Không gửi cookie/mật khẩu. Khả năng
   phát nền còn phụ thuộc YouTube, Android System WebView và quản lý pin MIUI.

## Android Auto: chọn đúng mục

- **ThanhTaxiXanh • Nhạc** là danh mục âm thanh/video gần đây. Bố cục do Android
  Auto sắp xếp, không hiển thị dashboard hay video.
- **ThanhTaxiXanh • Bản đồ** có dashboard 60/40 và nút YouTube. Tỷ lệ tính trong
  vùng app, không gồm thanh hệ thống hay vùng dành cho ứng dụng khác.

Trong mục Bản đồ:

1. Home hiển thị map trái 60%, ba hàng phải 40%: Lịch/sự kiện, QR, Media.
   Kiểm tra Dương/Âm, Can Chi, đếm ngày và QR. Sửa tiền/tài khoản trên phone phải
   ẩn QR cũ ngay trong lúc đang chỉnh.
2. Settings chọn QR lớn/cân đối/ưu tiên sự kiện. Phone **Cài đặt → Tùy chỉnh tỷ
   lệ hàng** cho nhập tổng 100%, mỗi hàng 15–70%. CRUD ngân hàng/sự kiện ở phone,
   kiểm tra dữ liệu tự cập nhật trên xe.
3. Bấm YouTube để chuyển chính WebView sang màn hình khách. Phone vẫn có ô tìm
   kiếm để chọn video. Bấm lại YouTube để thu nhỏ/phóng to trong vùng ứng dụng;
   Settings mở được video gần đây. Home trở về dashboard.
4. Trong video, thanh công cụ có trước/Play-Pause/sau. Nếu host yêu cầu, bật pan
   để tương tác với bề mặt. Nút **Chuyển về điện thoại** đưa view về phone.
5. Thử ngắt/kết nối, đổi video, toàn vùng/thu nhỏ. Nếu không xác nhận được view
   trong 8 giây, ứng dụng trả về phone và báo lỗi.

## Mức xác minh

Dashboard native đã được đo đúng 60/40 trong vùng host chừa lề; test đã kiểm tra
ba hàng, chuyển parent, thu nhỏ và QR. Video xe dùng external API WebView plugin
và Surface của app. Những test đó chưa xác nhận GPU, giải mã video, bàn phím,
tương tác hay chính sách của bộ nhận thực. Chế độ màn hình khách còn thử nghiệm,
chưa có chứng nhận Play/Android Auto. Cửa sổ thu nhỏ này nằm trong ứng dụng;
Android PiP hệ thống là tính năng riêng của điện thoại.

67 Flutter/12 JS/7 Android tests và Chromium HTML5 fixture đã qua; YouTube thật
trên Redmi/bộ nhận vẫn cần thử. [Báo cáo đầy đủ](source-security-review.md) nêu rõ
lỗi đã sửa, phạm vi bảo mật và phần Master Prompt còn chưa hoàn chỉnh.

## Nguồn cài và dữ liệu

Theo [hướng dẫn Google](https://developer.android.com/training/cars/testing),
Unknown sources trong developer settings Android Auto hỗ trợ thử ứng dụng media.
Car App Library cần nguồn tin cậy như Play Internal App Sharing/Internal Testing.
APK GitHub không tự bảo đảm mục Bản đồ xuất hiện.

APK thử dùng khóa debug tạm. Khác khóa ký ngăn cập nhật đè; gỡ bản cũ xóa tài
khoản nhận tiền, sự kiện và cài đặt cục bộ. Bản 0.5.0 tắt sao lưu/di chuyển tự động
của Android; chưa có xuất/nhập dữ liệu ứng dụng.
