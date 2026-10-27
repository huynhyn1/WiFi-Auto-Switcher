param(
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

$requiredFiles = @(
    "Setup.exe",
    "WiFiAutoSwitcher.exe",
    "WifiSwitcherApp.ps1",
    "config.json",
    "app.ico",
    "HUONG-DAN-SU-DUNG.html",
    "README.md",
    "LICENSE"
)

foreach ($file in $requiredFiles) {
    $sourcePath = Join-Path $projectRoot $file
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required release file not found: $sourcePath"
    }
}

$fileVersion = (Get-Item (Join-Path $projectRoot "WiFiAutoSwitcher.exe")).VersionInfo.FileVersion
try {
    $version = [version]$fileVersion
} catch {
    throw "Could not read a valid version from WiFiAutoSwitcher.exe: '$fileVersion'"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputDirectory = Join-Path $projectRoot "dist"
    $OutputPath = Join-Path $outputDirectory ("WiFi-Auto-Switcher-v{0}.{1}-Windows.zip" -f $version.Major, $version.Minor)
} else {
    $OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    $outputDirectory = Split-Path -Parent $OutputPath
}

if ([string]::IsNullOrWhiteSpace($outputDirectory)) {
    throw "OutputPath must include a directory."
}

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wifi-auto-switcher-" + [guid]::NewGuid().ToString("N"))
$packageDirectory = Join-Path $stagingRoot ("WiFi-Auto-Switcher-v{0}.{1}-Windows" -f $version.Major, $version.Minor)

try {
    New-Item -ItemType Directory -Path $packageDirectory -Force | Out-Null
    foreach ($file in $requiredFiles) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination $packageDirectory
    }

    Compress-Archive -Path $packageDirectory -DestinationPath $OutputPath -CompressionLevel Optimal -Force
    Write-Output "Release package created: $OutputPath"
} finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}
