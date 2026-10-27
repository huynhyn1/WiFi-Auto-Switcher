# WiFi Auto Switcher Pro

Ứng dụng Windows theo dõi chất lượng kết nối và tự động chuyển sang mạng Wi-Fi đã lưu phù hợp hơn.

[![Latest release](https://img.shields.io/github/v/release/huynhyn1/WiFi-Auto-Switcher)](https://github.com/huynhyn1/WiFi-Auto-Switcher/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/huynhyn1/WiFi-Auto-Switcher/total)](https://github.com/huynhyn1/WiFi-Auto-Switcher/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Tải bản Windows:** [Mở trang Releases](https://github.com/huynhyn1/WiFi-Auto-Switcher/releases/latest) và tải gói ZIP để cài đặt đầy đủ.

## Tính năng

- Theo dõi độ trễ, tín hiệu và chất lượng kết nối Wi-Fi.
- Tự động chuyển sang mạng Wi-Fi đã lưu khi mạng hiện tại không ổn định.
- Có các cấu hình nhanh cho chơi game, sử dụng thông thường, tiết kiệm mạng và tùy chỉnh.
- Giao diện tiếng Việt và tiếng Anh, kèm cửa sổ mini theo dõi trạng thái mạng.
- Có thể chạy trực tiếp hoặc thiết lập shortcut và khởi động cùng Windows.

## Cài đặt

1. Tải gói ZIP mới nhất từ [Releases](https://github.com/huynhyn1/WiFi-Auto-Switcher/releases/latest).
2. Giải nén toàn bộ gói vào một thư mục; không chạy `Setup.exe` trực tiếp bên trong ZIP.
3. Mở `Setup.exe` để tạo shortcut và chọn tùy chọn khởi động cùng Windows. Có thể mở `WiFiAutoSwitcher.exe` để chạy trực tiếp.

Giữ các tệp trong cùng thư mục để trình cài đặt và ứng dụng tìm thấy các thành phần đi kèm. Ứng dụng chỉ có thể chuyển sang các mạng Wi-Fi đã được lưu trên máy.

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

## Cấu trúc dự án

| Đường dẫn | Nội dung |
| --- | --- |
| `src/` | Mã nguồn C#, ứng dụng PowerShell, script build và kiểm thử |
| `legacy/` | Các script khởi chạy và cài đặt cũ |
| `Setup.exe` | Tiện ích tạo shortcut và cấu hình khởi động cùng Windows |
| `WiFiAutoSwitcher.exe` | Ứng dụng Windows |
| `WifiSwitcherApp.ps1` | Script ứng dụng chạy cạnh tệp `.exe` |
| `config.json` | Cấu hình mặc định |
| `HUONG-DAN-SU-DUNG.html` | Hướng dẫn sử dụng chi tiết |

## Tác giả

Phát triển bởi **S.Nova**. Phân phối theo giấy phép [MIT](LICENSE).
