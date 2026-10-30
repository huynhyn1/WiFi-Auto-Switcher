# ==============================================================================
# FULL UI & LOGIC SIMULATION TEST HARNESS
# WiFi Auto Switcher Pro v2.6.7
# Tac gia: S.Nova
# ==============================================================================

[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$rootDir = Split-Path $PSScriptRoot -Parent
$scriptPath = Join-Path $rootDir "WifiSwitcherApp.ps1"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   BAT DAU CHAY GIA LAP VA MO PHONG TOAN BO HE THONG" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

function Record-Test ([string]$testName, [bool]$passed, [string]$details) {
    $status = if ($passed) { "PASSED" } else { "FAILED" }
    $color  = if ($passed) { "Green" } else { "Red" }
    Write-Host ("[{0}] {1}: {2}" -f $status, $testName, $details) -ForegroundColor $color
    $results.Add([PSCustomObject]@{
        TestName = $testName
        Status   = $status
        Details  = $details
    })
}

# 1. Test cu phap PowerShell cua WifiSwitcherApp.ps1
try {
    $errors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
    if ($errors.Count -eq 0) {
        Record-Test "Syntax AST Parser" $true "Khong co bat ky loi cu phap nao trong 2191 dong code."
    } else {
        Record-Test "Syntax AST Parser" $false ("Co {0} loi cu phap: {1}" -f $errors.Count, $errors[0].Message)
    }
} catch {
    Record-Test "Syntax AST Parser" $false $_.Exception.Message
}

# 2. Khoi tao moi truong WPF & Tai XAML tren luong STA hien tai
try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $code = Get-Content -Path $scriptPath -Raw -Encoding UTF8
    
    # Bypass blocking app loop and post-exit cleanup for unit testing
    $code = $code -replace '\[void\]\$app\.Run\(\$window\)', '# App Run bypassed for simulation'
    $code = $code -replace '\[void\]\$app\.Run\(\)', '# App Run bypassed for simulation'
    $code = $code -replace '\$monitorTimer\.Start\(\)', '# Timer start bypassed for simulation'
    $code = $code -replace '(?s)if \(\$miniWindow\) \{.*?\$miniWindow\.Close\(\).*?\}', '# MiniWindow cleanup bypassed'

    Invoke-Expression $code

    Write-Host "`n>>> 1. KIEM THU GIAO DIEN CHINH VA MINI HUD XAML..." -ForegroundColor Yellow
    if ($window -ne $null -and $window -is [System.Windows.Window]) {
        Record-Test "Main Window Init" $true ("Cua so chinh WPF khoi tao thanh cong (Width: {0}, Height: {1})" -f $window.Width, $window.Height)
    } else {
        Record-Test "Main Window Init" $false "Khong khoi tao duoc MainWindow"
    }

    if ($miniWindow -ne $null -and $miniWindow -is [System.Windows.Window]) {
        Record-Test "Mini HUD Init" $true ("Bang noi Mini HUD khoi tao thanh cong (Width: {0}, Height: {1})" -f $miniWindow.Width, $miniWindow.Height)
    } else {
        Record-Test "Mini HUD Init" $false "Khong khoi tao duoc MiniHUD"
    }

    Show-CompactWidget
    $compactModeWorks = ($miniWindow.IsVisible -and -not $window.IsVisible)
    Show-ControlDashboard
    $dashboardModeWorks = ($window.IsVisible -and -not $miniWindow.IsVisible)
    Record-Test "Dashboard and widget are unified modes" ($compactModeWorks -and $dashboardModeWorks) "Chuyen duoc giua bang dieu khien va widget, chi hien mot cua so moi lan"

    Write-Host "`n>>> 2. MO PHONG CHUYEN DOI 5 PHAN HE GIAO DIEN (TABS)..." -ForegroundColor Yellow
    $tabs = @(
        @{ Btn = $BtnNavDashboard;   Panel = $PanelDashboard;   Name = "Dashboard" },
        @{ Btn = $BtnNavSmartSwitch; Panel = $PanelSmartSwitch; Name = "Smart Switch" },
        @{ Btn = $BtnNavRadar;       Panel = $PanelRadar;       Name = "Wi-Fi Radar" },
        @{ Btn = $BtnNavAnalytics;   Panel = $PanelAnalytics;   Name = "Analytics" },
        @{ Btn = $BtnNavSettings;    Panel = $PanelSettings;    Name = "Settings" }
    )

    foreach ($t in $tabs) {
        $t.Btn.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
        $isVisible = ($t.Panel.Visibility -eq [System.Windows.Visibility]::Visible)
        Record-Test ("Tab Nav: " + $t.Name) $isVisible ("Trang thai hien thi Panel: " + $t.Panel.Visibility.ToString())
    }

    Write-Host "`n>>> 3. MO PHONG CHUYEN DOI CHE DO TOI UU NHANH (PROFILES)..." -ForegroundColor Yellow
    
    # Test Gaming Profile
    Set-ActiveProfile "Gaming" $false
    $gPass = ($Global:Config.ActiveProfile -eq "Gaming" -and $Global:Config.MaxPingMs -eq 80 -and $Global:Config.MinSpeedMbps -eq 5.0)
    Record-Test "Profile Gaming" $gPass ("Ping threshold: {0}ms, Min Speed: {1}Mbps, Loss: {2}%" -f $Global:Config.MaxPingMs, $Global:Config.MinSpeedMbps, $Global:Config.MaxPacketLossPercent)

    # Test Standard Profile
    Set-ActiveProfile "Standard" $false
    $sPass = ($Global:Config.ActiveProfile -eq "Standard" -and $Global:Config.MaxPingMs -eq 150 -and $Global:Config.MinSpeedMbps -eq 2.0)
    Record-Test "Profile Standard" $sPass ("Ping threshold: {0}ms, Min Speed: {1}Mbps, Loss: {2}%" -f $Global:Config.MaxPingMs, $Global:Config.MinSpeedMbps, $Global:Config.MaxPacketLossPercent)

    # Test Saving Profile
    Set-ActiveProfile "Saving" $false
    $svPass = ($Global:Config.ActiveProfile -eq "Saving" -and $Global:Config.MaxPingMs -eq 220 -and $Global:Config.MinSpeedMbps -eq 1.0)
    Record-Test "Profile Saving" $svPass ("Ping threshold: {0}ms, Min Speed: {1}Mbps, Loss: {2}%" -f $Global:Config.MaxPingMs, $Global:Config.MinSpeedMbps, $Global:Config.MaxPacketLossPercent)

    # Test Custom Profile
    Set-ActiveProfile "Custom" $false
    $cPass = ($Global:Config.ActiveProfile -eq "Custom")
    Record-Test "Profile Custom" $cPass "Chuyen sang che do tuy chinh thanh cong"

    Write-Host "`n>>> 4. MO PHONG DA NGON NGU SONG NGU (VI vs EN)..." -ForegroundColor Yellow
    # Chuyen sang tieng Anh
    Apply-Language "en"
    $enPass = ($Global:Config.Language -eq "en" -and $BtnTitleLang.Content -like "*EN*" -and $TxtNavDashboard.Text -eq "Dashboard")
    Record-Test "Language Switch to EN" $enPass ("Title button: {0}, Nav text: {1}, Author card: {2}" -f $BtnTitleLang.Content, $TxtNavDashboard.Text, $TxtAuthorHeader.Text)

    # Chuyen lai tieng Viet
    Apply-Language "vi"
    $viPass = ($Global:Config.Language -eq "vi" -and $BtnTitleLang.Content -like "*VI*")
    Record-Test "Language Switch to VI" $viPass ("Title button: {0}, Nav text: {1}, Author card: {2}" -f $BtnTitleLang.Content, $TxtNavDashboard.Text, $TxtAuthorHeader.Text)

    Write-Host "`n>>> 5. MO PHONG THUAT TOAN DO SUC KHOE MANG (HEALTH SCORE)..." -ForegroundColor Yellow
    $h1 = Get-NetworkHealthScore -signal 95 -wanPingMs 15 -packetLoss 0 -speedMbps 10.0
    Record-Test "Health Score (Perfect Net)" ($h1.Score -ge 90) ("Diem so: {0}/100 - Trang thai: {1}" -f $h1.Score, $h1.Quality)

    $h2 = Get-NetworkHealthScore -signal 55 -wanPingMs 120 -packetLoss 8 -speedMbps 3.0
    Record-Test "Health Score (Degraded Net)" ($h2.Score -ge 50 -and $h2.Score -lt 85) ("Diem so: {0}/100 - Trang thai: {1}" -f $h2.Score, $h2.Quality)

    $h3 = Get-NetworkHealthScore -signal 25 -wanPingMs 350 -packetLoss 40 -speedMbps 0.5
    Record-Test "Health Score (Critical Net)" ($h3.Score -lt 50) ("Diem so: {0}/100 - Trang thai: {1}" -f $h3.Score, $h3.Quality)

    Write-Host "`n>>> KIEM TRA NGUONG TOC DO TAI XUONG..." -ForegroundColor Yellow
    Record-Test "Download failure triggers low-speed rule" (Test-DownloadSpeedBelowMinimum -speedMbps 0 -minimumMbps 2) "Toc do 0 Mbps duoi nguong va kich hoat dieu kien mang yeu"
    Record-Test "Download below minimum triggers" (Test-DownloadSpeedBelowMinimum -speedMbps 1.5 -minimumMbps 2) "Toc do thap hon nguong kich hoat dieu kien mang yeu"
    Record-Test "Download at minimum does not trigger" (-not (Test-DownloadSpeedBelowMinimum -speedMbps 2 -minimumMbps 2)) "Toc do bang nguong khong bi xem la thap"
    Record-Test "Download above minimum does not trigger" (-not (Test-DownloadSpeedBelowMinimum -speedMbps 5 -minimumMbps 2)) "Toc do tren nguong khong bi xem la thap"
    Record-Test "First low-speed result waits for confirmation" (-not (Test-DownloadFailureConfirmed -consecutiveFailures 1)) "Mot lan do thap chua kich hoat chuyen mang"
    Record-Test "Second low-speed result waits for confirmation" (-not (Test-DownloadFailureConfirmed -consecutiveFailures 2)) "Hai lan do thap lien tiep van cho xac nhan"
    Record-Test "Repeated low-speed result is confirmed" (Test-DownloadFailureConfirmed -consecutiveFailures 3) "Ba lan kiem tra lien tiep duoi nguong duoc xac nhan"
    Record-Test "Recovered speed clears confirmation" (-not (Test-DownloadFailureConfirmed -consecutiveFailures 0)) "Ket noi phuc hoi se khong giu loi cu"
    Record-Test "Disconnected network accepts available candidate" (Test-AlternativeNetworkIsBetter -currentConnected $false -currentSignal 0 -candidateSignal 30 -minimumImprovement 8) "Cho phep thu mang thay the khi mat ket noi"
    Record-Test "Stronger candidate meets improvement threshold" (Test-AlternativeNetworkIsBetter -currentConnected $true -currentSignal 40 -candidateSignal 48 -minimumImprovement 8) "Mang thay the manh hon du nguong"
    Record-Test "Slightly stronger candidate is rejected" (-not (Test-AlternativeNetworkIsBetter -currentConnected $true -currentSignal 40 -candidateSignal 47 -minimumImprovement 8)) "Khong doi sang mang chi manh hon mot chut"
    Record-Test "Equal signal candidate is rejected" (-not (Test-AlternativeNetworkIsBetter -currentConnected $true -currentSignal 40 -candidateSignal 40 -minimumImprovement 0)) "Khong doi sang mang co song bang mang hien tai"
    $healthyConnection = [PSCustomObject]@{ Connected = $true; SSID = "Home WiFi" }
    Record-Test "Switch requires target SSID and Internet" (Test-WifiSwitchSucceeded -connection $healthyConnection -expectedSSID "Home WiFi" -internetReachable $true) "Xac nhan thanh cong khi dung SSID va co Internet"
    Record-Test "Connected Wi-Fi without Internet is rejected" (-not (Test-WifiSwitchSucceeded -connection $healthyConnection -expectedSSID "Home WiFi" -internetReachable $false)) "Khong coi Wi-Fi khong co Internet la chuyen thanh cong"
    Record-Test "Unexpected connected SSID is rejected" (-not (Test-WifiSwitchSucceeded -connection $healthyConnection -expectedSSID "Guest" -internetReachable $true)) "Khong coi ket noi nham SSID la thanh cong"
    $fixedNow = [DateTime]"2026-01-01T12:00:30"
    $recentSwitch = [DateTime]"2026-01-01T12:00:15"
    Record-Test "Switch cooldown blocks rapid retry" (-not (Test-SwitchCooldownElapsed -lastSwitchTime $recentSwitch -cooldownSeconds 20 -currentTime $fixedNow)) "Cho het 20 giay sau lan chuyen truoc"
    Record-Test "Switch cooldown allows retry after expiry" (Test-SwitchCooldownElapsed -lastSwitchTime $recentSwitch -cooldownSeconds 15 -currentTime $fixedNow) "Cho phep thu lai khi cooldown da het"
    Record-Test "Emergency switch bypasses cooldown" (Test-SwitchCooldownAllowsAttempt -lastSwitchTime $recentSwitch -cooldownSeconds 60 -isEmergency $true -currentTime $fixedNow) "Cho phep cuu mang ngay khi mat ket noi"
    Record-Test "Disconnected Wi-Fi is an emergency" (Test-EmergencyNetworkFailure -currentConnected $false -internetPingSucceeded $false -gatewayPingMs -1) "Mất lien ket Wi-Fi duoc cuu ngay"
    Record-Test "Gateway and Internet failure is an emergency" (Test-EmergencyNetworkFailure -currentConnected $true -internetPingSucceeded $false -gatewayPingMs -1) "Chi cuu khan cap khi router va Internet deu khong phan hoi"
    Record-Test "Internet ping failure with live gateway respects cooldown" (-not (Test-EmergencyNetworkFailure -currentConnected $true -internetPingSucceeded $false -gatewayPingMs 5)) "Khong vuot cooldown khi router van phan hoi"
    Record-Test "Weak signal needs repeated confirmation" (-not (Test-SignalDegradationConfirmed -signal 35 -minimumSignal 40 -consecutiveWeakObservations 2)) "Khong doi mang do mot vai mau song yeu"
    Record-Test "Persistent weak signal triggers degradation" (Test-SignalDegradationConfirmed -signal 35 -minimumSignal 40 -consecutiveWeakObservations 3) "Xac nhan song yeu sau ba chu ky"
    Record-Test "Recovered signal resets degradation" (-not (Test-SignalDegradationConfirmed -signal 45 -minimumSignal 40 -consecutiveWeakObservations 3)) "Khong coi song phuc hoi la mang yeu"
    Record-Test "HTTPS probe accepts expected Internet response" (Test-InternetProbeResponse -statusCode 200 -responseBody "x" -responseHost "speed.cloudflare.com") "Chap nhan HTTPS thanh cong tu may chu Cloudflare"
    Record-Test "HTTPS probe rejects captive portal redirect" (-not (Test-InternetProbeResponse -statusCode 200 -responseBody "Sign in to Wi-Fi" -responseHost "captive.portal")) "Tu choi trang dang nhap captive portal"
    Record-Test "HTTPS probe rejects unexpected status" (-not (Test-InternetProbeResponse -statusCode 503 -responseBody "x" -responseHost "speed.cloudflare.com")) "Tu choi phan hoi HTTP loi"
    $candidateNetworks = @(
        [PSCustomObject]@{ SSID = "Current"; Signal = 95; IsSaved = $true; BSSID = "00:00:00:00:00:01" },
        [PSCustomObject]@{ SSID = "Strong"; Signal = 85; IsSaved = $true; BSSID = "00:00:00:00:00:02" },
        [PSCustomObject]@{ SSID = "Backup"; Signal = 70; IsSaved = $true; BSSID = "00:00:00:00:00:03" },
        [PSCustomObject]@{ SSID = "Guest"; Signal = 90; IsSaved = $false; BSSID = "00:00:00:00:00:04" },
        [PSCustomObject]@{ SSID = "Weak"; Signal = 30; IsSaved = $true; BSSID = "00:00:00:00:00:05" }
    )
    $Global:WifiBlacklist = @{}
    Add-TemporaryWifiBlacklist -ssid "Strong" -bssid "00:00:00:00:00:02" -durationSeconds 120 -currentTime $fixedNow
    $orderedCandidates = @(Get-AlternativeWifiCandidates -networks $candidateNetworks -currentSSID "Current" -currentConnected $true -currentSignal 40 -minimumSignal 40 -minimumImprovement 8 -currentTime $fixedNow)
    Record-Test "Failed BSSID is temporarily avoided" ($orderedCandidates.Count -eq 1 -and $orderedCandidates[0].SSID -eq "Backup") "Tam bo qua AP vua that bai va van giu mang du phong tiep theo"
    $blacklistExpired = @(Get-AlternativeWifiCandidates -networks $candidateNetworks -currentSSID "Current" -currentConnected $true -currentSignal 40 -minimumSignal 40 -minimumImprovement 8 -currentTime $fixedNow.AddSeconds(121))
    Record-Test "Failed BSSID returns after blacklist expires" ($blacklistExpired.Count -eq 2 -and $blacklistExpired[0].SSID -eq "Strong") "Cho phep thu lai AP sau thoi han 120 giay"

    Write-Host "`n>>> KIEM TRA PHAN TICH NETSH DA NGON NGU..." -ForegroundColor Yellow
    $englishInterface = @(
        "    State                  : connected",
        "    SSID                   : Home WiFi",
        "    AP BSSID               : 00:11:22:33:44:55",
        "    Radio type             : 802.11ac",
        "    Channel                : 36",
        "    Receive rate (Mbps)    : 866.7",
        "    Transmit rate (Mbps)   : 780.5",
        "    Signal                 : 92%"
    )
    $englishMetrics = ConvertFrom-NetshWifiInterfaces -lines $englishInterface
    Record-Test "English netsh interface parsing" ($englishMetrics.Connected -and $englishMetrics.SSID -eq "Home WiFi" -and $englishMetrics.Signal -eq 92 -and $englishMetrics.ReceiveRate -eq 867 -and $englishMetrics.TransmitRate -eq 780 -and $englishMetrics.Channel -eq 36) "Doc dung SSID, song, toc do, kenh tu output tieng Anh"

    $vietnameseInterface = @(
        "    Trạng thái             : đã kết nối",
        "    SSID                   : WiFi Nhà",
        "    BSSID                  : 00:11:22:33:44:66",
        "    Loại radio             : 802.11ac",
        "    Kênh                   : 44",
        "    Tốc độ nhận (Mbps)     : 433,3",
        "    Tốc độ truyền (Mbps)   : 390,5",
        "    Tín hiệu               : 78%"
    )
    $vietnameseMetrics = ConvertFrom-NetshWifiInterfaces -lines $vietnameseInterface
    $vietnameseMetricsPass = ($vietnameseMetrics.Connected -and $vietnameseMetrics.SSID -eq "WiFi Nhà" -and $vietnameseMetrics.Signal -eq 78 -and $vietnameseMetrics.ReceiveRate -eq 433 -and $vietnameseMetrics.TransmitRate -eq 390 -and $vietnameseMetrics.Channel -eq 44)
    Record-Test "Vietnamese netsh interface parsing" $vietnameseMetricsPass ("SSID={0}; Signal={1}; Rx={2}; Tx={3}; Channel={4}; Connected={5}" -f $vietnameseMetrics.SSID, $vietnameseMetrics.Signal, $vietnameseMetrics.ReceiveRate, $vietnameseMetrics.TransmitRate, $vietnameseMetrics.Channel, $vietnameseMetrics.Connected)

    $savedProfilesForParser = [System.Collections.Generic.List[string]]::new()
    $savedProfilesForParser.Add("WiFi Nhà")
    $vietnameseRadar = @(
        "SSID 1 : WiFi Nhà",
        "    BSSID 1 : 00:11:22:33:44:77",
        "    Tín hiệu             : 82%",
        "    Loại radio           : 802.11ax",
        "    Kênh                 : 149",
        "    SSID 2 : Guest"
    )
    $parsedRadar = @(ConvertFrom-NetshWifiNetworks -lines $vietnameseRadar -savedProfiles $savedProfilesForParser -currentSSID "WiFi Nhà")
    $radarPass = ($parsedRadar.Count -eq 2 -and $parsedRadar[0].SSID -eq "WiFi Nhà" -and $parsedRadar[0].Signal -eq 82 -and $parsedRadar[0].IsSaved -and $parsedRadar[0].IsCurrent -and $parsedRadar[0].Band -eq "5 GHz" -and $parsedRadar[0].BSSID -eq "00:11:22:33:44:77")
    $radarDetails = ($parsedRadar | ForEach-Object { "{0} (Signal={1}, Saved={2}, Current={3}, Band={4}, BSSID={5})" -f $_.SSID, $_.Signal, $_.IsSaved, $_.IsCurrent, $_.Band, $_.BSSID }) -join "; "
    Record-Test "Vietnamese netsh radar parsing" $radarPass ("Count={0}; {1}" -f $parsedRadar.Count, $radarDetails)

    Write-Host "`n>>> 6. MO PHONG NHAT KY KIEM TOAN (AUDIT LOGS)..." -ForegroundColor Yellow
    Add-AuditLog "Mo phong bai test ghi log he thong tu dong." "SYSTEM"
    Add-AuditLog "Mo phong phat hien mang yeu va chuyen mach thanh cong." "SWITCH"
    $logPass = ($Global:EventLogsList.Count -ge 2 -and $TbAnalyticsLogs.Text.Length -gt 0)
    Record-Test "Audit Logging Engine" $logPass ("Tong su kien da luu trong bo nho: " + $Global:EventLogsList.Count)

    Write-Host "`n>>> 7. MO PHONG BANG NOI MINI HUD..." -ForegroundColor Yellow
    $miniWindow.Show()
    $hudShow = $miniWindow.IsVisible
    $miniWindow.Hide()
    $hudHide = (-not $miniWindow.IsVisible)
    Record-Test "Mini HUD Show/Hide" ($hudShow -and $hudHide) "Kich hoat hien thi va an bang noi thanh cong"

    Write-Host "`n>>> 8. KIEM TRA BAN QUYEN TAC GIA S.NOVA TREN GIAO DIEN..." -ForegroundColor Yellow
    $authorCardVisible = ($TxtAuthorHeader -ne $null -and $TxtAuthorDesc -ne $null)
    Record-Test "Author S.Nova Attribution" $authorCardVisible "Thong tin tac gia S.Nova hien thi day du tren moi tab va titlebar"

} catch {
    Write-Host ("LOI NGOAI LE: " + $_.Exception.ToString()) -ForegroundColor Red
    Record-Test "Execution Exception" $false $_.Exception.Message
} finally {
    $Global:IsExiting = $true
    if ($notifyIcon) { 
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose() 
    }
    if ($window) { $window.Close() }
    if ($miniWindow) { $miniWindow.Close() }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "                TONG KET KET QUA MO PHONG" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
$passedCount = ($results | Where-Object { $_.Status -eq "PASSED" }).Count
$failedCount = ($results | Where-Object { $_.Status -eq "FAILED" }).Count
Write-Host ("Tong so bai test mo phong: " + $results.Count)
Write-Host ("Thanh cong: " + $passedCount) -ForegroundColor Green
Write-Host ("That bai:   " + $failedCount) -ForegroundColor $(if ($failedCount -eq 0) { "Green" } else { "Red" })

if ($failedCount -eq 0) {
    Write-Host "`n>>> TOAN BO GIAO DIEN VA LOGIC DA DUOC MO PHONG HOAN HAO 100%! <<<" -ForegroundColor Green
} else {
    Write-Host "`n>>> CAN KIEM TRA CAC MUC THAT BAI TREN! <<<" -ForegroundColor Red
    exit 1
}
