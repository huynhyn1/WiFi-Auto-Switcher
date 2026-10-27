@echo off
title Cai dat Tu dong chay cung Windows
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$w = New-Object -ComObject WScript.Shell; $s = $w.CreateShortcut([Environment]::GetFolderPath([Environment+SpecialFolder]::Startup) + '\WiFiAutoSwitcherPro.lnk'); $s.TargetPath = 'wscript.exe'; $s.Arguments = '\"%~dp0Start-Silent.vbs\"'; $s.WorkingDirectory = '%~dp0'; $s.Description = 'WiFi Auto Switcher Pro Background Service'; $s.Save(); Write-Host 'DA CAI DAT TU DONG KHOI DONG CUNG WINDOWS THANH CONG!'"
pause
