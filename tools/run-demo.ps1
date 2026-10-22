# Starts OnAirKey from source with a separate demo config, for trying it out during development.
#   powershell -ExecutionPolicy Bypass -File tools\run-demo.ps1
# The demo config lives in %TEMP%\onairkey-demo and uses Caps Lock as the indicator, so it does
# not interfere with another setup driving Scroll Lock. Changes saved in the demo stay there.
# -Reset starts from a fresh config (first-run experience).
param([switch]$Reset)

$ahk = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$root = Split-Path $PSScriptRoot -Parent
$dir = Join-Path $env:TEMP 'onairkey-demo'
$cfg = Join-Path $dir 'config.ini'

if ($Reset) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force $dir | Out-Null
if (-not (Test-Path $cfg)) {
    [IO.File]::WriteAllText($cfg, "[Indicator]`r`nLock=CapsLock`r`n[General]`r`nDebug=1`r`n", [Text.Encoding]::Unicode)
}

# Only one demo at a time
Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe'" |
    Where-Object { $_.CommandLine -like "*OnAirKey.ahk*$dir*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Start-Process $ahk -ArgumentList "`"$root\src\OnAirKey.ahk`"", '--config', "`"$cfg`""
Write-Host "OnAirKey demo started (config: $cfg)"
