# Opens the settings window of a temporary OnAirKey instance and saves a PNG of every tab.
#   powershell -ExecutionPolicy Bypass -File tools\screenshot-settings.ps1 -Language pl -OutDir <folder>
# The instance uses Caps Lock and test shortcuts, so it doesn't interfere with a running setup.
# -Showcase uses a clean, typical setup (for README images) instead of one that shows validation messages.
param([string]$Language = 'pl', [string]$OutDir = (Join-Path $env:TEMP 'onairkey-shots'), [switch]$Showcase)

$ErrorActionPreference = 'Stop'
$ahk = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$root = Split-Path $PSScriptRoot -Parent
New-Item -ItemType Directory -Force $OutDir | Out-Null

$dir = Join-Path $env:TEMP "onairkey-shot-$Language"
Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $dir | Out-Null
$cfg = Join-Path $dir 'config.ini'
if ($Showcase) {
    $shortcuts = "PushToTalk=Ctrl+Shift+F13`r`nHandsFree=Ctrl+Shift+F14`r`nCancel=Ctrl+Shift+F16`r`nCommandMode=`r`n"
} else {
    $shortcuts = "PushToTalk=Ctrl+Shift+F20`r`nHandsFree=Ctrl+Shift+F21`r`nCancel=Escape`r`nCommandMode=Ctrl+Shift+F20`r`n"
}
$ini = "[Shortcuts]`r`n$shortcuts[Indicator]`r`nLock=CapsLock`r`n[General]`r`nLanguage=$Language`r`n"
[IO.File]::WriteAllText($cfg, $ini, [Text.Encoding]::Unicode)

$app = Start-Process $ahk -ArgumentList "`"$root\src\OnAirKey.ahk`"", '--config', "`"$cfg`"" -PassThru
Start-Sleep -Seconds 2

# Helper: opens settings (first call) or switches to the next tab, then prints the window rectangle
$helper = Join-Path $dir 'helper.ahk'
@"
DetectHiddenWindows(true)
win := 'ahk_class AutoHotkeyGUI ahk_pid $($app.Id)'
if A_Args[1] = 'open' {
    PostMessage(0x8001, 3, 0, , 'ahk_class AutoHotkey ahk_pid $($app.Id)')
    WinWait(win, , 5)
    WinActivate(win)
    WinMove(40, 40, , , win)
} else {
    WinActivate(win)
    Send('^{Tab}')
}
Sleep(500)
; Visible frame only (WinGetPos would include the invisible resize borders of Windows 10)
rect := Buffer(16)
DllCall('dwmapi\DwmGetWindowAttribute', 'Ptr', WinExist(win), 'UInt', 9, 'Ptr', rect, 'UInt', 16)
x := NumGet(rect, 0, 'Int'), y := NumGet(rect, 4, 'Int')
w := NumGet(rect, 8, 'Int') - x, h := NumGet(rect, 12, 'Int') - y
FileAppend(x ' ' y ' ' w ' ' h, '*')
"@ | Set-Content $helper -Encoding UTF8

Add-Type -AssemblyName System.Drawing
for ($i = 1; $i -le 6; $i++) {
    $rect = (& $ahk $helper ($(if ($i -eq 1) { 'open' } else { 'next' })) | Out-String).Trim() -split ' '
    $x, $y, $w, $h = [int[]]$rect
    $bmp = New-Object Drawing.Bitmap $w, $h
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($x, $y, 0, 0, $bmp.Size)
    $file = Join-Path $OutDir "settings-$Language-$i.png"
    $bmp.Save($file)
    $g.Dispose(); $bmp.Dispose()
    Write-Host $file
}

Stop-Process -Id $app.Id -Force
