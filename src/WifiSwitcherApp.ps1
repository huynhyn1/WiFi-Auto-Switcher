<#
    ==========================================================================
    WIFI AUTO SWITCHER PRO - ENTERPRISE COMMERCIAL EDITION v2.5
    Hệ thống Tự Động 100% Giám Sát & Chuyển Đổi Wi-Fi Thông Minh Trên Windows
    Bản quyền thương mại / Zero-Dependency Portable Suite
    Mã hóa: UTF-8 with BOM (Hiển thị 100% phông chữ tiếng Việt chuẩn Segoe UI)
    ==========================================================================
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir -and $MyInvocation -and $MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
    try { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path } catch { }
}
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path }
$ConfigFile = Join-Path $ScriptDir "config.json"
$LogExportFile = Join-Path $ScriptDir "BaoCao-SuKien-WiFi.csv"

# ==================== CẤU HÌNH MẶC ĐỊNH CHUẨN THƯƠNG MẠI ====================
$DefaultConfig = [PSCustomObject]@{
    Language                = "vi"         # "vi" or "en"
    AutoSwitchEnabled       = $true
    ActiveProfile           = "Standard"   # "Gaming", "Standard", "Saving", "Custom"
    MaxPingMs               = 150
    MinSpeedMbps            = 2.0
    MinSignalPercent        = 40
    MaxPacketLossPercent    = 25
    CheckIntervalSeconds    = 6
    CooldownSeconds         = 20
    MinSignalImprovement    = 8
    TargetPingHost          = "8.8.8.8"
    SpeedTestUrl            = "https://speed.cloudflare.com/__down?bytes=524288"
    ShowNotifications       = $true
    ShowMiniWidget          = $true
    AutoStartWithWindows    = $true
    MinimizeToTrayOnClose   = $true
    PlaySoundOnSwitch       = $true
    TotalSwitchesCount      = 0
    MiniWidgetX             = -1
    MiniWidgetY             = -1
}

# Tải cấu hình từ config.json
$Global:Config = $DefaultConfig
if (Test-Path $ConfigFile) {
    try {
        $loaded = Get-Content -Path $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in $DefaultConfig.PSObject.Properties) {
            if ($null -ne $loaded.($prop.Name)) {
                $Global:Config.($prop.Name) = $loaded.($prop.Name)
            }
        }
    } catch {
        $Global:Config = $DefaultConfig
    }
} else {
    $Global:Config | ConvertTo-Json -Depth 4 | Set-Content -Path $ConfigFile -Encoding UTF8
}

# Đăng ký tự khởi động cùng Windows
$RegRunPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RegRunName = "WiFiAutoSwitcherPro"
$ExeTarget = Join-Path $ScriptDir "WiFiAutoSwitcher.exe"
$OldStartupLnk = Join-Path ([Environment]::GetFolderPath("Startup")) "WiFiAutoSwitcherPro.lnk"

function Set-StartupRegistry ([bool]$enable) {
    try {
        if (Test-Path $OldStartupLnk) { Remove-Item $OldStartupLnk -Force -ErrorAction SilentlyContinue }
        if ($enable) {
            if (Test-Path $ExeTarget) {
                Set-ItemProperty -Path $RegRunPath -Name $RegRunName -Value "`"$ExeTarget`" --minimized" -Force
            }
        } else {
            Remove-ItemProperty -Path $RegRunPath -Name $RegRunName -ErrorAction SilentlyContinue
        }
    } catch { }
}
Set-StartupRegistry ($Global:Config.AutoStartWithWindows)

# Biến trạng thái hoạt động toàn cục
$Global:IsAutoSwitchRunning = $Global:Config.AutoSwitchEnabled
$Global:IsCheckingNow       = $false
$Global:LastSwitchTime      = [DateTime]::MinValue
$Global:ConsecutiveFails    = 0
$Global:StartTime           = [DateTime]::Now
$Global:PingHistory         = [System.Collections.Generic.List[int]]::new()
$Global:EventLogsList       = [System.Collections.Generic.List[PSCustomObject]]::new()
$Global:DetectedGateway     = "192.168.1.1"

# ==================== GIAO DIỆN XAML THƯƠNG MẠI PRO V2.5 ====================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WiFi Auto Switcher Pro Enterprise"
        Height="720" Width="1060"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None"
        AllowsTransparency="False"
        Background="#080C14"
        Foreground="#E2E8F0"
        FontFamily="Segoe UI, Tahoma, Helvetica, sans-serif"
        TextOptions.TextFormattingMode="Display"
        TextOptions.TextRenderingMode="ClearType"
        ResizeMode="CanResizeWithGrip">

    <Window.Resources>
        <!-- Card Style -->
        <Style x:Key="ProCard" TargetType="Border">
            <Setter Property="Background" Value="#111827"/>
            <Setter Property="CornerRadius" Value="14"/>
            <Setter Property="BorderBrush" Value="#1F293D"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="18"/>
            <Setter Property="Margin" Value="0,0,0,14"/>
        </Style>

        <!-- KPI Mini Card -->
        <Style x:Key="KpiCard" TargetType="Border">
            <Setter Property="Background" Value="#0F172A"/>
            <Setter Property="CornerRadius" Value="12"/>
            <Setter Property="BorderBrush" Value="#1E293B"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="14,12"/>
        </Style>

        <!-- Primary Action Button (Gradient Cyan-Blue) -->
        <Style x:Key="ProBtnPrimary" TargetType="Button">
            <Setter Property="Background" Value="#2563EB"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="9" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#1D4ED8"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Secondary Button -->
        <Style x:Key="ProBtnSecondary" TargetType="Button">
            <Setter Property="Background" Value="#1E293B"/>
            <Setter Property="Foreground" Value="#CBD5E1"/>
            <Setter Property="FontWeight" Value="Medium"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="14,7"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#334155"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#2D3B52"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Sidebar Navigation Button -->
        <Style x:Key="NavTabBtn" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#94A3B8"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="14,10"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Margin" Value="0,2"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#141E30"/>
                    <Setter Property="Foreground" Value="#F8FAFC"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Modern Input TextBox -->
        <Style x:Key="ModernInputBox" TargetType="TextBox">
            <Setter Property="Background" Value="#0A0E17"/>
            <Setter Property="Foreground" Value="#F8FAFC"/>
            <Setter Property="BorderBrush" Value="#2A364F"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,5"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
                            <ScrollViewer x:Name="PART_ContentHost"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Modern CheckBox -->
        <Style x:Key="ProCheckBox" TargetType="CheckBox">
            <Setter Property="Foreground" Value="#E2E8F0"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>
    </Window.Resources>

    <!-- WINDOW CONTAINER WITH CUSTOM TITLEBAR & BORDER -->
    <Border BorderBrush="#1E293B" BorderThickness="1" CornerRadius="0">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="46"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <!-- ==================== HEADER / CUSTOM TITLEBAR ==================== -->
            <Grid Grid.Row="0" x:Name="CustomTitleBar" Background="#0C1322" Cursor="Arrow">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <!-- Brand & Logo -->
                <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0,0,0">
                    <Border Width="28" Height="28" CornerRadius="7" Background="#1D4ED8" Margin="0,0,10,0">
                        <TextBlock Text="⚡" FontSize="14" HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#FFFFFF"/>
                    </Border>
                    <TextBlock Text="WiFi Auto Switcher Pro" FontWeight="Bold" FontSize="14" Foreground="#F8FAFC" VerticalAlignment="Center"/>
                    <Border Background="#1E3A8A" CornerRadius="6" Padding="7,2" Margin="10,0,0,0" VerticalAlignment="Center">
                        <TextBlock Text="by S.Nova" FontSize="10" FontWeight="Bold" Foreground="#38BDF8"/>
                    </Border>
                </StackPanel>

                <!-- Center Active Protection Pill -->
                <StackPanel Grid.Column="1" HorizontalAlignment="Center" VerticalAlignment="Center" Orientation="Horizontal">
                    <Border x:Name="TitleStatusPill" CornerRadius="12" Padding="12,3" Background="#064E3B">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <Ellipse x:Name="TitleStatusDot" Width="7" Height="7" Fill="#34D399" Margin="0,0,6,0"/>
                            <TextBlock x:Name="TitleStatusText" Text="ĐANG BẢO VỆ MẠNG 24/7" FontSize="11" FontWeight="Bold" Foreground="#34D399"/>
                        </StackPanel>
                    </Border>
                </StackPanel>

                <!-- Titlebar Window Controls -->
                <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,8,0">
                    <Button x:Name="BtnTitleLang" Style="{StaticResource ProBtnSecondary}" Content="🌐 VI" Padding="8,4" Margin="0,0,8,0" FontSize="11" ToolTip="Chuyển Đổi Ngôn Ngữ / Switch Language (Tiếng Việt / English)"/>
                    <Button x:Name="BtnTitleMiniHUD" Style="{StaticResource ProBtnSecondary}" Content="📌 Bảng Nhỏ (HUD)" Padding="10,4" Margin="0,0,8,0" FontSize="11"/>
                    <Button x:Name="BtnTitleMinimize" Width="38" Height="32" Background="Transparent" BorderThickness="0" Foreground="#94A3B8" Content="—" FontSize="12" FontWeight="Bold" Cursor="Hand"/>
                    <Button x:Name="BtnTitleClose" Width="38" Height="32" Background="Transparent" BorderThickness="0" Foreground="#94A3B8" Content="✕" FontSize="12" FontWeight="Bold" Cursor="Hand"/>
                </StackPanel>
            </Grid>

            <!-- ==================== MAIN BODY: SIDEBAR + CONTENT ==================== -->
            <Grid Grid.Row="1">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="230"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- LEFT SIDEBAR -->
                <Border Grid.Column="0" Background="#0A101D" BorderBrush="#162032" BorderThickness="0,0,1,0" Padding="14,16">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Navigation Section -->
                        <StackPanel Grid.Row="0">
                            <TextBlock x:Name="TxtNavMenuHeader" Text="MENU QUẢN TRỊ" FontSize="11" FontWeight="Bold" Foreground="#64748B" Margin="8,0,0,10"/>
                            
                            <Button x:Name="BtnNavDashboard" Style="{StaticResource NavTabBtn}" Background="#1E293B" Foreground="#38BDF8">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="📊" Margin="0,0,10,0"/>
                                    <TextBlock x:Name="TxtNavDashboard" Text="Tổng Quan"/>
                                </StackPanel>
                            </Button>

                            <Button x:Name="BtnNavSmartSwitch" Style="{StaticResource NavTabBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="⚡" Margin="0,0,10,0"/>
                                    <TextBlock x:Name="TxtNavSmartSwitch" Text="Tự Động Đổi"/>
                                </StackPanel>
                            </Button>

                            <Button x:Name="BtnNavRadar" Style="{StaticResource NavTabBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="📶" Margin="0,0,10,0"/>
                                    <TextBlock x:Name="TxtNavRadar" Text="Radar Quét Sóng"/>
                                </StackPanel>
                            </Button>

                            <Button x:Name="BtnNavAnalytics" Style="{StaticResource NavTabBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="📈" Margin="0,0,10,0"/>
                                    <TextBlock x:Name="TxtNavAnalytics" Text="Nhật Ký &amp; Sự Kiện"/>
                                </StackPanel>
                            </Button>

                            <Button x:Name="BtnNavSettings" Style="{StaticResource NavTabBtn}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="⚙️" Margin="0,0,10,0"/>
                                    <TextBlock x:Name="TxtNavSettings" Text="Cài Đặt Hệ Thống"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>

                        <!-- Bottom Sidebar: Quick Toggle & Statistics -->
                        <Border Grid.Row="2" Background="#111827" CornerRadius="12" Padding="12" BorderBrush="#1F293D" BorderThickness="1">
                            <StackPanel>
                                <TextBlock x:Name="TxtSidebarHeader" Text="BẢO VỆ TỰ ĐỘNG" FontSize="10" FontWeight="Bold" Foreground="#64748B" Margin="0,0,0,6"/>
                                <Button x:Name="BtnQuickToggleAuto" Style="{StaticResource ProBtnPrimary}" Content="Tắt Tự Động" Padding="0,7" FontSize="12" Margin="0,0,0,10"/>
                                <Grid Margin="0,2">
                                    <TextBlock x:Name="TxtSidebarSwitchesLabel" Text="Lần tự đổi mạng:" FontSize="11" Foreground="#94A3B8"/>
                                    <TextBlock x:Name="TxtSidebarSwitches" Text="0 lần" FontSize="11" FontWeight="Bold" Foreground="#38BDF8" HorizontalAlignment="Right"/>
                                </Grid>
                                <Grid Margin="0,2">
                                    <TextBlock x:Name="TxtSidebarUptimeLabel" Text="Thời gian chạy:" FontSize="11" Foreground="#94A3B8"/>
                                    <TextBlock x:Name="TxtSidebarUptime" Text="00:00" FontSize="11" FontWeight="Bold" Foreground="#34D399" HorizontalAlignment="Right"/>
                                </Grid>
                                <Border BorderBrush="#1E293B" BorderThickness="0,1,0,0" Margin="0,8,0,6"/>
                                <TextBlock Text="Tác giả: S.Nova • v2.5" FontSize="10" Foreground="#64748B" HorizontalAlignment="Center"/>
                            </StackPanel>
                        </Border>
                    </Grid>
                </Border>

                <!-- RIGHT CONTENT AREA (TAB PANELS) -->
                <Grid Grid.Column="1" Margin="20,16">

                    <!-- ==================== TAB 1: DASHBOARD (TỔNG QUAN) ==================== -->
                    <Grid x:Name="PanelDashboard" Visibility="Visible">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <!-- TOP BANNER: HEALTH SCORE WIDGET -->
                        <Border Grid.Row="0" Style="{StaticResource ProCard}" Background="#0F172A" Padding="16,14">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>

                                <!-- Score Circle -->
                                <Border Grid.Column="0" Width="58" Height="58" CornerRadius="29" Background="#022C22" BorderBrush="#10B981" BorderThickness="2" Margin="0,0,16,0">
                                    <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                                        <TextBlock x:Name="TxtHealthScore" Text="98" FontSize="20" FontWeight="Bold" Foreground="#34D399" HorizontalAlignment="Center"/>
                                        <TextBlock Text="/100" FontSize="9" Foreground="#6EE7B7" HorizontalAlignment="Center"/>
                                    </StackPanel>
                                </Border>

                                <!-- Assessment Text -->
                                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                    <StackPanel Orientation="Horizontal" Margin="0,0,0,3">
                                        <TextBlock Text="CHỈ SỐ SỨC KHỎE MẠNG: " FontSize="12" FontWeight="Bold" Foreground="#94A3B8"/>
                                        <TextBlock x:Name="TxtHealthRating" Text="HOÀN HẢO &amp; ỔN ĐỊNH CAO" FontSize="12" FontWeight="Bold" Foreground="#34D399"/>
                                    </StackPanel>
                                    <TextBlock x:Name="TxtHealthDesc" Text="Đường truyền Internet tối ưu, độ trễ cực thấp, không phát hiện mất gói tin." FontSize="12" Foreground="#64748B"/>
                                </StackPanel>

                                <!-- Quick Test Button -->
                                <Button Grid.Column="2" x:Name="BtnDashboardTestNow" Style="{StaticResource ProBtnSecondary}" Content="⚡ Đo Kiểm Tra Ngay" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>

                        <!-- 3 REALTIME METRICS CARDS -->
                        <Grid Grid.Row="1">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="1.15*"/>
                                <ColumnDefinition Width="1*"/>
                                <ColumnDefinition Width="1*"/>
                            </Grid.ColumnDefinitions>

                            <!-- CARD 1: WI-FI HIỆN TẠI -->
                            <Border Grid.Column="0" Style="{StaticResource ProCard}" Margin="0,0,12,14">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>
                                    <StackPanel Orientation="Horizontal" Margin="0,0,0,8">
                                        <TextBlock Text="WI-FI HIỆN TẠI" FontSize="11" FontWeight="Bold" Foreground="#60A5FA"/>
                                        <TextBlock x:Name="TxtWifiBand" Text="[5 GHz]" FontSize="11" FontWeight="Bold" Foreground="#38BDF8" Margin="8,0,0,0"/>
                                    </StackPanel>
                                    <TextBlock Grid.Row="1" x:Name="TxtWifiSSID" Text="Đang dò tìm..." FontSize="18" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,8"/>
                                    <Grid Grid.Row="2" Margin="0,0,0,8">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <ProgressBar x:Name="PbSignal" Height="8" Minimum="0" Maximum="100" Value="85" Background="#1E293B" Foreground="#10B981"/>
                                        <TextBlock Grid.Column="1" x:Name="TxtSignalVal" Text="85%" FontWeight="Bold" FontSize="12" Foreground="#10B981" Margin="10,0,0,0"/>
                                    </Grid>
                                    <TextBlock Grid.Row="3" x:Name="TxtWifiDetails" Text="RX: -- Mbps | AP: -- | Kênh: --" FontSize="11" Foreground="#64748B"/>
                                </Grid>
                            </Border>

                            <!-- CARD 2: ĐỘ TRỄ KÉP (GATEWAY & INTERNET) -->
                            <Border Grid.Column="1" Style="{StaticResource ProCard}" Margin="0,0,12,14">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>
                                    <TextBlock Text="ĐỘ TRỄ (PING) &amp; GÓI TIN" FontSize="11" FontWeight="Bold" Foreground="#F59E0B" Margin="0,0,0,8"/>
                                    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,8">
                                        <TextBlock x:Name="TxtPingVal" Text="-- ms" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>
                                        <Border x:Name="BadgePingStatus" CornerRadius="8" Padding="8,2" Background="#064E3B" Margin="10,0,0,0" VerticalAlignment="Center">
                                            <TextBlock x:Name="TxtPingQuality" Text="RẤT TỐT" FontSize="10" FontWeight="Bold" Foreground="#34D399"/>
                                        </Border>
                                    </StackPanel>
                                    <Grid Grid.Row="2" Margin="0,0,0,4">
                                        <TextBlock x:Name="TxtPingGateway" Text="Router LAN: -- ms" FontSize="11" Foreground="#94A3B8"/>
                                        <TextBlock x:Name="TxtPacketLoss" Text="Mất gói: 0%" FontSize="11" Foreground="#94A3B8" HorizontalAlignment="Right"/>
                                    </Grid>
                                    <TextBlock Grid.Row="3" Text="Máy chủ DNS: 8.8.8.8 (Google)" FontSize="11" Foreground="#64748B"/>
                                </Grid>
                            </Border>

                            <!-- CARD 3: TỐC ĐỘ BĂNG THÔNG -->
                            <Border Grid.Column="2" Style="{StaticResource ProCard}">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>
                                    <TextBlock Text="TỐC ĐỘ TẢI THỰC TẾ" FontSize="11" FontWeight="Bold" Foreground="#A78BFA" Margin="0,0,0,8"/>
                                    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,8">
                                        <TextBlock x:Name="TxtSpeedVal" Text="-- Mbps" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>
                                    </StackPanel>
                                    <TextBlock Grid.Row="2" x:Name="TxtSpeedStatus" Text="Đang cập nhật..." FontSize="12" Foreground="#34D399" Margin="0,0,0,4"/>
                                    <TextBlock Grid.Row="3" Text="Máy chủ test: Cloudflare Edge" FontSize="11" Foreground="#64748B"/>
                                </Grid>
                            </Border>
                        </Grid>

                        <!-- PING SPARKLINE HISTORY & LIVE EVENT SNIPPET -->
                        <Border Grid.Row="2" Style="{StaticResource ProCard}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <Grid Grid.Row="0" Margin="0,0,0,12">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <TextBlock Text="BIỂU ĐỒ ĐỘ TRỄ THỜI GIAN THỰC (LỊCH SỬ 16 LẦN GẦN NHẤT)" FontSize="12" FontWeight="Bold" Foreground="#38BDF8"/>
                                    </StackPanel>
                                    <TextBlock x:Name="TxtDashboardLastChecked" Text="Cập nhật: Chưa" FontSize="11" Foreground="#64748B" HorizontalAlignment="Right"/>
                                </Grid>
                                
                                <!-- Sparkline Bar Visualization -->
                                <Grid Grid.Row="1" Height="100">
                                    <StackPanel x:Name="SparklinePanel" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Bottom">
                                        <!-- Bars will be dynamically populated/updated -->
                                    </StackPanel>
                                </Grid>
                            </Grid>
                        </Border>
                    </Grid>

                    <!-- ==================== TAB 2: SMART SWITCH (BỘ TỰ ĐỘNG ĐỔI MẠNG) ==================== -->
                    <Grid x:Name="PanelSmartSwitch" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <!-- PROFILES PRESET CARDS -->
                        <Border Grid.Row="0" Style="{StaticResource ProCard}">
                            <StackPanel>
                                <TextBlock Text="CHẾ ĐỘ TỐI ƯU HÓA NHANH (PROFILES)" FontSize="13" FontWeight="Bold" Foreground="#38BDF8" Margin="0,0,0,10"/>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <!-- Profile 1: Gaming / Họp -->
                                    <Border Grid.Column="0" x:Name="CardProfileGaming" Style="{StaticResource KpiCard}" Margin="0,0,10,0" Cursor="Hand">
                                        <StackPanel>
                                            <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                                                <TextBlock Text="🎮" FontSize="14" Margin="0,0,6,0"/>
                                                <TextBlock Text="Gaming / Livestream" FontWeight="Bold" FontSize="13" Foreground="#F8FAFC"/>
                                            </StackPanel>
                                            <TextBlock Text="Đổi mạng siêu nhạy: Ping &gt; 80ms hoặc Mất gói &gt; 5%." FontSize="11" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,8"/>
                                            <Button x:Name="BtnApplyProfileGaming" Style="{StaticResource ProBtnSecondary}" Content="Kích Hoạt" Padding="8,4" FontSize="11"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Profile 2: Làm việc / Tiêu chuẩn -->
                                    <Border Grid.Column="1" x:Name="CardProfileStandard" Style="{StaticResource KpiCard}" Margin="0,0,10,0" BorderBrush="#3B82F6" Cursor="Hand">
                                        <StackPanel>
                                            <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                                                <TextBlock Text="🌐" FontSize="14" Margin="0,0,6,0"/>
                                                <TextBlock Text="Văn Phòng &amp; Phim Ảnh" FontWeight="Bold" FontSize="13" Foreground="#F8FAFC"/>
                                            </StackPanel>
                                            <TextBlock Text="Cân bằng tối ưu: Ping &gt; 150ms hoặc Sóng &lt; 40%." FontSize="11" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,8"/>
                                            <Button x:Name="BtnApplyProfileStandard" Style="{StaticResource ProBtnPrimary}" Content="[Đang Chọn]" Padding="8,4" FontSize="11"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Profile 3: Tiết kiệm / Ổn định -->
                                    <Border Grid.Column="2" x:Name="CardProfileSaving" Style="{StaticResource KpiCard}" Cursor="Hand">
                                        <StackPanel>
                                            <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                                                <TextBlock Text="🔋" FontSize="14" Margin="0,0,6,0"/>
                                                <TextBlock Text="Tiết Kiệm &amp; Ổn Định" FontWeight="Bold" FontSize="13" Foreground="#F8FAFC"/>
                                            </StackPanel>
                                            <TextBlock Text="Hạn chế đổi: Chỉ đổi khi mất kết nối hoặc Sóng &lt; 25%." FontSize="11" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,8"/>
                                            <Button x:Name="BtnApplyProfileSaving" Style="{StaticResource ProBtnSecondary}" Content="Kích Hoạt" Padding="8,4" FontSize="11"/>
                                        </StackPanel>
                                    </Border>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <!-- CUSTOM CRITERIA FORM -->
                        <Border Grid.Row="1" Style="{StaticResource ProCard}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>

                                <TextBlock Grid.Row="0" Text="TÙY CHỈNH THÔNG SỐ TỰ ĐỘNG CHUYỂN MẠNG" FontSize="13" FontWeight="Bold" Foreground="#34D399" Margin="0,0,0,16"/>

                                <Grid Grid.Row="1">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <!-- Column 1 -->
                                    <StackPanel Grid.Column="0" Margin="0,0,16,0">
                                        <TextBlock Text="1. Ngưỡng độ trễ tối đa (Ping Ms):" FontSize="12" Foreground="#CBD5E1" Margin="0,0,0,4"/>
                                        <TextBox x:Name="TbMaxPing" Style="{StaticResource ModernInputBox}" Text="150" Margin="0,0,0,12"/>

                                        <TextBlock Text="2. Ngưỡng tốc độ tải tối thiểu (Mbps):" FontSize="12" Foreground="#CBD5E1" Margin="0,0,0,4"/>
                                        <TextBox x:Name="TbMinSpeed" Style="{StaticResource ModernInputBox}" Text="2.0" Margin="0,0,0,12"/>

                                        <TextBlock Text="3. Ngưỡng tín hiệu sóng tối thiểu (%):" FontSize="12" Foreground="#CBD5E1" Margin="0,0,0,4"/>
                                        <TextBox x:Name="TbMinSignal" Style="{StaticResource ModernInputBox}" Text="40" Margin="0,0,0,12"/>
                                    </StackPanel>

                                    <!-- Column 2 -->
                                    <StackPanel Grid.Column="1" Margin="16,0,0,0">
                                        <TextBlock Text="4. Tỷ lệ mất gói tin tối đa (%):" FontSize="12" Foreground="#CBD5E1" Margin="0,0,0,4"/>
                                        <TextBox x:Name="TbMaxLoss" Style="{StaticResource ModernInputBox}" Text="25" Margin="0,0,0,12"/>

                                        <TextBlock Text="5. Chu kỳ quét kiểm tra mạng (giây):" FontSize="12" Foreground="#CBD5E1" Margin="0,0,0,4"/>
                                        <TextBox x:Name="TbInterval" Style="{StaticResource ModernInputBox}" Text="6" Margin="0,0,0,12"/>

                                        <TextBlock Text="6. Thời gian nghỉ chống nhảy mạng (Cooldown giây):" FontSize="12" Foreground="#CBD5E1" Margin="0,0,0,4"/>
                                        <TextBox x:Name="TbCooldown" Style="{StaticResource ModernInputBox}" Text="20" Margin="0,0,0,12"/>
                                    </StackPanel>
                                </Grid>

                                <Grid Grid.Row="2" Margin="0,16,0,0">
                                    <TextBlock Text="* Hệ thống chỉ tự động chuyển sang Wi-Fi đã từng kết nối thành công trên máy tính." FontSize="11" Foreground="#64748B" VerticalAlignment="Center"/>
                                    <Button x:Name="BtnSaveSmartCriteria" Style="{StaticResource ProBtnPrimary}" Content="💾 Lưu Cài Đặt Ngay" HorizontalAlignment="Right" Padding="18,8"/>
                                </Grid>
                            </Grid>
                        </Border>
                    </Grid>

                    <!-- ==================== TAB 3: RADAR (QUÉT SÓNG XUNG QUANH) ==================== -->
                    <Grid x:Name="PanelRadar" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <!-- Header Bar -->
                        <Grid Grid.Row="0" Margin="0,0,0,12">
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <TextBlock Text="RADAR QUÉT TOÀN BỘ SÓNG WI-FI XUNG QUANH" FontSize="13" FontWeight="Bold" Foreground="#38BDF8"/>
                                <TextBlock x:Name="TxtRadarTotalCount" Text="(Đang quét...)" FontSize="12" Foreground="#64748B" Margin="8,0,0,0" VerticalAlignment="Center"/>
                            </StackPanel>
                            <Button x:Name="BtnRadarRefresh" Style="{StaticResource ProBtnSecondary}" Content="🔄 Quét Lại Sóng Ngay" HorizontalAlignment="Right" Padding="12,5"/>
                        </Grid>

                        <!-- Radar ListView -->
                        <Border Grid.Row="1" Style="{StaticResource ProCard}">
                            <ListView x:Name="LvRadarNetworks" Background="Transparent" BorderThickness="0" Foreground="#E2E8F0" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                                <ListView.ItemContainerStyle>
                                    <Style TargetType="ListViewItem">
                                        <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
                                        <Setter Property="Margin" Value="0,3"/>
                                        <Setter Property="Padding" Value="6"/>
                                        <Setter Property="Background" Value="#101726"/>
                                        <Setter Property="Template">
                                            <Setter.Value>
                                                <ControlTemplate TargetType="ListViewItem">
                                                    <Border Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                                                        <ContentPresenter/>
                                                    </Border>
                                                </ControlTemplate>
                                            </Setter.Value>
                                        </Setter>
                                    </Style>
                                </ListView.ItemContainerStyle>
                                <ListView.ItemTemplate>
                                    <DataTemplate>
                                        <Grid Margin="6,3">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="110"/>
                                                <ColumnDefinition Width="90"/>
                                                <ColumnDefinition Width="100"/>
                                            </Grid.ColumnDefinitions>
                                            <!-- SSID & Details -->
                                            <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                                <StackPanel Orientation="Horizontal">
                                                    <TextBlock Text="{Binding SSID}" FontWeight="Bold" FontSize="14" Foreground="#F8FAFC"/>
                                                    <Border Background="#1E293B" CornerRadius="4" Padding="4,1" Margin="8,0,0,0">
                                                        <TextBlock Text="{Binding Band}" FontSize="10" Foreground="#94A3B8"/>
                                                    </Border>
                                                </StackPanel>
                                                <TextBlock Text="{Binding Details}" FontSize="11" Foreground="#64748B" Margin="0,2,0,0"/>
                                            </StackPanel>
                                            <!-- Status Badge -->
                                            <Border Grid.Column="1" CornerRadius="8" Padding="8,3" Background="{Binding BadgeBg}" VerticalAlignment="Center" HorizontalAlignment="Center">
                                                <TextBlock Text="{Binding StatusText}" FontSize="10" FontWeight="Bold" Foreground="{Binding BadgeFg}"/>
                                            </Border>
                                            <!-- Signal Strength -->
                                            <StackPanel Grid.Column="2" VerticalAlignment="Center" HorizontalAlignment="Center">
                                                <TextBlock Text="{Binding SignalText}" FontWeight="Bold" FontSize="13" Foreground="{Binding SignalColor}" HorizontalAlignment="Center"/>
                                                <ProgressBar Height="4" Width="60" Value="{Binding SignalVal}" Minimum="0" Maximum="100" Foreground="{Binding SignalColor}" Background="#1E293B" Margin="0,2,0,0"/>
                                            </StackPanel>
                                            <!-- Action Button -->
                                            <Button Grid.Column="3" Tag="{Binding SSID}" Style="{StaticResource ProBtnSecondary}" Content="Chuyển ngay" Padding="8,4" FontSize="11" HorizontalAlignment="Right"/>
                                        </Grid>
                                    </DataTemplate>
                                </ListView.ItemTemplate>
                            </ListView>
                        </Border>
                    </Grid>

                    <!-- ==================== TAB 4: ANALYTICS (NHẬT KÝ & SỰ KIỆN) ==================== -->
                    <Grid x:Name="PanelAnalytics" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <!-- 4 KPI SUMMARY CARDS -->
                        <Grid Grid.Row="0" Margin="0,0,0,14">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Border Grid.Column="0" Style="{StaticResource KpiCard}" Margin="0,0,8,0">
                                <StackPanel>
                                    <TextBlock Text="TỰ ĐỔI CỨU MẠNG" FontSize="10" FontWeight="Bold" Foreground="#64748B"/>
                                    <TextBlock x:Name="TxtKpiSwitches" Text="0 lần" FontSize="18" FontWeight="Bold" Foreground="#38BDF8" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>
                            <Border Grid.Column="1" Style="{StaticResource KpiCard}" Margin="0,0,8,0">
                                <StackPanel>
                                    <TextBlock Text="ĐỘ TRỄ TRUNG BÌNH" FontSize="10" FontWeight="Bold" Foreground="#64748B"/>
                                    <TextBlock x:Name="TxtKpiAvgPing" Text="-- ms" FontSize="18" FontWeight="Bold" Foreground="#34D399" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>
                            <Border Grid.Column="2" Style="{StaticResource KpiCard}" Margin="0,0,8,0">
                                <StackPanel>
                                    <TextBlock Text="TỶ LỆ KẾT NỐI ONLINE" FontSize="10" FontWeight="Bold" Foreground="#64748B"/>
                                    <TextBlock x:Name="TxtKpiUptime" Text="99.9%" FontSize="18" FontWeight="Bold" Foreground="#F59E0B" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>
                            <Border Grid.Column="3" Style="{StaticResource KpiCard}">
                                <StackPanel>
                                    <TextBlock Text="MẠNG ĐANG BẢO VỆ" FontSize="10" FontWeight="Bold" Foreground="#64748B"/>
                                    <TextBlock x:Name="TxtKpiCurrentNet" Text="--" FontSize="15" FontWeight="Bold" Foreground="#A78BFA" Margin="0,4,0,0" TextTrimming="CharacterEllipsis"/>
                                </StackPanel>
                            </Border>
                        </Grid>

                        <!-- EVENT LOGS CONSOLE -->
                        <Border Grid.Row="1" Style="{StaticResource ProCard}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <Grid Grid.Row="0" Margin="0,0,0,10">
                                    <TextBlock Text="NHẬT KÝ HOẠT ĐỘNG THỜI GIAN THỰC (LIVE AUDIT LOGS)" FontSize="12" FontWeight="Bold" Foreground="#F43F5E"/>
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                        <Button x:Name="BtnExportLogs" Style="{StaticResource ProBtnSecondary}" Content="📥 Xuất Báo Cáo (CSV)" Padding="10,4" Margin="0,0,8,0" FontSize="11"/>
                                        <Button x:Name="BtnClearLogs" Style="{StaticResource ProBtnSecondary}" Content="Xóa Nhật Ký" Padding="10,4" FontSize="11"/>
                                    </StackPanel>
                                </Grid>
                                <TextBox Grid.Row="1" x:Name="TbAnalyticsLogs" IsReadOnly="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"
                                         TextWrapping="Wrap" Background="#070A10" Foreground="#94A3B8" BorderBrush="#1C2433" BorderThickness="1"
                                         FontFamily="Cascadia Code, Consolas, Courier New" FontSize="11" Padding="12"/>
                            </Grid>
                        </Border>
                    </Grid>

                    <!-- ==================== TAB 5: SETTINGS (CÀI ĐẶT HỆ THỐNG) ==================== -->
                    <Grid x:Name="PanelSettings" Visibility="Collapsed">
                        <Border Style="{StaticResource ProCard}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>

                                <TextBlock Grid.Row="0" x:Name="TxtSettingsHeader" Text="THIẾT LẬP NÂNG CAO CHO HỆ THỐNG" FontSize="14" FontWeight="Bold" Foreground="#38BDF8" Margin="0,0,0,16"/>

                                <StackPanel Grid.Row="1">
                                    <!-- Language Selector -->
                                    <Grid Margin="0,0,0,16">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="220"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock x:Name="TxtSettingsLangLabel" Text="Ngôn ngữ giao diện (Language):" FontSize="12" Foreground="#CBD5E1" VerticalAlignment="Center"/>
                                        <StackPanel Grid.Column="1" Orientation="Horizontal">
                                            <Button x:Name="BtnLangVi" Style="{StaticResource ProBtnPrimary}" Content="🇻🇳 Tiếng Việt" Padding="12,6" Margin="0,0,8,0" FontSize="12"/>
                                            <Button x:Name="BtnLangEn" Style="{StaticResource ProBtnSecondary}" Content="🇬🇧 English" Padding="12,6" FontSize="12"/>
                                        </StackPanel>
                                    </Grid>

                                    <Border BorderBrush="#1F293D" BorderThickness="0,1,0,0" Margin="0,0,0,16"/>

                                    <CheckBox x:Name="CbSettingsAutoStart" Style="{StaticResource ProCheckBox}" Content="Tự động khởi động ngầm cùng Windows (Khuyên dùng)" Margin="0,0,0,14"/>
                                    <CheckBox x:Name="CbSettingsMiniHUD" Style="{StaticResource ProCheckBox}" Content="Luôn hiển thị Bảng Nhỏ nổi trên màn hình (Mini HUD Desktop Widget)" Margin="0,0,0,14"/>
                                    <CheckBox x:Name="CbSettingsPlaySound" Style="{StaticResource ProCheckBox}" Content="Phát âm thanh thông báo tinh tế khi tự động chuyển mạng" Margin="0,0,0,14"/>
                                    <CheckBox x:Name="CbSettingsShowNotify" Style="{StaticResource ProCheckBox}" Content="Bật thông báo khay hệ thống (Windows Balloon Notification)" Margin="0,0,0,14"/>
                                    <CheckBox x:Name="CbSettingsMinimizeClose" Style="{StaticResource ProCheckBox}" Content="Khi bấm nút đóng (✕), tự động thu nhỏ xuống khay thay vì tắt tool" Margin="0,0,0,18"/>

                                    <Border BorderBrush="#1F293D" BorderThickness="0,1,0,0" Margin="0,0,0,16"/>

                                    <Grid Margin="0,0,0,12">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="220"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock x:Name="TxtSettingsPingHostLabel" Text="Máy chủ kiểm tra Ping (DNS):" FontSize="12" Foreground="#CBD5E1" VerticalAlignment="Center"/>
                                        <TextBox Grid.Column="1" x:Name="TbSettingsPingHost" Style="{StaticResource ModernInputBox}" Text="8.8.8.8"/>
                                    </Grid>

                                    <Grid Margin="0,0,0,16">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="220"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock x:Name="TxtSettingsSpeedUrlLabel" Text="Đường dẫn kiểm tra SpeedTest:" FontSize="12" Foreground="#CBD5E1" VerticalAlignment="Center"/>
                                        <TextBox Grid.Column="1" x:Name="TbSettingsSpeedUrl" Style="{StaticResource ModernInputBox}" Text="https://speed.cloudflare.com/__down?bytes=524288"/>
                                    </Grid>

                                    <!-- Author & App Info Card -->
                                    <Border Background="#0F172A" CornerRadius="10" Padding="14" BorderBrush="#1E293B" BorderThickness="1">
                                        <StackPanel>
                                            <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                                                <TextBlock x:Name="TxtAuthorHeader" Text="THÔNG TIN TÁC GIẢ &amp; PHIÊN BẢN" FontSize="11" FontWeight="Bold" Foreground="#38BDF8"/>
                                                <Border Background="#1E3A8A" CornerRadius="4" Padding="6,1" Margin="8,0,0,0">
                                                    <TextBlock Text="Tác giả: S.Nova" FontSize="10" FontWeight="Bold" Foreground="#60A5FA"/>
                                                </Border>
                                            </StackPanel>
                                            <TextBlock Text="WiFi Auto Switcher Pro v2.5 • Developed by S.Nova" FontSize="12" Foreground="#F8FAFC" FontWeight="SemiBold"/>
                                            <TextBlock x:Name="TxtAuthorDesc" Text="Hệ thống tự động giám sát độ trễ &amp; chuyển đổi Wi-Fi thông minh trên Windows." FontSize="11" Foreground="#94A3B8" Margin="0,2,0,0"/>
                                        </StackPanel>
                                    </Border>
                                </StackPanel>

                                <Button Grid.Row="2" x:Name="BtnSaveAllSettings" Style="{StaticResource ProBtnPrimary}" Content="💾 Lưu Cấu Hình Hệ Thống" HorizontalAlignment="Right" Padding="18,8" Margin="0,16,0,0"/>
                            </Grid>
                        </Border>
                    </Grid>

                </Grid>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

# ==================== GIAO DIỆN BẢNG NHỎ NỔI MÀN HÌNH (MINI HUD PRO) ====================
[xml]$miniXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WiFi HUD Pro" Height="70" Width="280"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ResizeMode="NoResize"
        FontFamily="Segoe UI, Tahoma, Helvetica, sans-serif"
        TextOptions.TextFormattingMode="Display"
        TextOptions.TextRenderingMode="ClearType"
        WindowStartupLocation="Manual">
    <Border Background="#F2080D17" BorderBrush="#2563EB" BorderThickness="1.5" CornerRadius="14" Padding="12,7" Cursor="SizeAll">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <!-- Row 1: Wi-Fi Name + Signal + Close -->
            <Grid Grid.Row="0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="⚡" FontSize="11" Foreground="#38BDF8" Margin="0,0,4,0"/>
                    <TextBlock x:Name="MiniSsid" Text="Đang kết nối..." FontSize="12" FontWeight="Bold" Foreground="#F8FAFC" MaxWidth="140" TextTrimming="CharacterEllipsis"/>
                </StackPanel>
                <TextBlock Grid.Column="1" x:Name="MiniSignal" Text="0%" FontSize="11" FontWeight="Bold" Foreground="#10B981" Margin="6,0,8,0" VerticalAlignment="Center"/>
                <Button Grid.Column="2" x:Name="MiniBtnClose" Content="✕" FontSize="10" FontWeight="Bold" Foreground="#94A3B8" Background="#1E293B" BorderThickness="0" Cursor="Hand" Width="18" Height="18" VerticalAlignment="Center">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" CornerRadius="9">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
            </Grid>
            <!-- Row 2: Ping + Speed + Mode Indicator -->
            <Grid Grid.Row="1" Margin="0,5,0,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <Ellipse x:Name="MiniPingDot" Width="7" Height="7" Fill="#10B981" Margin="0,0,6,0" VerticalAlignment="Center"/>
                    <TextBlock x:Name="MiniPing" Text="-- ms" FontSize="11" FontWeight="SemiBold" Foreground="#CBD5E1"/>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <TextBlock Text="DL: " FontSize="10" FontWeight="Bold" Foreground="#FBBF24"/>
                    <TextBlock x:Name="MiniSpeed" Text="-- Mbps" FontSize="11" FontWeight="SemiBold" Foreground="#CBD5E1"/>
                </StackPanel>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

# Đọc XAML vào Window Objects
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$miniReader = New-Object System.Xml.XmlNodeReader $miniXaml
$miniWindow = [System.Windows.Markup.XamlReader]::Load($miniReader)

# Tọa độ vị trí Mini HUD
$screenWidth = [System.Windows.SystemParameters]::PrimaryScreenWidth
if ($Global:Config.MiniWidgetX -gt 0 -and $Global:Config.MiniWidgetY -gt 0) {
    $miniWindow.Left = $Global:Config.MiniWidgetX
    $miniWindow.Top  = $Global:Config.MiniWidgetY
} else {
    $miniWindow.Left = $screenWidth - 300
    $miniWindow.Top  = 30
}

# Kéo thả Mini HUD và lưu vị trí
$miniWindow.Add_MouseLeftButtonDown({
    $miniWindow.DragMove()
    $Global:Config.MiniWidgetX = [int]$miniWindow.Left
    $Global:Config.MiniWidgetY = [int]$miniWindow.Top
})

# Ánh xạ Controls từ Cửa sổ chính
$CustomTitleBar         = $window.FindName("CustomTitleBar")
$BtnTitleMinimize       = $window.FindName("BtnTitleMinimize")
$BtnTitleClose          = $window.FindName("BtnTitleClose")
$BtnTitleMiniHUD        = $window.FindName("BtnTitleMiniHUD")
$TitleStatusPill        = $window.FindName("TitleStatusPill")
$TitleStatusDot         = $window.FindName("TitleStatusDot")
$TitleStatusText        = $window.FindName("TitleStatusText")
$BtnTitleLang           = $window.FindName("BtnTitleLang")

# Sidebar Buttons & Headers
$TxtNavMenuHeader        = $window.FindName("TxtNavMenuHeader")
$BtnNavDashboard        = $window.FindName("BtnNavDashboard")
$TxtNavDashboard        = $window.FindName("TxtNavDashboard")
$BtnNavSmartSwitch      = $window.FindName("BtnNavSmartSwitch")
$TxtNavSmartSwitch      = $window.FindName("TxtNavSmartSwitch")
$BtnNavRadar            = $window.FindName("BtnNavRadar")
$TxtNavRadar            = $window.FindName("TxtNavRadar")
$BtnNavAnalytics        = $window.FindName("BtnNavAnalytics")
$TxtNavAnalytics        = $window.FindName("TxtNavAnalytics")
$BtnNavSettings         = $window.FindName("BtnNavSettings")
$TxtNavSettings         = $window.FindName("TxtNavSettings")
$TxtSidebarHeader       = $window.FindName("TxtSidebarHeader")
$BtnQuickToggleAuto     = $window.FindName("BtnQuickToggleAuto")
$TxtSidebarSwitchesLabel= $window.FindName("TxtSidebarSwitchesLabel")
$TxtSidebarSwitches     = $window.FindName("TxtSidebarSwitches")
$TxtSidebarUptimeLabel  = $window.FindName("TxtSidebarUptimeLabel")
$TxtSidebarUptime       = $window.FindName("TxtSidebarUptime")

# Panels
$PanelDashboard         = $window.FindName("PanelDashboard")
$PanelSmartSwitch       = $window.FindName("PanelSmartSwitch")
$PanelRadar             = $window.FindName("PanelRadar")
$PanelAnalytics         = $window.FindName("PanelAnalytics")
$PanelSettings          = $window.FindName("PanelSettings")

# Dashboard Controls
$TxtHealthScore         = $window.FindName("TxtHealthScore")
$TxtHealthRating        = $window.FindName("TxtHealthRating")
$TxtHealthDesc          = $window.FindName("TxtHealthDesc")
$BtnDashboardTestNow    = $window.FindName("BtnDashboardTestNow")
$TxtWifiSSID            = $window.FindName("TxtWifiSSID")
$TxtWifiBand            = $window.FindName("TxtWifiBand")
$PbSignal               = $window.FindName("PbSignal")
$TxtSignalVal           = $window.FindName("TxtSignalVal")
$TxtWifiDetails         = $window.FindName("TxtWifiDetails")
$TxtPingVal             = $window.FindName("TxtPingVal")
$BadgePingStatus        = $window.FindName("BadgePingStatus")
$TxtPingQuality         = $window.FindName("TxtPingQuality")
$TxtPingGateway         = $window.FindName("TxtPingGateway")
$TxtPacketLoss          = $window.FindName("TxtPacketLoss")
$TxtSpeedVal            = $window.FindName("TxtSpeedVal")
$TxtSpeedStatus         = $window.FindName("TxtSpeedStatus")
$SparklinePanel         = $window.FindName("SparklinePanel")
$TxtDashboardLastChecked= $window.FindName("TxtDashboardLastChecked")

# Smart Switch Controls
$CardProfileGaming       = $window.FindName("CardProfileGaming")
$CardProfileStandard     = $window.FindName("CardProfileStandard")
$CardProfileSaving       = $window.FindName("CardProfileSaving")
$BtnApplyProfileGaming   = $window.FindName("BtnApplyProfileGaming")
$BtnApplyProfileStandard = $window.FindName("BtnApplyProfileStandard")
$BtnApplyProfileSaving   = $window.FindName("BtnApplyProfileSaving")
$TbMaxPing               = $window.FindName("TbMaxPing")
$TbMinSpeed              = $window.FindName("TbMinSpeed")
$TbMinSignal             = $window.FindName("TbMinSignal")
$TbMaxLoss               = $window.FindName("TbMaxLoss")
$TbInterval              = $window.FindName("TbInterval")
$TbCooldown              = $window.FindName("TbCooldown")
$BtnSaveSmartCriteria    = $window.FindName("BtnSaveSmartCriteria")

# Radar Controls
$BtnRadarRefresh         = $window.FindName("BtnRadarRefresh")
$TxtRadarTotalCount      = $window.FindName("TxtRadarTotalCount")
$LvRadarNetworks         = $window.FindName("LvRadarNetworks")

# Analytics Controls
$TxtKpiSwitches          = $window.FindName("TxtKpiSwitches")
$TxtKpiAvgPing           = $window.FindName("TxtKpiAvgPing")
$TxtKpiUptime            = $window.FindName("TxtKpiUptime")
$TxtKpiCurrentNet        = $window.FindName("TxtKpiCurrentNet")
$BtnExportLogs           = $window.FindName("BtnExportLogs")
$BtnClearLogs            = $window.FindName("BtnClearLogs")
$TbAnalyticsLogs         = $window.FindName("TbAnalyticsLogs")

# Settings Controls
$BtnLangVi               = $window.FindName("BtnLangVi")
$BtnLangEn               = $window.FindName("BtnLangEn")
$TxtSettingsHeader       = $window.FindName("TxtSettingsHeader")
$TxtSettingsLangLabel    = $window.FindName("TxtSettingsLangLabel")
$TxtSettingsPingHostLabel= $window.FindName("TxtSettingsPingHostLabel")
$TxtSettingsSpeedUrlLabel= $window.FindName("TxtSettingsSpeedUrlLabel")
$TxtAuthorHeader         = $window.FindName("TxtAuthorHeader")
$TxtAuthorDesc           = $window.FindName("TxtAuthorDesc")
$CbSettingsAutoStart     = $window.FindName("CbSettingsAutoStart")
$CbSettingsMiniHUD       = $window.FindName("CbSettingsMiniHUD")
$CbSettingsPlaySound     = $window.FindName("CbSettingsPlaySound")
$CbSettingsShowNotify    = $window.FindName("CbSettingsShowNotify")
$CbSettingsMinimizeClose = $window.FindName("CbSettingsMinimizeClose")
$TbSettingsPingHost      = $window.FindName("TbSettingsPingHost")
$TbSettingsSpeedUrl      = $window.FindName("TbSettingsSpeedUrl")
$BtnSaveAllSettings      = $window.FindName("BtnSaveAllSettings")

# Mini HUD Controls
$MiniSsid                = $miniWindow.FindName("MiniSsid")
$MiniSignal              = $miniWindow.FindName("MiniSignal")
$MiniBtnClose            = $miniWindow.FindName("MiniBtnClose")
$MiniPingDot             = $miniWindow.FindName("MiniPingDot")
$MiniPing                = $miniWindow.FindName("MiniPing")
$MiniSpeed               = $miniWindow.FindName("MiniSpeed")

# Tải thông số vào Settings Controls
$TbMaxPing.Text   = $Global:Config.MaxPingMs.ToString()
$TbMinSpeed.Text  = $Global:Config.MinSpeedMbps.ToString()
$TbMinSignal.Text = $Global:Config.MinSignalPercent.ToString()
$TbMaxLoss.Text   = $Global:Config.MaxPacketLossPercent.ToString()
$TbInterval.Text  = $Global:Config.CheckIntervalSeconds.ToString()
$TbCooldown.Text  = $Global:Config.CooldownSeconds.ToString()

$CbSettingsAutoStart.IsChecked     = [bool]$Global:Config.AutoStartWithWindows
$CbSettingsMiniHUD.IsChecked       = [bool]$Global:Config.ShowMiniWidget
$CbSettingsPlaySound.IsChecked     = [bool]$Global:Config.PlaySoundOnSwitch
$CbSettingsShowNotify.IsChecked    = [bool]$Global:Config.ShowNotifications
$CbSettingsMinimizeClose.IsChecked = [bool]$Global:Config.MinimizeToTrayOnClose
$TbSettingsPingHost.Text           = $Global:Config.TargetPingHost
$TbSettingsSpeedUrl.Text           = $Global:Config.SpeedTestUrl

# ==================== SYSTEM TRAY / NOTIFY ICON ====================
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$appIcoPath = Join-Path $ScriptDir "app.ico"
if (Test-Path $appIcoPath) {
    try {
        $notifyIcon.Icon = New-Object System.Drawing.Icon($appIcoPath)
        $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([System.Uri]::new($appIcoPath))
        $miniWindow.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([System.Uri]::new($appIcoPath))
    } catch {
        $notifyIcon.Icon = [System.Drawing.SystemIcons]::Shield
    }
} else {
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Shield
}
$notifyIcon.Text = "WiFi Auto Switcher Pro"
$notifyIcon.Visible = $true

$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$menuShow = $trayMenu.Items.Add("Mở Bảng Điều Khiển Pro")
$menuHud  = $trayMenu.Items.Add("Hiện / Ẩn Bảng Nhỏ (HUD)")
$menuAuto = $trayMenu.Items.Add("Bật / Tắt Tự Động Đổi Mạng")
$trayMenu.Items.Add("-") | Out-Null
$menuExit = $trayMenu.Items.Add("Thoát Hoàn Toàn Ứng Dụng")
$notifyIcon.ContextMenuStrip = $trayMenu

$menuShow.Add_Click({
    $window.Show()
    $window.WindowState = [System.Windows.WindowState]::Normal
    $window.Activate()
})
$menuHud.Add_Click({
    if ($miniWindow.IsVisible) {
        $miniWindow.Hide()
        $Global:Config.ShowMiniWidget = $false
    } else {
        $miniWindow.Show()
        $Global:Config.ShowMiniWidget = $true
    }
})
$notifyIcon.Add_DoubleClick({
    $window.Show()
    $window.WindowState = [System.Windows.WindowState]::Normal
    $window.Activate()
})
$menuExit.Add_Click({
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    $miniWindow.Close()
    $window.Close()
    [System.Windows.Application]::Current.Shutdown()
})

# ==================== HÀM TIỆN ÍCH & GHI LOG ====================

function Add-AuditLog {
    param([string]$message, [string]$type = "INFO")
    $now = [DateTime]::Now
    $timeStr = $now.ToString("HH:mm:ss")
    $logLine = "[$timeStr] [$type] $message`r`n"
    
    $Global:EventLogsList.Add([PSCustomObject]@{
        Time    = $now.ToString("yyyy-MM-dd HH:mm:ss")
        Type    = $type
        Message = $message
    })

    $window.Dispatcher.Invoke([System.Action]{
        $TbAnalyticsLogs.AppendText($logLine)
        $TbAnalyticsLogs.ScrollToEnd()
    })
}

function Show-ToastAlert {
    param([string]$title, [string]$msg, [int]$timeout = 3000)
    if ($Global:Config.ShowNotifications) {
        $notifyIcon.ShowBalloonTip($timeout, $title, $msg, [System.Windows.Forms.ToolTipIcon]::Info)
    }
}

function Play-SwitchChime {
    if ($Global:Config.PlaySoundOnSwitch) {
        try {
            [System.Media.SystemSounds]::Asterisk.Play()
        } catch { }
    }
}

# ==================== ĐIỀU HƯỚNG TABS GIAO DIỆN ====================

$navButtons = @($BtnNavDashboard, $BtnNavSmartSwitch, $BtnNavRadar, $BtnNavAnalytics, $BtnNavSettings)
$navPanels  = @($PanelDashboard, $PanelSmartSwitch, $PanelRadar, $PanelAnalytics, $PanelSettings)

function Switch-NavTab ([int]$tabIndex) {
    for ($i = 0; $i -lt $navPanels.Count; $i++) {
        if ($i -eq $tabIndex) {
            $navPanels[$i].Visibility = [System.Windows.Visibility]::Visible
            $navButtons[$i].Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E293B")
            $navButtons[$i].Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8")
        } else {
            $navPanels[$i].Visibility = [System.Windows.Visibility]::Collapsed
            $navButtons[$i].Background = [System.Windows.Media.Brushes]::Transparent
            $navButtons[$i].Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#94A3B8")
        }
    }
}

$BtnNavDashboard.Add_Click({ Switch-NavTab 0 })
$BtnNavSmartSwitch.Add_Click({ Switch-NavTab 1 })
$BtnNavRadar.Add_Click({ Switch-NavTab 2 })
$BtnNavAnalytics.Add_Click({ Switch-NavTab 3 })
$BtnNavSettings.Add_Click({ Switch-NavTab 4 })

# ==================== TITLEBAR & WINDOW CONTROLS ====================

$CustomTitleBar.Add_MouseLeftButtonDown({
    if ($_.ButtonState -eq [System.Windows.Input.MouseButtonState]::Pressed) {
        $window.DragMove()
    }
})

$BtnTitleMinimize.Add_Click({
    $window.WindowState = [System.Windows.WindowState]::Minimized
})

$BtnTitleClose.Add_Click({
    if ($Global:Config.MinimizeToTrayOnClose) {
        $window.Hide()
        Show-ToastAlert "WiFi Auto Switcher Pro" "Ứng dụng tiếp tục chạy ngầm trong khay để bảo vệ kết nối." 2000
    } else {
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
        $miniWindow.Close()
        $window.Close()
        [System.Windows.Application]::Current.Shutdown()
    }
})

$BtnTitleMiniHUD.Add_Click({
    if ($miniWindow.IsVisible) {
        $miniWindow.Hide()
        $Global:Config.ShowMiniWidget = $false
        $BtnTitleMiniHUD.Content = "📌 Bảng Nhỏ (HUD)"
    } else {
        $miniWindow.Show()
        $Global:Config.ShowMiniWidget = $true
        $BtnTitleMiniHUD.Content = "✕ Ẩn Bảng Nhỏ"
    }
})

$MiniBtnClose.Add_Click({
    $miniWindow.Hide()
    $Global:Config.ShowMiniWidget = $false
    $BtnTitleMiniHUD.Content = "📌 Bảng Nhỏ (HUD)"
})

$window.Add_Closing({
    param($sender, $e)
    if ($Global:Config.MinimizeToTrayOnClose -and $notifyIcon.Visible) {
        $e.Cancel = $true
        $window.Hide()
        Show-ToastAlert "WiFi Auto Switcher Pro" "Ứng dụng tiếp tục chạy ngầm để bảo vệ mạng." 1500
    }
})

# Cập nhật trạng thái bảo vệ (Bật/Tắt)
function Update-ProtectionStateUI {
    if ($Global:IsAutoSwitchRunning) {
        $TitleStatusPill.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#064E3B")
        $TitleStatusDot.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
        $TitleStatusText.Text = "ĐANG BẢO VỆ MẠNG 24/7"
        $TitleStatusText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
        $BtnQuickToggleAuto.Content = "Tắt Tự Động"
        $BtnQuickToggleAuto.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EF4444")
    } else {
        $TitleStatusPill.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#374151")
        $TitleStatusDot.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#9CA3AF")
        $TitleStatusText.Text = "ĐÃ TẮT BẢO VỆ TỰ ĐỘNG"
        $TitleStatusText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#9CA3AF")
        $BtnQuickToggleAuto.Content = "Bật Tự Động"
        $BtnQuickToggleAuto.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
    }
}
Update-ProtectionStateUI

$BtnQuickToggleAuto.Add_Click({
    $Global:IsAutoSwitchRunning = -not $Global:IsAutoSwitchRunning
    Update-ProtectionStateUI
    Add-AuditLog "Người dùng đã $(('BẬT','TẮT')[[int](-not $Global:IsAutoSwitchRunning)]) tính năng tự động chuyển mạng." "ACTION"
})

$menuAuto.Add_Click({
    $Global:IsAutoSwitchRunning = -not $Global:IsAutoSwitchRunning
    $window.Dispatcher.Invoke({ Update-ProtectionStateUI })
    Add-AuditLog "Chuyển trạng thái bảo vệ sang $(('BẬT','TẮT')[[int](-not $Global:IsAutoSwitchRunning)]) từ khay hệ thống." "ACTION"
})

# ==================== ĐO ĐẠC & THU THẬP DỮ LIỆU MẠNG ====================

function Get-RouterGatewayIP {
    try {
        $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($route -and $route.NextHop) { return $route.NextHop }
    } catch { }
    return "192.168.1.1"
}

function Get-WifiCurrentMetrics {
    $raw = netsh wlan show interfaces
    $status = [PSCustomObject]@{
        Connected    = $false
        SSID         = "Chưa kết nối"
        Signal       = 0
        ReceiveRate  = 0
        TransmitRate = 0
        Band         = "N/A"
        Channel      = 0
        BSSID        = "N/A"
        RadioType    = "N/A"
    }
    foreach ($line in $raw) {
        if ($line -match '^\s*State\s*:\s*(.+)$') {
            $st = $matches[1].Trim().ToLower()
            if ($st -eq 'connected' -or $st -eq 'đã kết nối') { $status.Connected = $true }
        }
        elseif ($line -match '^\s*SSID\s*:\s*(.+)$') { 
            $status.SSID = $matches[1].Trim() 
            if ($status.SSID -and $status.SSID -ne "Chưa kết nối") { $status.Connected = $true }
        }
        elseif ($line -match '^\s*AP BSSID\s*:\s*(.+)$') { $status.BSSID = $matches[1].Trim() }
        elseif ($line -match '(\d+)%') { $status.Signal = [int]$matches[1] }
        elseif ($line -match 'Receive rate.*:\s*([\d\.]+)') { $status.ReceiveRate = [int][double]$matches[1] }
        elseif ($line -match 'Transmit rate.*:\s*([\d\.]+)') { $status.TransmitRate = [int][double]$matches[1] }
        elseif ($line -match '^\s*Band\s*:\s*(.+)$') { $status.Band = $matches[1].Trim() }
        elseif ($line -match 'Channel\s*:\s*(\d+)') { $status.Channel = [int]$matches[1] }
        elseif ($line -match 'Radio type\s*:\s*(.+)$') { $status.RadioType = $matches[1].Trim() }
    }
    # Fallback suy luận Band từ Channel nếu netsh không in dòng Band
    if (($status.Band -eq "N/A" -or [string]::IsNullOrEmpty($status.Band)) -and $status.Channel -gt 0) {
        if ($status.Channel -le 14) { $status.Band = "2.4 GHz" }
        elseif ($status.Channel -le 177) { $status.Band = "5 GHz" }
        else { $status.Band = "6 GHz" }
    }
    return $status
}

function Get-AllSavedProfiles {
    $raw = netsh wlan show profiles
    $profiles = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $raw) {
        if ($line -match ':\s*([^:\r\n]+)$') {
            $p = $matches[1].Trim()
            if ($p -and $p -ne "<None>" -and -not $p.StartsWith("<") -and -not $profiles.Contains($p)) {
                $profiles.Add($p)
            }
        }
    }
    return $profiles
}

function Scan-RadarWifiNetworks {
    param([System.Collections.Generic.List[string]]$savedProfiles, [string]$currentSSID)
    $raw = netsh wlan show networks mode=bssid
    $dict = [System.Collections.Generic.Dictionary[string, PSCustomObject]]::new()
    $cSSID = ""
    $cSignal = 0
    $cBand = ""
    $cRadio = ""
    $cChannel = 0

    $saveNetwork = {
        if ($cSSID) {
            $bandFinal = $cBand
            if (-not $bandFinal -and $cChannel -gt 0) {
                if ($cChannel -le 14) { $bandFinal = "2.4 GHz" }
                elseif ($cChannel -le 177) { $bandFinal = "5 GHz" }
                else { $bandFinal = "6 GHz" }
            }
            if (-not $bandFinal) { $bandFinal = "2.4 GHz" }

            $isSaved = ($savedProfiles -and $savedProfiles.Contains($cSSID))
            $isCurrent = ($cSSID -eq $currentSSID)

            if ($dict.ContainsKey($cSSID)) {
                if ($cSignal -gt $dict[$cSSID].Signal) {
                    $dict[$cSSID].Signal = $cSignal
                    $dict[$cSSID].Band = $bandFinal
                    $dict[$cSSID].RadioType = $cRadio
                }
            } else {
                $dict[$cSSID] = [PSCustomObject]@{
                    SSID       = $cSSID
                    Signal     = $cSignal
                    Band       = $bandFinal
                    RadioType  = $cRadio
                    IsSaved    = $isSaved
                    IsCurrent  = $isCurrent
                }
            }
        }
    }

    foreach ($line in $raw) {
        if ($line -match '^SSID\s+\d+\s*:\s*(.*)$') {
            & $saveNetwork
            $cSSID = $matches[1].Trim()
            $cSignal = 0
            $cBand = ""
            $cRadio = ""
            $cChannel = 0
        }
        elseif ($line -match 'Signal\s*:\s*(\d+)%') {
            $cSignal = [int]$matches[1]
        }
        elseif ($line -match 'Radio type\s*:\s*(.+)$') {
            $cRadio = $matches[1].Trim()
        }
        elseif ($line -match 'Band\s*:\s*(.+)$') {
            $cBand = $matches[1].Trim()
        }
        elseif ($line -match 'Channel\s*:\s*(\d+)') {
            $cChannel = [int]$matches[1]
        }
    }
    & $saveNetwork

    return $dict.Values
}

function Measure-DualPingAndSpeed {
    param([string]$targetHost, [string]$gatewayHost, [string]$speedUrl)
    
    $result = [PSCustomObject]@{
        WanPingMs   = -1
        LanPingMs   = -1
        PacketLoss  = 100
        SpeedMbps   = 0.0
        IsOnline    = $false
    }

    $ping = New-Object System.Net.NetworkInformation.Ping
    $successWan = 0
    $totalWanMs = 0
    $samples = 3

    # Đo WAN Ping (Internet)
    for ($i = 0; $i -lt $samples; $i++) {
        try {
            $reply = $ping.Send($targetHost, 900)
            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                $successWan++
                $totalWanMs += $reply.RoundtripTime
            }
        } catch { }
        Start-Sleep -Milliseconds 30
    }

    if ($successWan -gt 0) {
        $result.WanPingMs = [math]::Round($totalWanMs / $successWan, 0)
        $result.PacketLoss = [math]::Round((($samples - $successWan) / $samples) * 100, 0)
        $result.IsOnline = $true
    } else {
        $result.WanPingMs = 999
        $result.PacketLoss = 100
        $result.IsOnline = $false
    }

    # Đo LAN Ping (Router Gateway)
    try {
        $replyGw = $ping.Send($gatewayHost, 500)
        if ($replyGw.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            $result.LanPingMs = $replyGw.RoundtripTime
        }
    } catch { }

    # Đo Tốc độ Download nếu đang Online
    if ($result.IsOnline) {
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "WifiSwitcherProEnterprise/2.5")
            $data = $wc.DownloadData($speedUrl)
            $sw.Stop()
            if ($data.Length -gt 0 -and $sw.Elapsed.TotalSeconds -gt 0.04) {
                $mbps = [math]::Round(($data.Length * 8) / ($sw.Elapsed.TotalSeconds * 1000000), 2)
                $result.SpeedMbps = $mbps
            }
        } catch {
            $result.SpeedMbps = 0.0
        }
    }

    return $result
}

function Connect-TargetWifi {
    param([string]$ssid)
    Add-AuditLog "Bắt đầu tự động chuyển sang mạng: '$ssid'..." "SWITCH"
    $out = netsh wlan connect name="$ssid" 2>&1
    Start-Sleep -Seconds 3
    $cur = Get-WifiCurrentMetrics
    if ($cur.Connected -and $cur.SSID -eq $ssid) {
        $Global:Config.TotalSwitchesCount++
        $Global:LastSwitchTime = [DateTime]::Now
        $Global:ConsecutiveFails = 0
        Play-SwitchChime
        Add-AuditLog "CHUYỂN MẠNG THÀNH CÔNG: Đã kết nối '$ssid' (Sóng: $($cur.Signal)%, $($cur.Band))." "SUCCESS"
        Show-ToastAlert "WiFi Auto Switcher Pro" "Đã tự động kết nối sang Wi-Fi '$ssid' (Sóng $($cur.Signal)%)" 3000
        return $true
    } else {
        Add-AuditLog "Chưa thể bắt sóng '$ssid'. Trạng thái hiện tại: $($cur.SSID)" "WARN"
        return $false
    }
}

function Get-NetworkHealthScore {
    param(
        [int]$signal,
        [int]$wanPingMs,
        [int]$packetLoss,
        [double]$speedMbps,
        [bool]$isOnline = $true
    )
    $sigScore = [Math]::Min(100, [Math]::Max(0, $signal))
    $pingScore = 0
    if ($isOnline) {
        if ($wanPingMs -le 35) { $pingScore = 100 }
        elseif ($wanPingMs -le 75) { $pingScore = 85 }
        elseif ($wanPingMs -le 150) { $pingScore = 65 }
        elseif ($wanPingMs -le 250) { $pingScore = 35 }
        else { $pingScore = 10 }
    }
    $lossScore = [Math]::Max(0, 100 - ($packetLoss * 2))
    $speedScore = if ($speedMbps -ge 10) { 100 } elseif ($speedMbps -ge 2) { 70 } else { 30 }

    $score = [Math]::Round(($sigScore * 0.3) + ($pingScore * 0.35) + ($lossScore * 0.25) + ($speedScore * 0.10), 0)
    $quality = if ($score -ge 85) { "EXCELLENT" } elseif ($score -ge 65) { "GOOD" } elseif ($score -ge 40) { "FAIR" } else { "CRITICAL" }

    return [PSCustomObject]@{
        Score   = $score
        Quality = $quality
    }
}

function Update-DashboardUI {
    param($curWifi, $metrics, $availNetworks)

    # 1. Điểm sức khỏe mạng (Network Health Score 0..100)
    $healthObj = Get-NetworkHealthScore -signal $curWifi.Signal -wanPingMs $metrics.WanPingMs -packetLoss $metrics.PacketLoss -speedMbps $metrics.SpeedMbps -isOnline $metrics.IsOnline
    $healthScore = $healthObj.Score
    $TxtHealthScore.Text = "$healthScore"

    if ($healthScore -ge 85) {
        $TxtHealthRating.Text = "XUẤT SẮC &amp; RẤT MƯỢT"
        $TxtHealthRating.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
        $TxtHealthDesc.Text = "Đường truyền Internet hoàn hảo, độ trễ lý tưởng cho Gaming và họp trực tuyến."
    } elseif ($healthScore -ge 65) {
        $TxtHealthRating.Text = "ỔN ĐỊNH &amp; TỐT"
        $TxtHealthRating.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8")
        $TxtHealthDesc.Text = "Chất lượng mạng tốt, đáp ứng mượt mà nhu cầu xem phim 4K và làm việc."
    } elseif ($healthScore -ge 40) {
        $TxtHealthRating.Text = "TRUNG BÌNH / HƠI CHẬP CHỜN"
        $TxtHealthRating.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FBBF24")
        $TxtHealthDesc.Text = "Độ trễ hoặc mất gói tin đang tăng, hệ thống đang theo dõi để tự đổi khi cần."
    } else {
        $TxtHealthRating.Text = "MẠNG YẾU / MẤT KẾT NỐI"
        $TxtHealthRating.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F87171")
        $TxtHealthDesc.Text = "Tín hiệu sóng kém hoặc mất mạng ngoài. Hệ thống đang tự động tìm Wi-Fi tốt hơn!"
    }

    # 2. Wi-Fi hiện tại
    if ($curWifi.Connected) {
        $TxtWifiSSID.Text = $curWifi.SSID
        $TxtWifiBand.Text = "[$($curWifi.Band)]"
        $PbSignal.Value = $curWifi.Signal
        $TxtSignalVal.Text = "$($curWifi.Signal)%"
        if ($curWifi.Signal -ge 70) {
            $PbSignal.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
            $TxtSignalVal.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
        } elseif ($curWifi.Signal -ge 40) {
            $PbSignal.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F59E0B")
            $TxtSignalVal.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F59E0B")
        } else {
            $PbSignal.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EF4444")
            $TxtSignalVal.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EF4444")
        }
        $TxtWifiDetails.Text = "RX: $($curWifi.ReceiveRate) Mbps / TX: $($curWifi.TransmitRate) Mbps | Kênh: $($curWifi.Channel) | BSSID: $($curWifi.BSSID)"
    } else {
        $TxtWifiSSID.Text = "MẤT KẾT NỐI WI-FI"
        $TxtWifiBand.Text = ""
        $PbSignal.Value = 0
        $TxtSignalVal.Text = "0%"
        $TxtWifiDetails.Text = "Chưa kết nối vào bất kỳ mạng Wi-Fi nào xung quanh."
    }

    # 3. Ping & Packet Loss
    if ($metrics.IsOnline) {
        $TxtPingVal.Text = "$($metrics.WanPingMs) ms"
        $TxtPacketLoss.Text = "Mất gói: $($metrics.PacketLoss)%"
        $TxtPingGateway.Text = "Router LAN: $(if ($metrics.LanPingMs -ge 0) { "$($metrics.LanPingMs) ms" } else { "--" })"

        if ($metrics.WanPingMs -le 50 -and $metrics.PacketLoss -eq 0) {
            $BadgePingStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#064E3B")
            $TxtPingQuality.Text = "RẤT MƯỢT"
            $TxtPingQuality.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
        } elseif ($metrics.WanPingMs -le $Global:Config.MaxPingMs) {
            $BadgePingStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E3A8A")
            $TxtPingQuality.Text = "BÌNH THƯỜNG"
            $TxtPingQuality.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#60A5FA")
        } else {
            $BadgePingStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#7F1D1D")
            $TxtPingQuality.Text = "PING CAO"
            $TxtPingQuality.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F87171")
        }
    } else {
        $TxtPingVal.Text = "TIMEOUT"
        $TxtPacketLoss.Text = "Mất gói: 100%"
        $TxtPingGateway.Text = "Router LAN: Không phản hồi"
        $BadgePingStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#7F1D1D")
        $TxtPingQuality.Text = "MẤT MẠNG"
        $TxtPingQuality.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F87171")
    }

    # 4. Tốc độ thực tế
    if ($metrics.SpeedMbps -gt 0) {
        $TxtSpeedVal.Text = "$($metrics.SpeedMbps) Mbps"
        if ($metrics.SpeedMbps -ge $Global:Config.MinSpeedMbps) {
            $TxtSpeedStatus.Text = "Băng thông đạt chuẩn (> $($Global:Config.MinSpeedMbps) Mbps)"
            $TxtSpeedStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
        } else {
            $TxtSpeedStatus.Text = "Tốc độ quá thấp (< $($Global:Config.MinSpeedMbps) Mbps)"
            $TxtSpeedStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F87171")
        }
    } else {
        $TxtSpeedVal.Text = "0 Mbps"
        $TxtSpeedStatus.Text = "Không tải được dữ liệu"
        $TxtSpeedStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F87171")
    }

    # 5. Cập nhật Sparkline Biểu đồ Ping
    $Global:PingHistory.Add([int]$metrics.WanPingMs)
    if ($Global:PingHistory.Count -gt 16) { $Global:PingHistory.RemoveAt(0) }

    $SparklinePanel.Children.Clear()
    foreach ($p in $Global:PingHistory) {
        $barHeight = [Math]::Min(80, [Math]::Max(6, ($p / 3.0)))
        $barCol = "#34D399"
        if ($p -gt 200 -or $p -eq 999) { $barCol = "#F87171"; $barHeight = 80 }
        elseif ($p -gt 100) { $barCol = "#FBBF24" }
        elseif ($p -gt 50) { $barCol = "#38BDF8" }

        $border = New-Object System.Windows.Controls.Border
        $border.Width = 22
        $border.Height = $barHeight
        $border.CornerRadius = [System.Windows.CornerRadius]::new(4)
        $border.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($barCol)
        $border.Margin = [System.Windows.Thickness]::new(4, 0, 4, 0)
        $border.ToolTip = "Ping: $p ms"
        $SparklinePanel.Children.Add($border) | Out-Null
    }

    # 6. Cập nhật Radar ListView
    $uiRadarList = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($net in ($availNetworks | Sort-Object -Property Signal -Descending)) {
        $statusText = "CHƯA LƯU"
        $badgeBg = "#1F2937"
        $badgeFg = "#9CA3AF"
        if ($net.IsCurrent) {
            $statusText = "ĐANG DÙNG"
            $badgeBg = "#064E3B"
            $badgeFg = "#34D399"
        } elseif ($net.IsSaved) {
            $statusText = "ĐÃ LƯU"
            $badgeBg = "#1E3A8A"
            $badgeFg = "#60A5FA"
        }

        $sigColor = "#F87171"
        if ($net.Signal -ge 70) { $sigColor = "#34D399" }
        elseif ($net.Signal -ge 40) { $sigColor = "#FBBF24" }

        $uiRadarList.Add([PSCustomObject]@{
            SSID        = $net.SSID
            Band        = $net.Band
            Details     = "Chuẩn: $($net.RadioType) | Trạng thái: $statusText"
            StatusText  = $statusText
            BadgeBg     = $badgeBg
            BadgeFg     = $badgeFg
            SignalVal   = $net.Signal
            SignalText  = "$($net.Signal)%"
            SignalColor = $sigColor
        })
    }
    $LvRadarNetworks.ItemsSource = $uiRadarList
    $TxtRadarTotalCount.Text = "($($uiRadarList.Count) mạng xung quanh)"

    # 7. Cập nhật KPI Analytics & Sidebar
    $TxtSidebarSwitches.Text = "$($Global:Config.TotalSwitchesCount) lần"
    $TxtKpiSwitches.Text     = "$($Global:Config.TotalSwitchesCount) lần"
    $TxtKpiCurrentNet.Text   = $curWifi.SSID

    $uptimeSpan = [DateTime]::Now - $Global:StartTime
    $TxtSidebarUptime.Text   = "$($uptimeSpan.Hours.ToString('00')):$($uptimeSpan.Minutes.ToString('00')):$($uptimeSpan.Seconds.ToString('00'))"

    $validPings = $Global:PingHistory | Where-Object { $_ -gt 0 -and $_ -lt 999 }
    if ($validPings.Count -gt 0) {
        $avg = [Math]::Round(($validPings | Measure-Object -Average).Average, 0)
        $TxtKpiAvgPing.Text = "$avg ms"
    }

    $TxtDashboardLastChecked.Text = "Cập nhật lúc: $([DateTime]::Now.ToString('HH:mm:ss'))"

    # 8. Cập nhật Bảng Nhỏ Nổi Màn Hình (Mini HUD)
    if ($curWifi.Connected) {
        $MiniSsid.Text = $curWifi.SSID
        $MiniSignal.Text = "$($curWifi.Signal)%"
        if ($curWifi.Signal -ge 70) {
            $MiniSignal.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
        } elseif ($curWifi.Signal -ge 40) {
            $MiniSignal.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F59E0B")
        } else {
            $MiniSignal.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EF4444")
        }
    } else {
        $MiniSsid.Text = "MẤT WI-FI"
        $MiniSignal.Text = "0%"
        $MiniSignal.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EF4444")
    }

    if ($metrics.IsOnline) {
        $MiniPing.Text = "$($metrics.WanPingMs) ms"
        if ($metrics.WanPingMs -le 50 -and $metrics.PacketLoss -eq 0) {
            $MiniPingDot.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
        } elseif ($metrics.WanPingMs -le $Global:Config.MaxPingMs) {
            $MiniPingDot.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3B82F6")
        } else {
            $MiniPingDot.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EF4444")
        }
    } else {
        $MiniPing.Text = "TIMEOUT"
        $MiniPingDot.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EF4444")
    }

    $MiniSpeed.Text = "$($metrics.SpeedMbps) Mbps"
}

# ==================== THUẬT TOÁN TỰ ĐỘNG CHUYỂN MẠNG 100% ====================

function Execute-MonitoringCycle {
    param([bool]$forceCheck = $false)
    if ($Global:IsCheckingNow) { return }
    $Global:IsCheckingNow = $true

    try {
        $curWifi       = Get-WifiCurrentMetrics
        $gatewayHost   = Get-RouterGatewayIP
        $metrics       = Measure-DualPingAndSpeed -targetHost $Global:Config.TargetPingHost -gatewayHost $gatewayHost -speedUrl $Global:Config.SpeedTestUrl
        $savedProfiles = Get-AllSavedProfiles
        $availNetworks = Scan-RadarWifiNetworks -savedProfiles $savedProfiles -currentSSID $curWifi.SSID

        $window.Dispatcher.Invoke([System.Action]{
            Update-DashboardUI -curWifi $curWifi -metrics $metrics -availNetworks $availNetworks
        })

        if ($Global:IsAutoSwitchRunning) {
            $isLagging = $false
            $isEmergency = $false
            $reasons = [System.Collections.Generic.List[string]]::new()

            if (-not $curWifi.Connected -or -not $metrics.IsOnline) {
                $isLagging = $true
                $isEmergency = $true
                $reasons.Add("Mất hoàn toàn kết nối Internet")
            } else {
                if ($metrics.WanPingMs -gt 250) {
                    $isLagging = $true
                    $isEmergency = $true
                    $reasons.Add("Độ trễ cực cao ($($metrics.WanPingMs) ms)")
                }
                elseif ($metrics.WanPingMs -gt $Global:Config.MaxPingMs) {
                    $isLagging = $true
                    $reasons.Add("Ping ($($metrics.WanPingMs) ms) vượt ngưỡng $($Global:Config.MaxPingMs) ms")
                }

                if ($metrics.PacketLoss -gt $Global:Config.MaxPacketLossPercent) {
                    $isLagging = $true
                    $reasons.Add("Mất gói tin ($($metrics.PacketLoss)%) vượt mức cho phép")
                }

                if ($metrics.SpeedMbps -gt 0 -and $metrics.SpeedMbps -lt $Global:Config.MinSpeedMbps) {
                    $isLagging = $true
                    $reasons.Add("Băng thông ($($metrics.SpeedMbps) Mbps) &lt; $($Global:Config.MinSpeedMbps) Mbps")
                }

                if ($curWifi.Signal -lt $Global:Config.MinSignalPercent) {
                    $isLagging = $true
                    $reasons.Add("Sóng Wi-Fi ($($curWifi.Signal)%) &lt; $($Global:Config.MinSignalPercent)%")
                }
            }

            if ($isLagging) {
                $Global:ConsecutiveFails++
                Add-AuditLog "PHÁT HIỆN MẠNG YẾU: $($reasons -join ', ')" "WARN"

                $secondsSinceLastSwitch = ([DateTime]::Now - $Global:LastSwitchTime).TotalSeconds
                if ($secondsSinceLastSwitch -lt $Global:Config.CooldownSeconds) {
                    $remain = [Math]::Round($Global:Config.CooldownSeconds - $secondsSinceLastSwitch, 0)
                    Add-AuditLog "Đang trong thời gian làm dịu (Cooldown $remain s). Chưa chuyển ngay để tránh nhảy mạng liên tục." "INFO"
                    return
                }

                if ($isEmergency -or $Global:ConsecutiveFails -ge 1) {
                    $candidates = $availNetworks | Where-Object {
                        $_.IsSaved -and ($_.SSID -ne $curWifi.SSID) -and ($_.Signal -gt $Global:Config.MinSignalPercent)
                    } | Sort-Object -Property Signal -Descending

                    if ($candidates -and $candidates.Count -gt 0) {
                        $bestTarget = $candidates[0]
                        if ((-not $curWifi.Connected) -or ($bestTarget.Signal -ge ($curWifi.Signal + $Global:Config.MinSignalImprovement)) -or ($curWifi.Signal -lt 35)) {
                            Add-AuditLog "[TỰ ĐỘNG 100%] Đang chuyển đổi sang Wi-Fi '$($bestTarget.SSID)' (Sóng $($bestTarget.Signal)%, $($bestTarget.Band))..." "SWITCH"
                            Connect-TargetWifi -ssid $bestTarget.SSID
                        } else {
                            Add-AuditLog "Wi-Fi '$($bestTarget.SSID)' chưa mạnh hơn đáng kể ($($bestTarget.Signal)% vs $($curWifi.Signal)%). Tiếp tục giữ mạng." "INFO"
                        }
                    } else {
                        Add-AuditLog "Không tìm thấy Wi-Fi đã lưu nào khác có sóng tốt xung quanh." "WARN"
                    }
                }
            } else {
                if ($Global:ConsecutiveFails -gt 0) {
                    Add-AuditLog "Chất lượng mạng đã phục hồi ổn định (Ping $($metrics.WanPingMs)ms, Sóng $($curWifi.Signal)%)." "SUCCESS"
                }
                $Global:ConsecutiveFails = 0
            }
        }
    } catch {
        Add-AuditLog "Lỗi trong chu kỳ giám sát: $($_.Exception.Message)" "ERROR"
    } finally {
        $Global:IsCheckingNow = $false
    }
}

# Click chuyển Wi-Fi thủ công từ ListView Radar
$LvRadarNetworks.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($sender, $e)
    if ($e.OriginalSource -and $e.OriginalSource.Tag) {
        $targetSSID = $e.OriginalSource.Tag.ToString()
        if ($targetSSID) {
            Connect-TargetWifi -ssid $targetSSID
            Execute-MonitoringCycle -forceCheck $true
        }
    }
})

# Nút đo kiểm tra ngay trên Dashboard
$BtnDashboardTestNow.Add_Click({
    Add-AuditLog "Người dùng yêu cầu kiểm tra toàn diện chất lượng mạng ngay lập tức..." "ACTION"
    Execute-MonitoringCycle -forceCheck $true
})

# Nút quét lại radar
$BtnRadarRefresh.Add_Click({
    Add-AuditLog "Đang quét lại toàn bộ quang phổ sóng Wi-Fi..." "ACTION"
    Execute-MonitoringCycle -forceCheck $true
})

# ==================== XỬ LÝ CÁC NÚT BẤM PROFILE & CÀI ĐẶT ====================

function Set-ActiveProfile ([string]$profileName, [bool]$showFeedback = $true) {
    $activeBrush    = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8")
    $defaultBrush   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E293B")
    $primaryBtnBg   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2563EB")
    $secondaryBtnBg = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E293B")
    $whiteFg        = [System.Windows.Media.Brushes]::White
    $mutedFg        = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#94A3B8")

    $btnActiveText   = if ($Global:Config.Language -eq "en") { "✓ [ACTIVE]" } else { "✓ [ĐANG CHỌN]" }
    $btnInactiveText = if ($Global:Config.Language -eq "en") { "Activate" } else { "Kích Hoạt" }

    # Reset all 3 cards & buttons
    if ($CardProfileGaming)   { $CardProfileGaming.BorderBrush   = $defaultBrush }
    if ($CardProfileStandard) { $CardProfileStandard.BorderBrush = $defaultBrush }
    if ($CardProfileSaving)   { $CardProfileSaving.BorderBrush   = $defaultBrush }

    if ($BtnApplyProfileGaming) {
        $BtnApplyProfileGaming.Content    = $btnInactiveText
        $BtnApplyProfileGaming.Background = $secondaryBtnBg
        $BtnApplyProfileGaming.Foreground = $mutedFg
    }
    if ($BtnApplyProfileStandard) {
        $BtnApplyProfileStandard.Content    = $btnInactiveText
        $BtnApplyProfileStandard.Background = $secondaryBtnBg
        $BtnApplyProfileStandard.Foreground = $mutedFg
    }
    if ($BtnApplyProfileSaving) {
        $BtnApplyProfileSaving.Content    = $btnInactiveText
        $BtnApplyProfileSaving.Background = $secondaryBtnBg
        $BtnApplyProfileSaving.Foreground = $mutedFg
    }

    if ($profileName -eq "Gaming") {
        if ($CardProfileGaming)   { $CardProfileGaming.BorderBrush = $activeBrush }
        if ($BtnApplyProfileGaming) {
            $BtnApplyProfileGaming.Content    = $btnActiveText
            $BtnApplyProfileGaming.Background = $primaryBtnBg
            $BtnApplyProfileGaming.Foreground = $whiteFg
        }

        $TbMaxPing.Text   = "80"
        $TbMinSpeed.Text  = "5.0"
        $TbMinSignal.Text = "50"
        $TbMaxLoss.Text   = "5"
        $TbInterval.Text  = "4"
        $TbCooldown.Text  = "15"

        $Global:Config.MaxPingMs            = 80
        $Global:Config.MinSpeedMbps         = 5.0
        $Global:Config.MinSignalPercent     = 50
        $Global:Config.MaxPacketLossPercent = 5
        $Global:Config.CheckIntervalSeconds = 4
        $Global:Config.CooldownSeconds      = 15
        $Global:Config.ActiveProfile        = "Gaming"

        if ($showFeedback) {
            $msgTitle = if ($Global:Config.Language -eq "en") { "Gaming & Streaming Profile" } else { "Chế Độ Gaming & Họp Online" }
            $msgBody  = if ($Global:Config.Language -eq "en") { "Ultra-sensitive profile active! Will auto switch if Ping > 80ms." } else { "Đã kích hoạt chế độ siêu nhạy! Tự đổi mạng ngay khi Ping > 80ms." }
            Add-AuditLog $(if ($Global:Config.Language -eq "en") { "ACTIVATED PROFILE: Gaming & Streaming (Low latency < 80ms, Loss < 5%)." } else { "ĐÃ KÍCH HOẠT CHẾ ĐỘ: Gaming & Livestream (Độ trễ thấp < 80ms, Mất gói < 5%)." }) "ACTION"
            Show-ToastAlert $msgTitle $msgBody 2000
        }
    }
    elseif ($profileName -eq "Saving") {
        if ($CardProfileSaving)   { $CardProfileSaving.BorderBrush = $activeBrush }
        if ($BtnApplyProfileSaving) {
            $BtnApplyProfileSaving.Content    = $btnActiveText
            $BtnApplyProfileSaving.Background = $primaryBtnBg
            $BtnApplyProfileSaving.Foreground = $whiteFg
        }

        $TbMaxPing.Text   = "220"
        $TbMinSpeed.Text  = "1.0"
        $TbMinSignal.Text = "25"
        $TbMaxLoss.Text   = "40"
        $TbInterval.Text  = "10"
        $TbCooldown.Text  = "30"

        $Global:Config.MaxPingMs            = 220
        $Global:Config.MinSpeedMbps         = 1.0
        $Global:Config.MinSignalPercent     = 25
        $Global:Config.MaxPacketLossPercent = 40
        $Global:Config.CheckIntervalSeconds = 10
        $Global:Config.CooldownSeconds      = 30
        $Global:Config.ActiveProfile        = "Saving"

        if ($showFeedback) {
            $msgTitle = if ($Global:Config.Language -eq "en") { "Battery Saver & Stable Profile" } else { "Chế Độ Tiết Kiệm & Ổn Định" }
            $msgBody  = if ($Global:Config.Language -eq "en") { "Conservative profile active! Prioritizes keeping current network." } else { "Đã kích hoạt! Giữ kết nối tối đa, hạn chế nhảy mạng." }
            Add-AuditLog $(if ($Global:Config.Language -eq "en") { "ACTIVATED PROFILE: Battery Saver & Stable (Switch only if Signal < 25% or disconnected)." } else { "ĐÃ KÍCH HOẠT CHẾ ĐỘ: Tiết Kiệm & Ổn Định (Chỉ đổi khi sóng < 25% hoặc mất mạng)." }) "ACTION"
            Show-ToastAlert $msgTitle $msgBody 2000
        }
    }
    elseif ($profileName -eq "Custom") {
        $Global:Config.ActiveProfile = "Custom"
        if ($showFeedback) {
            $msgTitle = if ($Global:Config.Language -eq "en") { "Custom Profile" } else { "Chế Độ Tùy Chỉnh" }
            $msgBody  = if ($Global:Config.Language -eq "en") { "Manual configuration active." } else { "Đã chuyển sang chế độ thiết lập thủ công." }
            Add-AuditLog $(if ($Global:Config.Language -eq "en") { "ACTIVATED PROFILE: Custom user defined." } else { "ĐÃ KÍCH HOẠT CHẾ ĐỘ: Tùy chỉnh người dùng." }) "ACTION"
            Show-ToastAlert $msgTitle $msgBody 1500
        }
    }
    else { # Standard
        if ($CardProfileStandard) { $CardProfileStandard.BorderBrush = $activeBrush }
        if ($BtnApplyProfileStandard) {
            $BtnApplyProfileStandard.Content    = $btnActiveText
            $BtnApplyProfileStandard.Background = $primaryBtnBg
            $BtnApplyProfileStandard.Foreground = $whiteFg
        }

        $TbMaxPing.Text   = "150"
        $TbMinSpeed.Text  = "2.0"
        $TbMinSignal.Text = "40"
        $TbMaxLoss.Text   = "25"
        $TbInterval.Text  = "6"
        $TbCooldown.Text  = "20"

        $Global:Config.MaxPingMs            = 150
        $Global:Config.MinSpeedMbps         = 2.0
        $Global:Config.MinSignalPercent     = 40
        $Global:Config.MaxPacketLossPercent = 25
        $Global:Config.CheckIntervalSeconds = 6
        $Global:Config.CooldownSeconds      = 20
        $Global:Config.ActiveProfile        = "Standard"

        if ($showFeedback) {
            $msgTitle = if ($Global:Config.Language -eq "en") { "Standard Office & Streaming" } else { "Chế Độ Tiêu Chuẩn" }
            $msgBody  = if ($Global:Config.Language -eq "en") { "Balanced profile active for everyday work & 4K streaming." } else { "Đã kích hoạt chế độ cân bằng cho làm việc & xem phim 4K." }
            Add-AuditLog $(if ($Global:Config.Language -eq "en") { "ACTIVATED PROFILE: Office & Streaming (Balanced: Ping > 150ms or Signal < 40%)." } else { "ĐÃ KÍCH HOẠT CHẾ ĐỘ: Văn Phòng & Phim Ảnh (Cân bằng tối ưu: Ping > 150ms hoặc Sóng < 40%)." }) "ACTION"
            Show-ToastAlert $msgTitle $msgBody 2000
        }
    }

    # Tự động lưu xuống config.json
    try {
        $Global:Config | ConvertTo-Json -Depth 4 | Set-Content -Path $ConfigFile -Encoding UTF8
    } catch { }

    # Cập nhật chu kỳ kiểm tra DispatcherTimer
    if ($monitorTimer) {
        $monitorTimer.Interval = [TimeSpan]::FromSeconds($Global:Config.CheckIntervalSeconds)
    }
}

function Apply-Language ([string]$lang) {
    if ($lang -ne "vi" -and $lang -ne "en") { $lang = "vi" }
    $Global:Config.Language = $lang
    $isEn = ($lang -eq "en")

    # 1. Update Titlebar
    if ($BtnTitleLang) {
        $BtnTitleLang.Content = if ($isEn) { "🌐 EN" } else { "🌐 VI" }
    }
    if ($TitleStatusText) {
        if ($Global:IsAutoSwitchRunning) {
            $TitleStatusText.Text = if ($isEn) { "ACTIVE PROTECTION 24/7" } else { "ĐANG BẢO VỆ MẠNG 24/7" }
        } else {
            $TitleStatusText.Text = if ($isEn) { "AUTO-SWITCH PAUSED" } else { "ĐÃ TẠM DỪNG TỰ ĐỔI MẠNG" }
        }
    }
    if ($BtnTitleMiniHUD) {
        if ($miniWindow -and $miniWindow.IsVisible) {
            $BtnTitleMiniHUD.Content = if ($isEn) { "✕ Hide Mini Widget" } else { "✕ Ẩn Bảng Nhỏ" }
        } else {
            $BtnTitleMiniHUD.Content = if ($isEn) { "📌 Mini Widget (HUD)" } else { "📌 Bảng Nhỏ (HUD)" }
        }
    }

    # 2. Update Navigation Sidebar
    if ($TxtNavMenuHeader)       { $TxtNavMenuHeader.Text       = if ($isEn) { "ADMIN MENU" } else { "MENU QUẢN TRỊ" } }
    if ($TxtNavDashboard)        { $TxtNavDashboard.Text        = if ($isEn) { "Dashboard" } else { "Tổng Quan" } }
    if ($TxtNavSmartSwitch)      { $TxtNavSmartSwitch.Text      = if ($isEn) { "Smart Switch" } else { "Tự Động Đổi" } }
    if ($TxtNavRadar)            { $TxtNavRadar.Text            = if ($isEn) { "Wi-Fi Radar" } else { "Radar Quét Sóng" } }
    if ($TxtNavAnalytics)        { $TxtNavAnalytics.Text        = if ($isEn) { "Analytics & Logs" } else { "Nhật Ký & Sự Kiện" } }
    if ($TxtNavSettings)         { $TxtNavSettings.Text         = if ($isEn) { "System Settings" } else { "Cài Đặt Hệ Thống" } }
    if ($TxtSidebarHeader)       { $TxtSidebarHeader.Text       = if ($isEn) { "AUTO PROTECTION" } else { "BẢO VỆ TỰ ĐỘNG" } }
    if ($TxtSidebarSwitchesLabel){ $TxtSidebarSwitchesLabel.Text= if ($isEn) { "Auto-switches:" } else { "Lần tự đổi mạng:" } }
    if ($TxtSidebarUptimeLabel)  { $TxtSidebarUptimeLabel.Text  = if ($isEn) { "Uptime:" } else { "Thời gian chạy:" } }
    if ($BtnQuickToggleAuto) {
        if ($Global:IsAutoSwitchRunning) {
            $BtnQuickToggleAuto.Content = if ($isEn) { "Disable Auto" } else { "Tắt Tự Động" }
        } else {
            $BtnQuickToggleAuto.Content = if ($isEn) { "Enable Auto" } else { "Bật Tự Động" }
        }
    }

    # 3. Update Dashboard Tab
    if ($BtnDashboardTestNow)     { $BtnDashboardTestNow.Content = if ($isEn) { "⚡ Test Network Now" } else { "⚡ Đo Kiểm Tra Ngay" } }

    # 4. Update Smart Switch Tab
    if ($TxtProfilesHeader)       { $TxtProfilesHeader.Text       = if ($isEn) { "QUICK OPTIMIZATION PROFILES (PRESETS)" } else { "CHẾ ĐỘ TỐI ƯU HÓA NHANH (PROFILES)" } }
    if ($TxtProfileGamingDesc)    { $TxtProfileGamingDesc.Text    = if ($isEn) { "Ultra-sensitive: Ping > 80ms or Packet Loss > 5%." } else { "Đổi mạng siêu nhạy: Ping > 80ms hoặc Mất gói > 5%." } }
    if ($TxtProfileStandardTitle) { $TxtProfileStandardTitle.Text = if ($isEn) { "Office & 4K Streaming" } else { "Văn Phòng & Phim Ảnh" } }
    if ($TxtProfileStandardDesc)  { $TxtProfileStandardDesc.Text  = if ($isEn) { "Balanced: Ping > 150ms or Signal < 40%." } else { "Cân bằng tối ưu: Ping > 150ms hoặc Sóng < 40%." } }
    if ($TxtProfileSavingTitle)   { $TxtProfileSavingTitle.Text   = if ($isEn) { "Battery Saver & Stable" } else { "Tiết Kiệm & Ổn Định" } }
    if ($TxtProfileSavingDesc)    { $TxtProfileSavingDesc.Text    = if ($isEn) { "Conservative: Only switch on disconnect or Signal < 25%." } else { "Hạn chế đổi: Chỉ đổi khi mất kết nối hoặc Sóng < 25%." } }

    if ($TxtCustomCriteriaTitle)  { $TxtCustomCriteriaTitle.Text  = if ($isEn) { "CUSTOM AUTO-SWITCH THRESHOLDS" } else { "TÙY CHỈNH THÔNG SỐ TỰ ĐỘNG CHUYỂN MẠNG" } }
    if ($TxtLblMaxPing)           { $TxtLblMaxPing.Text           = if ($isEn) { "1. Maximum allowed Ping latency (ms):" } else { "1. Ngưỡng độ trễ tối đa (Ping Ms):" } }
    if ($TxtLblMinSpeed)          { $TxtLblMinSpeed.Text          = if ($isEn) { "2. Minimum desired download speed (Mbps):" } else { "2. Ngưỡng tốc độ tải tối thiểu (Mbps):" } }
    if ($TxtLblMinSignal)         { $TxtLblMinSignal.Text         = if ($isEn) { "3. Minimum acceptable signal strength (%):" } else { "3. Ngưỡng tín hiệu sóng tối thiểu (%):" } }
    if ($TxtLblMaxLoss)           { $TxtLblMaxLoss.Text           = if ($isEn) { "4. Maximum acceptable packet loss (%):" } else { "4. Tỷ lệ mất gói tin tối đa (%):" } }
    if ($TxtLblInterval)          { $TxtLblInterval.Text          = if ($isEn) { "5. Automated check interval (seconds):" } else { "5. Chu kỳ quét kiểm tra mạng (giây):" } }
    if ($TxtLblCooldown)          { $TxtLblCooldown.Text          = if ($isEn) { "6. Cooldown duration between switches (seconds):" } else { "6. Thời gian nghỉ chống nhảy mạng (Cooldown giây):" } }
    if ($TxtCriteriaNotice)       { $TxtCriteriaNotice.Text       = if ($isEn) { "* System only switches to Wi-Fi networks previously saved on this PC." } else { "* Hệ thống chỉ tự động chuyển sang Wi-Fi đã từng kết nối thành công trên máy tính." } }
    if ($BtnSaveSmartCriteria)    { $BtnSaveSmartCriteria.Content = if ($isEn) { "💾 Save Settings Now" } else { "💾 Lưu Cài Đặt Ngay" } }

    # 5. Update Radar Tab
    if ($TxtRadarTitle)           { $TxtRadarTitle.Text           = if ($isEn) { "LIVE WI-FI SPECTRUM RADAR SCANNER" } else { "RADAR QUÉT TOÀN BỘ SÓNG WI-FI XUNG QUANH" } }
    if ($BtnRadarRefresh)         { $BtnRadarRefresh.Content       = if ($isEn) { "🔄 Rescan Wi-Fi Networks" } else { "🔄 Quét Lại Sóng Ngay" } }

    # 6. Update Analytics Tab
    if ($TxtKpiSwitchesHeader)    { $TxtKpiSwitchesHeader.Text    = if ($isEn) { "RESCUE SWITCHES" } else { "TỰ ĐỔI CỨU MẠNG" } }
    if ($TxtKpiAvgPingHeader)     { $TxtKpiAvgPingHeader.Text     = if ($isEn) { "AVERAGE PING" } else { "ĐỘ TRỄ TRUNG BÌNH" } }
    if ($TxtKpiUptimeHeader)      { $TxtKpiUptimeHeader.Text      = if ($isEn) { "UPTIME RATIO" } else { "TỶ LỆ KẾT NỐI ONLINE" } }
    if ($TxtKpiCurrentNetHeader)  { $TxtKpiCurrentNetHeader.Text  = if ($isEn) { "PROTECTED NETWORK" } else { "MẠNG ĐANG BẢO VỆ" } }
    if ($TxtAnalyticsTitle)       { $TxtAnalyticsTitle.Text       = if ($isEn) { "REALTIME LIVE AUDIT LOGS" } else { "NHẬT KÝ HOẠT ĐỘNG THỜI GIAN THỰC (LIVE AUDIT LOGS)" } }
    if ($BtnExportLogs)           { $BtnExportLogs.Content         = if ($isEn) { "📥 Export Report (CSV)" } else { "📥 Xuất Báo Cáo (CSV)" } }
    if ($BtnClearLogs)            { $BtnClearLogs.Content          = if ($isEn) { "Clear Logs" } else { "Xóa Nhật Ký" } }

    # 7. Update Settings Tab
    if ($TxtSettingsHeader)       { $TxtSettingsHeader.Text       = if ($isEn) { "ADVANCED SYSTEM SETTINGS" } else { "THIẾT LẬP NÂNG CAO CHO HỆ THỐNG" } }
    if ($TxtSettingsLangLabel)    { $TxtSettingsLangLabel.Text    = if ($isEn) { "Interface Language / Ngôn ngữ:" } else { "Ngôn ngữ giao diện (Language):" } }
    if ($CbSettingsAutoStart)     { $CbSettingsAutoStart.Content  = if ($isEn) { "Launch automatically in background on Windows startup (Recommended)" } else { "Tự động khởi động ngầm cùng Windows (Khuyên dùng)" } }
    if ($CbSettingsMiniHUD)       { $CbSettingsMiniHUD.Content    = if ($isEn) { "Always show floating desktop widget (Mini HUD Desktop Widget)" } else { "Luôn hiển thị Bảng Nhỏ nổi trên màn hình (Mini HUD Desktop Widget)" } }
    if ($CbSettingsPlaySound)     { $CbSettingsPlaySound.Content  = if ($isEn) { "Play audio chime notification when auto-switching Wi-Fi" } else { "Phát âm thanh thông báo tinh tế khi tự động chuyển mạng" } }
    if ($CbSettingsShowNotify)    { $CbSettingsShowNotify.Content = if ($isEn) { "Show desktop system tray balloon notifications for network events" } else { "Bật thông báo khay hệ thống (Windows Balloon Notification)" } }
    if ($CbSettingsMinimizeClose) { $CbSettingsMinimizeClose.Content = if ($isEn) { "Minimize to system tray when clicking close (✕) instead of quitting" } else { "Khi bấm nút đóng (✕), tự động thu nhỏ xuống khay thay vì tắt tool" } }
    if ($TxtSettingsPingHostLabel){ $TxtSettingsPingHostLabel.Text= if ($isEn) { "Target Ping Host (DNS):" } else { "Máy chủ kiểm tra Ping (DNS):" } }
    if ($TxtSettingsSpeedUrlLabel){ $TxtSettingsSpeedUrlLabel.Text= if ($isEn) { "SpeedTest Download URL:" } else { "Đường dẫn kiểm tra SpeedTest:" } }
    if ($TxtAuthorHeader)         { $TxtAuthorHeader.Text         = if ($isEn) { "AUTHOR & VERSION INFO" } else { "THÔNG TIN TÁC GIẢ & PHIÊN BẢN" } }
    if ($TxtAuthorDesc)           { $TxtAuthorDesc.Text           = if ($isEn) { "Intelligent Wi-Fi latency monitoring & auto-switching system for Windows." } else { "Hệ thống tự động giám sát độ trễ & chuyển đổi Wi-Fi thông minh trên Windows." } }
    if ($BtnSaveAllSettings)      { $BtnSaveAllSettings.Content   = if ($isEn) { "💾 Save System Settings" } else { "💾 Lưu Cấu Hình Hệ Thống" } }

    # Settings Language Button styles
    $primaryBtnBg   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2563EB")
    $secondaryBtnBg = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E293B")
    $whiteFg        = [System.Windows.Media.Brushes]::White
    $mutedFg        = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#94A3B8")

    if ($BtnLangVi -and $BtnLangEn) {
        if ($isEn) {
            $BtnLangEn.Background = $primaryBtnBg
            $BtnLangEn.Foreground = $whiteFg
            $BtnLangVi.Background = $secondaryBtnBg
            $BtnLangVi.Foreground = $mutedFg
        } else {
            $BtnLangVi.Background = $primaryBtnBg
            $BtnLangVi.Foreground = $whiteFg
            $BtnLangEn.Background = $secondaryBtnBg
            $BtnLangEn.Foreground = $mutedFg
        }
    }

    # 8. Update System Tray Menu
    if ($menuShow) { $menuShow.Text = if ($isEn) { "Open Control Dashboard" } else { "Mở Bảng Điều Khiển Pro" } }
    if ($menuHud)  { $menuHud.Text  = if ($isEn) { "Toggle Mini Widget (HUD)" } else { "Hiện / Ẩn Bảng Nhỏ (HUD)" } }
    if ($menuAuto) { $menuAuto.Text = if ($isEn) { "Toggle Auto Switch" } else { "Bật / Tắt Tự Động Đổi Mạng" } }
    if ($menuExit) { $menuExit.Text = if ($isEn) { "Exit WiFi Auto Switcher" } else { "Thoát Hoàn Toàn Ứng Dụng" } }

    # Refresh Profile buttons text based on language
    if ($Global:Config.ActiveProfile) {
        Set-ActiveProfile $Global:Config.ActiveProfile $false
    }

    # Save to config.json
    try {
        $Global:Config | ConvertTo-Json -Depth 4 | Set-Content -Path $ConfigFile -Encoding UTF8
    } catch { }

    Add-AuditLog $(if ($isEn) { "Interface language set to: English." } else { "Đã chuyển đổi ngôn ngữ giao diện: Tiếng Việt." }) "SYSTEM"
}

function Toggle-Language {
    if ($Global:Config.Language -eq "en") {
        Apply-Language "vi"
    } else {
        Apply-Language "en"
    }
}

$BtnApplyProfileGaming.Add_Click({ Set-ActiveProfile "Gaming" $true })
$CardProfileGaming.Add_MouseLeftButtonDown({ Set-ActiveProfile "Gaming" $true })

$BtnApplyProfileStandard.Add_Click({ Set-ActiveProfile "Standard" $true })
$CardProfileStandard.Add_MouseLeftButtonDown({ Set-ActiveProfile "Standard" $true })

$BtnApplyProfileSaving.Add_Click({ Set-ActiveProfile "Saving" $true })
$CardProfileSaving.Add_MouseLeftButtonDown({ Set-ActiveProfile "Saving" $true })

$BtnTitleLang.Add_Click({ Toggle-Language })
$BtnLangVi.Add_Click({ Apply-Language "vi" })
$BtnLangEn.Add_Click({ Apply-Language "en" })

$BtnSaveSmartCriteria.Add_Click({
    try {
        $Global:Config.MaxPingMs            = [int]$TbMaxPing.Text
        $Global:Config.MinSpeedMbps         = [double]$TbMinSpeed.Text
        $Global:Config.MinSignalPercent     = [int]$TbMinSignal.Text
        $Global:Config.MaxPacketLossPercent = [int]$TbMaxLoss.Text
        $Global:Config.CheckIntervalSeconds = [int]$TbInterval.Text
        $Global:Config.CooldownSeconds      = [int]$TbCooldown.Text

        $Global:Config | ConvertTo-Json -Depth 4 | Set-Content -Path $ConfigFile -Encoding UTF8
        Add-AuditLog "Đã lưu cài đặt thông số chuyển mạng mới vào config.json." "SUCCESS"
        [System.Windows.MessageBox]::Show("Đã lưu các thông số tự động chuyển mạng thành công!", "Thông Báo Pro", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        [System.Windows.MessageBox]::Show("Lỗi khi lưu thông số: $($_.Exception.Message)", "Lỗi", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$BtnSaveAllSettings.Add_Click({
    try {
        $Global:Config.AutoStartWithWindows    = [bool]$CbSettingsAutoStart.IsChecked
        $Global:Config.ShowMiniWidget          = [bool]$CbSettingsMiniHUD.IsChecked
        $Global:Config.PlaySoundOnSwitch       = [bool]$CbSettingsPlaySound.IsChecked
        $Global:Config.ShowNotifications       = [bool]$CbSettingsShowNotify.IsChecked
        $Global:Config.MinimizeToTrayOnClose   = [bool]$CbSettingsMinimizeClose.IsChecked
        $Global:Config.TargetPingHost          = $TbSettingsPingHost.Text.Trim()
        $Global:Config.SpeedTestUrl            = $TbSettingsSpeedUrl.Text.Trim()

        Set-StartupRegistry ($Global:Config.AutoStartWithWindows)

        if ($Global:Config.ShowMiniWidget) { $miniWindow.Show() } else { $miniWindow.Hide() }

        $Global:Config | ConvertTo-Json -Depth 4 | Set-Content -Path $ConfigFile -Encoding UTF8
        Add-AuditLog "Đã lưu toàn bộ cấu hình hệ thống nâng cao thành công." "SUCCESS"
        [System.Windows.MessageBox]::Show("Đã lưu cài đặt cấu hình hệ thống thành công!", "Thông Báo Pro", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        [System.Windows.MessageBox]::Show("Lỗi khi lưu cấu hình: $($_.Exception.Message)", "Lỗi", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

# Xuất file báo cáo CSV
$BtnExportLogs.Add_Click({
    try {
        $Global:EventLogsList | Export-Csv -Path $LogExportFile -NoTypeInformation -Encoding UTF8
        Add-AuditLog "Đã xuất báo cáo sự kiện ra file: $LogExportFile" "SUCCESS"
        [System.Windows.MessageBox]::Show("Đã xuất báo cáo sự kiện thành công tại:`n$LogExportFile", "Báo Cáo Pro", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        [System.Windows.MessageBox]::Show("Lỗi khi xuất file báo cáo: $($_.Exception.Message)", "Lỗi", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

# Xóa nhật ký
$BtnClearLogs.Add_Click({
    $TbAnalyticsLogs.Clear()
    $Global:EventLogsList.Clear()
})

# ==================== VÒNG LẶP TIMER GIÁM SÁT REALTIME ====================

$monitorTimer = New-Object System.Windows.Threading.DispatcherTimer
$monitorTimer.Interval = [TimeSpan]::FromSeconds($Global:Config.CheckIntervalSeconds)
$monitorTimer.Add_Tick({
    if ($monitorTimer.Interval.TotalSeconds -ne $Global:Config.CheckIntervalSeconds) {
        $monitorTimer.Interval = [TimeSpan]::FromSeconds($Global:Config.CheckIntervalSeconds)
    }
    Execute-MonitoringCycle
})

# Khởi tạo Application Lifecycle chuẩn cho Tray App
$app = [System.Windows.Application]::Current
if (-not $app) {
    $app = New-Object System.Windows.Application
}
$app.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown

$isSilentStart = ($Global:AppCliArgs -contains "--minimized" -or $Global:AppCliArgs -contains "--tray" -or $Global:AppCliArgs -contains "--startup")

$window.Add_Loaded({
    Add-AuditLog "Khởi động thành công WiFi Auto Switcher Pro Enterprise Edition v2.5." "SYSTEM"
    Add-AuditLog "Chế độ bảo vệ tự động đang hoạt động ngầm. Chu kỳ quét: $($Global:Config.CheckIntervalSeconds)s." "SYSTEM"
    
    # Khởi tạo trạng thái Profile trực quan đúng với config.json
    try {
        Set-ActiveProfile $Global:Config.ActiveProfile $false
    } catch { }

    if ($Global:Config.ShowMiniWidget) {
        $miniWindow.Show()
        $BtnTitleMiniHUD.Content = "✕ Ẩn Bảng Nhỏ"
    } else {
        $BtnTitleMiniHUD.Content = "📌 Bảng Nhỏ (HUD)"
    }

    $monitorTimer.Start()
    Execute-MonitoringCycle -forceCheck $true
})

if ($isSilentStart) {
    if ($Global:Config.ShowMiniWidget) {
        $miniWindow.Show()
    }
    $monitorTimer.Start()
    Execute-MonitoringCycle -forceCheck $true
    [void]$app.Run()
} else {
    [void]$app.Run($window)
}

# Dọn dẹp tài nguyên khi thoát
if ($notifyIcon) {
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
}
if ($miniWindow) {
    $miniWindow.Close()
}
