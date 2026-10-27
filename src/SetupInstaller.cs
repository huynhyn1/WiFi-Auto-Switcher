using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("WiFi Auto Switcher Setup")]
[assembly: AssemblyProduct("WiFi Auto Switcher Pro")]
[assembly: AssemblyCompany("S.Nova")]
[assembly: AssemblyDescription("Trình Cài Đặt & Cấu Hình WiFi Auto Switcher Pro - Tác giả: S.Nova")]
[assembly: AssemblyVersion("2.5.0.0")]
[assembly: AssemblyFileVersion("2.5.0.0")]
[assembly: AssemblyCopyright("Copyright © 2026 S.Nova")]

public class SetupForm : Form {
    [DllImport("user32.dll")]
    static extern bool SetProcessDPIAware();

    private CheckBox cbDesktopShortcut;
    private CheckBox cbAutoStart;
    private CheckBox cbLaunchNow;
    private Button btnInstall;
    private Button btnUninstall;
    private Button btnExit;
    private Label lblStatus;

    public SetupForm() {
        try { SetProcessDPIAware(); } catch { }
        InitializeUI();
    }

    private void InitializeUI() {
        this.Text = "Cài Đặt & Cấu Hình - WiFi Auto Switcher Pro";
        this.Size = new Size(540, 390);
        this.StartPosition = FormStartPosition.CenterScreen;
        this.FormBorderStyle = FormBorderStyle.FixedDialog;
        this.MaximizeBox = false;
        this.MinimizeBox = false;
        this.BackColor = Color.FromArgb(15, 23, 42); // #0F172A
        this.ForeColor = Color.FromArgb(241, 245, 249);
        this.Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);

        string icoPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "app.ico");
        if (File.Exists(icoPath)) {
            try { this.Icon = new Icon(icoPath); } catch { }
        }

        // Header Panel
        Panel headerPanel = new Panel();
        headerPanel.Dock = DockStyle.Top;
        headerPanel.Height = 85;
        headerPanel.BackColor = Color.FromArgb(30, 41, 59); // #1E293B

        Label lblTitle = new Label();
        lblTitle.Text = "⚡ WiFi Auto Switcher Pro v2.5";
        lblTitle.Font = new Font("Segoe UI", 14f, FontStyle.Bold);
        lblTitle.ForeColor = Color.FromArgb(56, 189, 248); // #38BDF8
        lblTitle.Location = new Point(24, 16);
        lblTitle.AutoSize = true;
        headerPanel.Controls.Add(lblTitle);

        Label lblSubTitle = new Label();
        lblSubTitle.Text = "Hệ thống tự động giám sát & chuyển đổi Wi-Fi • Tác giả: S.Nova";
        lblSubTitle.Font = new Font("Segoe UI", 8.5f, FontStyle.Regular);
        lblSubTitle.ForeColor = Color.FromArgb(148, 163, 184); // #94A3B8
        lblSubTitle.Location = new Point(26, 48);
        lblSubTitle.AutoSize = true;
        headerPanel.Controls.Add(lblSubTitle);

        this.Controls.Add(headerPanel);

        // Options Box
        GroupBox grpOptions = new GroupBox();
        grpOptions.Text = " Tùy Chọn Cài Đặt & Kích Hoạt ";
        grpOptions.ForeColor = Color.FromArgb(203, 213, 225);
        grpOptions.Location = new Point(24, 105);
        grpOptions.Size = new Size(475, 140);

        cbDesktopShortcut = new CheckBox();
        cbDesktopShortcut.Text = "Tạo biểu tượng lối tắt trên màn hình chính (Desktop Shortcut)";
        cbDesktopShortcut.Checked = true;
        cbDesktopShortcut.ForeColor = Color.FromArgb(241, 245, 249);
        cbDesktopShortcut.Location = new Point(24, 30);
        cbDesktopShortcut.Size = new Size(430, 24);
        grpOptions.Controls.Add(cbDesktopShortcut);

        cbAutoStart = new CheckBox();
        cbAutoStart.Text = "Tự động khởi động ngầm cùng Windows (Khay hệ thống Taskbar)";
        cbAutoStart.Checked = true;
        cbAutoStart.ForeColor = Color.FromArgb(241, 245, 249);
        cbAutoStart.Location = new Point(24, 62);
        cbAutoStart.Size = new Size(430, 24);
        grpOptions.Controls.Add(cbAutoStart);

        cbLaunchNow = new CheckBox();
        cbLaunchNow.Text = "Mở ứng dụng WiFi Auto Switcher Pro ngay sau khi hoàn tất";
        cbLaunchNow.Checked = true;
        cbLaunchNow.ForeColor = Color.FromArgb(241, 245, 249);
        cbLaunchNow.Location = new Point(24, 94);
        cbLaunchNow.Size = new Size(430, 24);
        grpOptions.Controls.Add(cbLaunchNow);

        this.Controls.Add(grpOptions);

        // Status Label
        lblStatus = new Label();
        lblStatus.Text = "Thư mục cài đặt: " + AppDomain.CurrentDomain.BaseDirectory;
        lblStatus.ForeColor = Color.FromArgb(100, 116, 139);
        lblStatus.Font = new Font("Segoe UI", 8f);
        lblStatus.Location = new Point(24, 255);
        lblStatus.Size = new Size(475, 20);
        this.Controls.Add(lblStatus);

        // Action Buttons
        btnInstall = new Button();
        btnInstall.Text = "✔ Cài Đặt / Kích Hoạt";
        btnInstall.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
        btnInstall.BackColor = Color.FromArgb(14, 165, 233);
        btnInstall.ForeColor = Color.White;
        btnInstall.FlatStyle = FlatStyle.Flat;
        btnInstall.FlatAppearance.BorderSize = 0;
        btnInstall.Location = new Point(145, 290);
        btnInstall.Size = new Size(165, 38);
        btnInstall.Click += BtnInstall_Click;
        this.Controls.Add(btnInstall);

        btnUninstall = new Button();
        btnUninstall.Text = "🗑 Gỡ Khỏi Hệ Thống";
        btnUninstall.Font = new Font("Segoe UI", 9f);
        btnUninstall.BackColor = Color.FromArgb(51, 65, 85);
        btnUninstall.ForeColor = Color.FromArgb(248, 113, 113);
        btnUninstall.FlatStyle = FlatStyle.Flat;
        btnUninstall.FlatAppearance.BorderSize = 0;
        btnUninstall.Location = new Point(320, 290);
        btnUninstall.Size = new Size(130, 38);
        btnUninstall.Click += BtnUninstall_Click;
        this.Controls.Add(btnUninstall);

        btnExit = new Button();
        btnExit.Text = "Đóng";
        btnExit.Font = new Font("Segoe UI", 9f);
        btnExit.BackColor = Color.FromArgb(30, 41, 59);
        btnExit.ForeColor = Color.FromArgb(148, 163, 184);
        btnExit.FlatStyle = FlatStyle.Flat;
        btnExit.FlatAppearance.BorderSize = 0;
        btnExit.Location = new Point(458, 290);
        btnExit.Size = new Size(42, 38);
        btnExit.Click += (s, e) => this.Close();
        this.Controls.Add(btnExit);
    }

    private void BtnInstall_Click(object sender, EventArgs e) {
        try {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string exePath = Path.Combine(baseDir, "WiFiAutoSwitcher.exe");
            string icoPath = Path.Combine(baseDir, "app.ico");

            if (!File.Exists(exePath)) {
                MessageBox.Show(
                    "Không tìm thấy file 'WiFiAutoSwitcher.exe' trong thư mục:\n" + baseDir,
                    "Lỗi Cài Đặt",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
                return;
            }

            // 1. Tạo Desktop Shortcut
            if (cbDesktopShortcut.Checked) {
                string desktopPath = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                string shortcutPath = Path.Combine(desktopPath, "WiFi Auto Switcher Pro.lnk");

                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType != null) {
                    dynamic shell = Activator.CreateInstance(shellType);
                    dynamic shortcut = shell.CreateShortcut(shortcutPath);
                    shortcut.TargetPath = exePath;
                    shortcut.WorkingDirectory = baseDir;
                    if (File.Exists(icoPath)) {
                        shortcut.IconLocation = icoPath + ",0";
                    }
                    shortcut.Description = "WiFi Auto Switcher Pro - Enterprise Intelligent Wi-Fi Manager";
                    shortcut.Save();
                }
            }

            // 2. Đăng ký Run on Startup (Registry HKCU)
            using (RegistryKey runKey = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true)) {
                if (runKey != null) {
                    if (cbAutoStart.Checked) {
                        runKey.SetValue("WiFiAutoSwitcherPro", "\"" + exePath + "\" --minimized");
                    } else {
                        runKey.DeleteValue("WiFiAutoSwitcherPro", false);
                    }
                }
            }

            // Dọn dẹp shortcut cũ trong Startup folder nếu có
            string startupFolder = Environment.GetFolderPath(Environment.SpecialFolder.Startup);
            string oldLnk = Path.Combine(startupFolder, "WiFiAutoSwitcherPro.lnk");
            if (File.Exists(oldLnk)) {
                try { File.Delete(oldLnk); } catch { }
            }

            // 3. Đăng ký thông tin trong Control Panel (Add/Remove Programs)
            using (RegistryKey uninstKey = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\WiFiAutoSwitcherPro")) {
                if (uninstKey != null) {
                    uninstKey.SetValue("DisplayName", "WiFi Auto Switcher Pro");
                    uninstKey.SetValue("DisplayVersion", "2.5.0");
                    uninstKey.SetValue("Publisher", "S.Nova");
                    uninstKey.SetValue("InstallLocation", baseDir);
                    uninstKey.SetValue("DisplayIcon", File.Exists(icoPath) ? icoPath + ",0" : exePath + ",0");
                    string setupExe = Path.Combine(baseDir, "Setup.exe");
                    uninstKey.SetValue("UninstallString", "\"" + setupExe + "\"");
                    uninstKey.SetValue("HelpLink", "https://github.com");
                    uninstKey.SetValue("NoModify", 1, RegistryValueKind.DWord);
                    uninstKey.SetValue("NoRepair", 1, RegistryValueKind.DWord);
                }
            }

            // 4. Khởi chạy ứng dụng nếu được chọn
            if (cbLaunchNow.Checked) {
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = exePath;
                psi.WorkingDirectory = baseDir;
                Process.Start(psi);
            }

            MessageBox.Show(
                "Cài đặt và thiết lập thành công!\n\n" +
                "• Biểu tượng ứng dụng đã được gắn ngoài Desktop.\n" +
                (cbAutoStart.Checked ? "• Ứng dụng đã được đăng ký tự khởi động ngầm bảo vệ mạng khi bật máy.\n" : "") +
                "• Bạn có thể quản lý hoặc gỡ bỏ bất kỳ lúc nào trong Windows Settings / Control Panel.",
                "Cài Đặt Thành Công",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information
            );

            this.Close();
        } catch (Exception ex) {
            MessageBox.Show(
                "Có lỗi xảy ra trong quá trình cài đặt:\n" + ex.Message,
                "Lỗi Cài Đặt",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            );
        }
    }

    private void BtnUninstall_Click(object sender, EventArgs e) {
        var res = MessageBox.Show(
            "Bạn có chắc chắn muốn gỡ bỏ lối tắt và đăng ký tự khởi động của WiFi Auto Switcher Pro khỏi hệ thống?",
            "Xác Nhận Gỡ Bỏ",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Question
        );

        if (res != DialogResult.Yes) return;

        try {
            // 1. Tắt tiến trình nếu đang chạy
            Process[] procs = Process.GetProcessesByName("WiFiAutoSwitcher");
            foreach (var p in procs) {
                try { p.Kill(); } catch { }
            }

            // 2. Xóa Desktop Shortcut
            string desktopPath = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            string shortcutPath = Path.Combine(desktopPath, "WiFi Auto Switcher Pro.lnk");
            if (File.Exists(shortcutPath)) { File.Delete(shortcutPath); }

            // 3. Xóa Startup Registry
            using (RegistryKey runKey = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true)) {
                if (runKey != null) {
                    runKey.DeleteValue("WiFiAutoSwitcherPro", false);
                }
            }

            // 4. Xóa Startup folder link nếu có
            string startupFolder = Environment.GetFolderPath(Environment.SpecialFolder.Startup);
            string oldLnk = Path.Combine(startupFolder, "WiFiAutoSwitcherPro.lnk");
            if (File.Exists(oldLnk)) { File.Delete(oldLnk); }

            // 5. Xóa Registry Uninstall
            Registry.CurrentUser.DeleteSubKeyTree(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\WiFiAutoSwitcherPro", false);

            MessageBox.Show(
                "Đã gỡ bỏ toàn bộ lối tắt và đăng ký hệ thống của WiFi Auto Switcher Pro thành công.\n\n" +
                "Thư mục ứng dụng hiện an toàn, bạn có thể xóa hoặc lưu trữ tùy ý.",
                "Gỡ Cài Đặt Hoàn Tất",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information
            );

            this.Close();
        } catch (Exception ex) {
            MessageBox.Show(
                "Lỗi khi gỡ cài đặt:\n" + ex.Message,
                "Lỗi",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            );
        }
    }

    [STAThread]
    public static void Main() {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new SetupForm());
    }
}
