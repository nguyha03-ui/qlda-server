# qlda-server

Máy chủ trạng thái license và cập nhật cho **QLDA Work Manager**, chạy trên GitHub Pages.

- Địa chỉ: https://nguyha03-ui.github.io/qlda-server/
- version.json: thông tin phiên bản mới nhất.
- license-status.json: trạng thái các license (chỉ chứa mã băm).

**Kho này công khai. Không đưa tên khách hàng, số điện thoại, mã khách hàng gốc hay license key gốc vào bất kỳ file nào.**

## 1. Cấu trúc license-status.json

| Trường | Giá trị | Ý nghĩa |
|---|---|---|
| plan | trial / term / perpetual | Dùng thử / có thời hạn / vĩnh viễn |
| expires | YYYY-MM-DD hoặc null | Ngày hết hạn (null với vĩnh viễn) |
| status | active / unpaid / blocked | Hoạt động / chưa thanh toán / bị khóa |

Khóa của mỗi license là mã băm SHA-256 của chuỗi mãKH:LICENSEKEY (key viết hoa, bỏ khoảng trắng). Ứng dụng tự băm từ mã và key khách nhập, rồi tra trong file.

## 2. Quy trình cập nhật (làm trên máy admin)

Cần Python 3 và Git. Chạy lệnh trong thư mục kho:

| Việc cần làm | Lệnh |
|---|---|
| Cấp license 1 năm | python tools/gen_license.py new --plan term --days 365 |
| Cấp dùng thử 14 ngày | python tools/gen_license.py new --plan trial --days 14 |
| Cấp vĩnh viễn | python tools/gen_license.py new --plan perpetual |
| Cấp nhưng chưa thanh toán | thêm --unpaid vào lệnh new |
| Xác nhận đã thanh toán | python tools/gen_license.py status MA_KH KEY active |
| Khóa license | python tools/gen_license.py status MA_KH KEY blocked |
| Gia hạn thêm 1 năm | python tools/gen_license.py extend MA_KH KEY --days 365 |
| Xem danh sách | python tools/gen_license.py list |

Sau mỗi lệnh:

1. Lệnh new in ra mã khách hàng và license key. Gửi riêng cho khách, không đăng lên GitHub.
2. Commit và đẩy file license-status.json lên GitHub.
3. Chờ 1-10 phút để GitHub Pages cập nhật.

## 3. Phát hành bản cập nhật

1. Tải bản cài đặt mới lên nơi lưu trữ (Google Drive hoặc GitHub Releases).
2. Sửa version.json: latest_version, min_supported_version, download_url, release_notes.
3. Đẩy lên GitHub. Ứng dụng có phiên bản thấp hơn latest_version sẽ báo cập nhật; thấp hơn min_supported_version sẽ bị buộc cập nhật.

## 4. Mã trong ứng dụng

- Flutter: client/license_service.dart
- Web / React: client/license_client.js

## 5. Giới hạn cần biết

Cách này đơn giản, miễn phí nhưng không chống được người có kỹ thuật cố tình bẻ khóa: file công khai, mã chạy trên máy khách. Khi cần bảo mật cao hơn (giới hạn số máy, chống chia sẻ key), chuyển phần kiểm tra sang máy chủ có xác thực (Supabase) và chỉ để version.json trên GitHub Pages.
