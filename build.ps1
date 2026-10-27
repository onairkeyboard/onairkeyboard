# Builds dist\OnAirKeyboard-<version>.exe with Ahk2Exe (AutoHotkey v2, 64-bit base).
#   powershell -ExecutionPolicy Bypass -File build.ps1          # next patch: 0.2.0 -> 0.2.1
#   powershell -ExecutionPolicy Bypass -File build.ps1 -Minor   # next minor: 0.2.4 -> 0.3.0
# Every build gets a version of its own, so two different EXEs never share a number: the script
# raises the version in App.Version and the compiler directives, commits it ("Build 0.2.1") and
# builds that commit. It refuses to run with uncommitted changes, so every build matches a
# commit. A release publishes one of these builds as it is (the patch number may skip).
# The version in the file name is for the download only: the self-install always copies the EXE
# to OnAirKeyboard.exe, so shortcuts, autostart and updates keep one path.
param([switch]$Minor)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$ahk2exe = 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe'
$base = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$src = Join-Path $root 'src\OnAirKeyboard.ahk'
$appFile = Join-Path $root 'src\App.ahk'
$dist = Join-Path $root 'dist'

$appVersion = (Select-String -Path $appFile -Pattern 'static Version := "(.+)"').Matches[0].Groups[1].Value
$exeVersion = (Select-String -Path $src -Pattern ';@Ahk2Exe-SetVersion (.+)').Matches[0].Groups[1].Value.Trim()
if ($appVersion -ne $exeVersion) { throw "Version mismatch: App.Version $appVersion, Ahk2Exe-SetVersion $exeVersion" }

$dirty = git -C $root status --porcelain
if ($LASTEXITCODE -ne 0) { throw 'git status failed' }
if ($dirty) { throw "Uncommitted changes: commit them first, so the build matches a commit.`n$($dirty -join "`n")" }

$v = [version]$appVersion
$version = if ($Minor) { "$($v.Major).$($v.Minor + 1).0" } else { "$($v.Major).$($v.Minor).$($v.Build + 1)" }
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Set-Version($path, $pattern, $replacement) {
    $text = [IO.File]::ReadAllText($path)
    $new = [regex]::Replace($text, $pattern, $replacement)
    if ($new -eq $text) { throw "Version not found in $path" }
    [IO.File]::WriteAllText($path, $new, $utf8)
}
Set-Version $appFile 'static Version := "[^"]+"' "static Version := `"$version`""
Set-Version $src ';@Ahk2Exe-Set(Product)?Version [^\r\n]+' ";@Ahk2Exe-Set`$1Version $version"
git -C $root commit --quiet -m "Build $version" -- $appFile $src
if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
Write-Host "Version $appVersion -> $version (committed)"

$exe = Join-Path $dist "OnAirKeyboard-$version.exe"
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
