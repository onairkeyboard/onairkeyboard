# Runs syntax validation and all test scripts. Exit code 0 when everything passes.
#   powershell -ExecutionPolicy Bypass -File tests\run.ps1
$ErrorActionPreference = 'Stop'
$ahk = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$root = Split-Path $PSScriptRoot -Parent
$failed = 0

& $ahk /Validate /ErrorStdOut (Join-Path $root 'src\OnAirKey.ahk') 2>&1 | Out-String | Write-Host
if ($LASTEXITCODE -ne 0) { Write-Host 'validate FAILED'; $failed++ } else { Write-Host 'validate ok' }

foreach ($test in 'TestCore', 'TestShortcuts', 'TestIntegration') {
    $out = Join-Path $env:TEMP "onairkey-$test.out"
    $p = Start-Process $ahk -ArgumentList '/ErrorStdOut', (Join-Path $root "tests\$test.ahk") `
        -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError "$out.err"
    $null = $p.Handle  # caches the handle; without it ExitCode stays empty
    if (-not $p.WaitForExit(60000)) { Stop-Process -Id $p.Id -Force; Write-Host "$test TIMEOUT"; $failed++; continue }
    Write-Host "== $test"
    Get-Content $out, "$out.err" -ErrorAction SilentlyContinue | Write-Host
    if ($p.ExitCode -ne 0) { $failed++ }
}

# Leftover test instances of the app, if a test died midway
Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe'" |
    Where-Object { $_.CommandLine -like '*OnAirKey\src\OnAirKey.ahk*--config*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

exit $failed
