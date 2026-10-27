@echo off
title Tao Shortcut ra Desktop
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$w = New-Object -ComObject WScript.Shell; $d = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop); $s = $w.CreateShortcut($d + '\WiFi Auto Switcher.lnk'); $s.TargetPath = 'wscript.exe'; $s.Arguments = '\"%~dp0Start-Silent.vbs\"'; $s.WorkingDirectory = '%~dp0'; $s.Description = 'WiFi Auto Switcher Pro'; $s.Save(); Write-Host 'DA TAO SHORTCUT RA MAN HINH DESKTOP THANH CONG!'"
pause
