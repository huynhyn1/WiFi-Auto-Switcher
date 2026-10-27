# ==============================================================================
# SCRIPT BUILD TU DONG - WIFI AUTO SWITCHER PRO
# Tac gia: S.Nova
# Bien dich ma nguon C# va nhung ma PowerShell thanh file (.exe)
# ==============================================================================

$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) {
    $csc = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
}
if (-not (Test-Path $csc)) {
    Write-Error "Khong tim thay trinh bien dich csc.exe cua .NET Framework!"
    exit 1
}

$rootDir = Split-Path $PSScriptRoot -Parent
$ico = Join-Path $rootDir "app.ico"
$psScript = Join-Path $PSScriptRoot "WifiSwitcherApp.ps1"
$psAutomationDll = "C:\Windows\Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation\v4.0_3.0.0.0__31bf3856ad364e35\System.Management.Automation.dll"

Write-Host ">>> Dang bien dich WiFiAutoSwitcher.exe..." -ForegroundColor Cyan
$argsMain = @(
    "/nologo",
    "/target:winexe",
    "/win32icon:$ico",
    "/resource:$psScript,EmbeddedScript.ps1",
    "/r:System.dll,System.Windows.Forms.dll,System.Drawing.dll,$psAutomationDll",
    "/out:$rootDir\WiFiAutoSwitcher.exe",
    "$PSScriptRoot\WiFiAutoSwitcher.cs"
)
& $csc $argsMain

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Bien dich WiFiAutoSwitcher.exe thanh cong!" -ForegroundColor Green
} else {
    Write-Error "Loi khi bien dich WiFiAutoSwitcher.exe"
    exit $LASTEXITCODE
}

Write-Host ">>> Dang bien dich Setup.exe..." -ForegroundColor Cyan
$argsSetup = @(
    "/nologo",
    "/target:winexe",
    "/win32icon:$ico",
    "/r:System.dll,System.Windows.Forms.dll,System.Drawing.dll,Microsoft.CSharp.dll",
    "/out:$rootDir\Setup.exe",
    "$PSScriptRoot\SetupInstaller.cs"
)
& $csc $argsSetup

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Bien dich Setup.exe thanh cong!" -ForegroundColor Green
} else {
    Write-Error "Loi khi bien dich Setup.exe"
    exit $LASTEXITCODE
}

Write-Host "`nHoan tat! Cac file exe da duoc cap nhat day du tac gia S.Nova." -ForegroundColor Yellow
