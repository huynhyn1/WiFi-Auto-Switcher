using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

[assembly: AssemblyTitle("WiFi Auto Switcher Pro")]
[assembly: AssemblyProduct("WiFi Auto Switcher Pro")]
[assembly: AssemblyCompany("S.Nova")]
[assembly: AssemblyDescription("Intelligent Wi-Fi Auto Switcher & Network Monitor for Windows by S.Nova")]
[assembly: AssemblyVersion("2.6.5.0")]
[assembly: AssemblyFileVersion("2.6.5.0")]
[assembly: AssemblyCopyright("Copyright © 2026 S.Nova")]

static class Program {
    [DllImport("user32.dll")]
    static extern bool SetProcessDPIAware();

    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    static extern bool SetForegroundWindow(IntPtr hWnd);

    const int SW_RESTORE = 9;
    const string MUTEX_ID = "Global\\WiFiAutoSwitcherPro_App_Mutex_2026";

    [STAThread]
    static void Main(string[] args) {
        try { SetProcessDPIAware(); } catch { }

        bool createdNew;
        using (Mutex mutex = new Mutex(true, MUTEX_ID, out createdNew)) {
            if (!createdNew) {
                // If already running, activate the existing window
                IntPtr hWnd = FindWindow(null, "WiFi Auto Switcher Pro Enterprise");
                if (hWnd != IntPtr.Zero) {
                    ShowWindow(hWnd, SW_RESTORE);
                    SetForegroundWindow(hWnd);
                } else {
                    MessageBox.Show(
                        "WiFi Auto Switcher Pro đang hoạt động ngầm để bảo vệ mạng.\n\nBiểu tượng ứng dụng nằm ở góc dưới bên phải (khay hệ thống gần đồng hồ Windows).",
                        "WiFi Auto Switcher Pro",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Information
                    );
                }
                return;
            }

            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            Environment.CurrentDirectory = baseDir;

            string scriptPath = Path.Combine(baseDir, "WifiSwitcherApp.ps1");
            string scriptCode = null;

            if (File.Exists(scriptPath)) {
                try {
                    scriptCode = File.ReadAllText(scriptPath, System.Text.Encoding.UTF8);
                } catch (Exception ex) {
                    MessageBox.Show(
                        "Không thể đọc file WifiSwitcherApp.ps1:\n" + ex.Message,
                        "WiFi Auto Switcher Pro - Lỗi Khởi Động",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error
                    );
                    return;
                }
            }

            // Fallback: check embedded resource if external file missing
            if (string.IsNullOrEmpty(scriptCode)) {
                Assembly asm = Assembly.GetExecutingAssembly();
                string[] resNames = asm.GetManifestResourceNames();
                foreach (string name in resNames) {
                    if (name.EndsWith(".ps1", StringComparison.OrdinalIgnoreCase)) {
                        using (Stream s = asm.GetManifestResourceStream(name))
                        using (StreamReader reader = new StreamReader(s, System.Text.Encoding.UTF8)) {
                            scriptCode = reader.ReadToEnd();
                            break;
                        }
                    }
                }
            }

            if (string.IsNullOrEmpty(scriptCode)) {
                MessageBox.Show(
                    "Không tìm thấy mã thực thi WifiSwitcherApp.ps1 trong thư mục ứng dụng.",
                    "WiFi Auto Switcher Pro - Thiếu Tệp",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
                return;
            }

            InitialSessionState iss = InitialSessionState.CreateDefault();
            iss.ApartmentState = ApartmentState.STA;
            iss.ThreadOptions = PSThreadOptions.UseCurrentThread;

            using (Runspace rs = RunspaceFactory.CreateRunspace(iss)) {
                rs.ApartmentState = ApartmentState.STA;
                rs.ThreadOptions = PSThreadOptions.UseCurrentThread;
                rs.Open();

                using (PowerShell ps = PowerShell.Create()) {
                    ps.Runspace = rs;

                    // Pass CLI args to PowerShell environment
                    ps.AddScript("param($CliArgs) $Global:AppCliArgs = $CliArgs; $Global:IsCompiledHost = $true");
                    ps.AddParameter("CliArgs", args);
                    ps.Invoke();

                    // Execute main application script
                    ps.Commands.Clear();
                    ps.AddScript(scriptCode);
                    ps.Invoke();

                    if (ps.HadErrors) {
                        System.Text.StringBuilder sb = new System.Text.StringBuilder();
                        foreach (var err in ps.Streams.Error) {
                            sb.AppendLine(err.ToString());
                        }
                        // Write to debug log if errors occur
                        try {
                            File.WriteAllText(Path.Combine(baseDir, "AppDebugError.log"), sb.ToString(), System.Text.Encoding.UTF8);
                        } catch { }
                    }
                }
            }
        }
    }
}
