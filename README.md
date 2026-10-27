# WiFi Auto Switcher Pro v2.6.3

Ứng dụng Windows theo dõi chất lượng kết nối và tự động chuyển sang mạng Wi-Fi đã lưu phù hợp hơn.

[![Latest release](https://img.shields.io/github/v/release/huynhyn1/WiFi-Auto-Switcher)](https://github.com/huynhyn1/WiFi-Auto-Switcher/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/huynhyn1/WiFi-Auto-Switcher/total)](https://github.com/huynhyn1/WiFi-Auto-Switcher/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Tải bản Windows:** [Mở trang Releases](https://github.com/huynhyn1/WiFi-Auto-Switcher/releases/latest) và tải gói ZIP để cài đặt đầy đủ.

## Tính năng

- Theo dõi độ trễ, tín hiệu và chất lượng kết nối Wi-Fi.
- Tự động chuyển sang mạng Wi-Fi đã lưu khi mạng hiện tại không ổn định.
- Tốc độ download thấp hoặc phép đo trả về 0 phải lặp lại trong ba lần kiểm tra liên tiếp; log cũng ghi tình trạng kết nối tới router. Chỉ thử chuyển nếu có Wi-Fi đã lưu mạnh hơn ít nhất ngưỡng cải thiện cấu hình.
- Có các cấu hình nhanh cho chơi game, sử dụng thông thường, tiết kiệm mạng và tùy chỉnh.
- Giao diện tiếng Việt và tiếng Anh, kèm cửa sổ mini theo dõi trạng thái mạng.
- Phân tích thông tin Wi-Fi từ Windows bằng cả tiếng Việt và tiếng Anh.
- Có thể chạy trực tiếp hoặc thiết lập shortcut và khởi động cùng Windows.

## Cài đặt

1. Tải gói ZIP mới nhất từ [Releases](https://github.com/huynhyn1/WiFi-Auto-Switcher/releases/latest).
2. Giải nén toàn bộ gói vào thư mục, rồi mở `Setup.exe`.
3. Chọn tùy chọn shortcut hoặc khởi động cùng Windows. Trình cài đặt chép ứng dụng vào thư mục người dùng; sau đó có thể xóa thư mục ZIP đã giải nén.

`Setup.exe` cài ứng dụng vào `%LOCALAPPDATA%\Programs\WiFi Auto Switcher Pro`; sau đó có thể xóa thư mục ZIP đã giải nén. Cấu hình và nhật ký được lưu riêng trong `%LOCALAPPDATA%\WiFi Auto Switcher Pro`, được chuyển từ bản cài cũ nếu có và giữ lại khi gỡ ứng dụng. Ứng dụng chỉ có thể chuyển sang các mạng Wi-Fi đã được lưu trên máy. Để gỡ hoàn toàn dữ liệu cá nhân, hãy xóa thư mục dữ liệu này sau khi gỡ cài đặt.

Hướng dẫn chi tiết: [HUONG-DAN-SU-DUNG.html](HUONG-DAN-SU-DUNG.html).

## Mã nguồn và biên dịch

Mã nguồn chính nằm trong `src/`. Trên Windows, mở PowerShell tại thư mục dự án và chạy:

```powershell
.\src\build.ps1
```

Script biên dịch tạo `WiFiAutoSwitcher.exe` và `Setup.exe` ở thư mục gốc. Dự án sử dụng trình biên dịch C# và các thành phần Windows PowerShell có sẵn trên Windows.

Để đóng gói bản chạy:

```powershell
.\src\package.ps1
```

Gói ZIP được tạo trong `dist/`. Có thể truyền `-OutputPath` để chọn vị trí lưu khác.

GitHub Actions tự động kiểm tra cú pháp, build ứng dụng Windows và chạy kiểm thử mô phỏng khi có push hoặc pull request vào `main`. Bản build CI được lưu dưới dạng workflow artifact.

## Cấu trúc dự án

| Đường dẫn | Nội dung |
| --- | --- |
| `src/` | Mã nguồn C#, ứng dụng PowerShell, script build và kiểm thử |
| `legacy/` | Các script khởi chạy và cài đặt cũ |
| `Setup.exe` | Trình cài đặt/gỡ cài đặt ứng dụng |
| `WiFiAutoSwitcher.exe` | Ứng dụng Windows |
| `WifiSwitcherApp.ps1` | Script ứng dụng chạy cạnh tệp `.exe` |
| `config.json` | Cấu hình mặc định |
| `HUONG-DAN-SU-DUNG.html` | Hướng dẫn sử dụng chi tiết |

## Tác giả

Phát triển bởi **S.Nova**. Phân phối theo giấy phép [MIT](LICENSE).
