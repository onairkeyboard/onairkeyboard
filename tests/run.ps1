# Runs syntax validation and all test scripts. Exit code 0 when everything passes.
#   powershell -ExecutionPolicy Bypass -File tests\run.ps1 [-Exe]
# -Exe also runs the integration test against dist\OnAirKeyboard-<version>.exe (build it first with build.ps1).
param([switch]$Exe)
$ErrorActionPreference = 'Stop'
$ahk = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$root = Split-Path $PSScriptRoot -Parent
$failed = 0

& $ahk /Validate /ErrorStdOut (Join-Path $root 'src\OnAirKeyboard.ahk') 2>&1 | Out-String | Write-Host
if ($LASTEXITCODE -ne 0) { Write-Host 'validate FAILED'; $failed++ } else { Write-Host 'validate ok' }

$runs = @(
    @{ Name = 'TestCore'; Args = @() },
    @{ Name = 'TestShortcuts'; Args = @() },
    @{ Name = 'TestMic'; Args = @() },
    @{ Name = 'TestDuck'; Args = @() },
    @{ Name = 'TestIntegration'; Args = @() }
)
if ($Exe) {
    $version = (Select-String -Path (Join-Path $root 'src\App.ahk') -Pattern 'static Version := "(.+)"').Matches[0].Groups[1].Value
    $exePath = Join-Path $root "dist\OnAirKeyboard-$version.exe"
    if (-not (Test-Path $exePath)) { throw "Missing $exePath, run build.ps1 first" }
    $runs += @{ Name = 'TestIntegration'; Args = @('--exe', "`"$exePath`""); Label = 'TestIntegration (EXE)' }
}

foreach ($run in $runs) {
    $label = if ($run.Label) { $run.Label } else { $run.Name }
    $out = Join-Path $env:TEMP "onairkeyboard-$($run.Name).out"
    $argList = @('/ErrorStdOut', "`"$(Join-Path $root "tests\$($run.Name).ahk")`"") + $run.Args
    $p = Start-Process $ahk -ArgumentList $argList -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError "$out.err"
    $null = $p.Handle  # caches the handle; without it ExitCode stays empty
    if (-not $p.WaitForExit(300000)) { Stop-Process -Id $p.Id -Force; Write-Host "$label TIMEOUT"; $failed++; continue }
    Write-Host "== $label"
    Get-Content $out, "$out.err" -ErrorAction SilentlyContinue | Where-Object { $_ -notlike 'target: *' } | Write-Host
    if ($p.ExitCode -ne 0) { $failed++ }
}

# Leftover test instances of the app, if a test died midway
Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe' OR Name='OnAirKeyboard.exe'" |
    Where-Object { $_.CommandLine -like '*--config*onairkeyboard-*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

exit $failed
