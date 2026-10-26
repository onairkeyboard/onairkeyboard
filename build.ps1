# Builds dist\OnAirKeyboard-<version>.exe with Ahk2Exe (AutoHotkey v2, 64-bit base).
#   powershell -ExecutionPolicy Bypass -File build.ps1
# Fails if the version in the compiler directives differs from App.Version.
# The version in the file name is for the download only: the self-install always copies the EXE
# to OnAirKeyboard.exe, so shortcuts, autostart and updates keep one path.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$ahk2exe = 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe'
$base = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$src = Join-Path $root 'src\OnAirKeyboard.ahk'
$dist = Join-Path $root 'dist'

$appVersion = (Select-String -Path (Join-Path $root 'src\App.ahk') -Pattern 'static Version := "(.+)"').Matches[0].Groups[1].Value
$exeVersion = (Select-String -Path $src -Pattern ';@Ahk2Exe-SetVersion (.+)').Matches[0].Groups[1].Value.Trim()
if ($appVersion -ne $exeVersion) { throw "Version mismatch: App.Version $appVersion, Ahk2Exe-SetVersion $exeVersion" }
$exe = Join-Path $dist "OnAirKeyboard-$appVersion.exe"

New-Item -ItemType Directory -Force $dist | Out-Null
if (Test-Path $exe) { Remove-Item $exe }
# Requires Ahk2Exe 1.1.37+ (installed from AutoHotkey Dash > Compile). /silent reports errors
# on stdout instead of a dialog; the time limit guards against a dialog anyway.
$log = Join-Path $env:TEMP 'onairkeyboard-ahk2exe.log'
$p = Start-Process $ahk2exe -ArgumentList '/in', "`"$src`"", '/out', "`"$exe`"", '/base', "`"$base`"", '/silent', 'verbose' `
    -PassThru -NoNewWindow -RedirectStandardOutput $log
$null = $p.Handle
if (-not $p.WaitForExit(90000)) { Stop-Process -Id $p.Id -Force; throw 'Ahk2Exe timed out (probably an error dialog)' }
Get-Content $log -ErrorAction SilentlyContinue | Write-Host
if ($p.ExitCode -ne 0 -or -not (Test-Path $exe)) { throw "Ahk2Exe failed (exit $($p.ExitCode))" }

$info = (Get-Item $exe).VersionInfo
Write-Host "Built $exe ($([math]::Round((Get-Item $exe).Length / 1KB)) KB), version $($info.FileVersion)"
