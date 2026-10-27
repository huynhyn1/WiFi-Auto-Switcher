@echo off
title Khoi dong WiFi Auto Switcher Pro Enterprise
cd /d "%~dp0"
echo ========================================================
echo   DANG KHOI DONG WIFI AUTO SWITCHER PRO ENTERPRISE v2.5...
echo ========================================================
start "" powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0WifiSwitcherApp.ps1"
exit
