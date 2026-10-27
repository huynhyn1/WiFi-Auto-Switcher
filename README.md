# ⚡ WiFi Auto Switcher Pro v2.5

> **Phần Mềm Tự Động Giám Sát Độ Trễ & Chuyển Đổi Wi-Fi Thông Minh Trên Windows**  
> *Tác giả:* **S.Nova** • *Phiên bản:* **v2.5 Enterprise** • *Ngôn ngữ:* **Tiếng Việt & English**  
> *100% Native Windows Binary • Single-Instance Protection • Zero-Configuration*

---

## 🌟 Tổng Quan Kiến Trúc & Tính Năng Chuyên Nghiệp

1. **Tác Giả & Bản Quyền**:
   - Được thiết kế và phát triển bởi **S.Nova**.
   - Hỗ trợ chuyển đổi **Song Ngữ Tức Thì (Tiếng Việt / English)** ngay trên thanh tiêu đề (`🌐 VI` / `🌐 EN`) hoặc trong tab Cài Đặt.

2. **Khởi Chạy Chuẩn Windows Native (`WiFiAutoSwitcher.exe`)**:
   - Được biên dịch thành file nhị phân Windows Subsystem (`winexe`), hoàn toàn **không mở cửa sổ console đen**.
   - Biểu tượng ứng dụng độ phân giải cao (`app.ico` 16x16 đến 256x256), nhúng sẵn thông tin bản quyền tác giả **S.Nova**.
   - Cơ chế bảo vệ **Single-Instance Mutex**: Ngăn chặn người dùng mở nhiều phiên bản trùng lặp gây xung đột card mạng. Nếu app đang chạy ngầm, click vào `.exe` sẽ tự động kích hoạt cửa sổ hiện hành hoặc hiển thị thông báo.

3. **Chế Độ Tối Ưu Nhanh (Quick Profiles)**:
   - **🎮 Chế độ Gaming / Họp trực tuyến**: Ping tối đa 80ms, tốc độ tối thiểu 5 Mbps, mất gói < 5%. Ưu tiên độ trễ cực thấp, không giật lag.
   - **🌐 Chế độ Tiêu chuẩn**: Ping tối đa 150ms, tốc độ tối thiểu 2 Mbps, mất gói < 25%. Cân bằng tối ưu cho văn phòng, học tập, giải trí.
   - **🔋 Chế độ Tiết kiệm mạng**: Ping 220ms, tốc độ 1 Mbps, mất gói < 40%. Chỉ chuyển khi mất kết nối hoặc sóng cực yếu.
   - **⚙️ Chế độ Tùy chỉnh**: Tự do điều chỉnh toàn bộ thông số kỹ thuật.

4. **Trình Cài Đặt & Cấu Hình Tự Động (`Setup.exe`)**:
   - Giao diện cài đặt 1-Click tiện lợi, hỗ trợ bởi **S.Nova**.
   - Tự động tạo Shortcut Desktop gắn icon ứng dụng.
   - Đăng ký chạy ngầm cùng Windows an toàn qua Registry (`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`), không dùng file batch hay script ẩn.
   - Đăng ký đầy đủ mục gỡ cài đặt sạch sẽ trong Windows Settings / Control Panel (`Programs and Features`).

5. **Giao Diện Điều Khiển Cao Cấp (Frameless Dark Glass)**:
   - Hệ thống 5 phân hệ chuyên sâu: **Tổng Quan (Dashboard)**, **Tự Động Đổi (Smart Switch)**, **Radar Quét Sóng (Wi-Fi Radar)**, **Nhật Ký & Sự Kiện (Analytics)**, **Cài Đặt Hệ Thống (Settings)**.
   - **Mini HUD Widget**: Bảng nhỏ theo dõi Ping / Sóng / Tốc độ nổi trên màn hình, hỗ trợ kéo thả tự do và ghi nhớ vị trí.

6. **Chỉ Số Sức Khỏe Mạng & Độ Trễ Kép (Network Health Score 0 - 100)**:
   - Đo đạc đồng thời **Router LAN Ping** (xác định lỗi trạm phát nội bộ) và **Internet WAN Ping** (xác định lỗi đường truyền nhà mạng ISP).
   - Tự động quét và chuyển sang Wi-Fi đã lưu có tín hiệu và tốc độ tốt nhất khi mạng hiện tại bị chập chờn hoặc rớt gói tin.

---

## 🚀 Hướng Dẫn Sử Dụng

| Tệp tin | Chức năng | Hướng dẫn |
| :--- | :--- | :--- |
| **`WiFiAutoSwitcher.exe`** | Ứng dụng chính | Nhấp đúp chuột để mở trực tiếp (Chạy độc lập, không cần cài đặt). |
| **`Setup.exe`** | Trình Cài Đặt & Gỡ Bỏ | Nhấp đúp chuột để cấu hình Shortcut Desktop và tự khởi động ngầm cùng Windows. |
| **`HUONG-DAN-SU-DUNG.html`** | Sổ tay hướng dẫn | Mở trên trình duyệt web để xem hướng dẫn trực quan chi tiết. |
| **`config.json`** | File cấu hình | Lưu trữ các ngưỡng Ping, tốc độ và chế độ hoạt động của ứng dụng. |
| **`src/`** | Mã nguồn phát triển | Chứa source code C# và file build tự động (`build.ps1`). |

---

## 🛠️ Biên Dịch Lại (Dành cho Lập trình viên)

Toàn bộ mã nguồn nằm trong thư mục `src/`:
- `src/WiFiAutoSwitcher.cs`: Host C# STA Single-Instance.
- `src/SetupInstaller.cs`: Trình cài đặt Setup GUI.
- `src/WifiSwitcherApp.ps1`: Engine giao diện WPF và thuật toán giám sát mạng.
- `src/build.ps1`: Script biên dịch tự động 1-Click bằng trình biên dịch `csc.exe` có sẵn trên Windows.

---
*Phát triển bởi **S.Nova** • Bản quyền © 2026 S.Nova. Mọi quyền được bảo lưu.*
