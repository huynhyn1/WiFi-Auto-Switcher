# Script tao file ZIP phat hanh WiFi Auto Switcher Pro v2.5
# Tac gia: S.Nova

$zipPath = 'c:\Users\SuperNova\Desktop\WiFi-Auto-Switcher-Pro-v2.5.zip'
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$tempDir = Join-Path $env:TEMP ('wifi_dist_' + [guid]::NewGuid().ToString().Substring(0,8))
$pkgDir = Join-Path $tempDir 'WiFi_Auto_Switcher'
New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null

Copy-Item 'c:\Users\SuperNova\Desktop\WiFi_Auto_Switcher\WiFiAutoSwitcher.exe' -Destination $pkgDir -Force
Copy-Item 'c:\Users\SuperNova\Desktop\WiFi_Auto_Switcher\Setup.exe' -Destination $pkgDir -Force
Copy-Item 'c:\Users\SuperNova\Desktop\WiFi_Auto_Switcher\config.json' -Destination $pkgDir -Force
Copy-Item 'c:\Users\SuperNova\Desktop\WiFi_Auto_Switcher\app.ico' -Destination $pkgDir -Force
Copy-Item 'c:\Users\SuperNova\Desktop\WiFi_Auto_Switcher\HUONG-DAN-SU-DUNG.html' -Destination $pkgDir -Force
Copy-Item 'c:\Users\SuperNova\Desktop\WiFi_Auto_Switcher\README.md' -Destination $pkgDir -Force
Copy-Item 'c:\Users\SuperNova\Desktop\WiFi_Auto_Switcher\src' -Destination $pkgDir -Recurse -Force

Compress-Archive -Path $pkgDir -DestinationPath $zipPath -CompressionLevel Optimal
Remove-Item -Path $tempDir -Recurse -Force

$item = Get-Item $zipPath
Write-Host "ZIP created successfully: $($item.FullName) - $($item.Length) bytes"
