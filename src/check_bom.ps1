$enc = New-Object System.Text.UTF8Encoding($true)
$projectRoot = Split-Path -Parent $PSScriptRoot
$paths = @(
    (Join-Path $projectRoot "WifiSwitcherApp.ps1"),
    (Join-Path $PSScriptRoot "WifiSwitcherApp.ps1"),
    (Join-Path $PSScriptRoot "test_simulation.ps1")
)

foreach ($p in $paths) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        throw "PowerShell source file not found: $p"
    }

    $content = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($p, $content, $enc)

    $errors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$tokens, [ref]$errors)
    Write-Host ("Path: {0} -> Errors count: {1}" -f (Split-Path $p -Leaf), $errors.Count)
    if ($errors.Count -gt 0) {
        foreach ($e in $errors) {
            Write-Host ("  Line {0}: {1}" -f $e.Extent.StartLineNumber, $e.Message)
        }
        exit 1
    }
}
