Set WshShell = CreateObject("WScript.Shell")
strPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
WshShell.Run "powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File """ & strPath & "\WifiSwitcherApp.ps1""", 0, False
Set WshShell = Nothing
