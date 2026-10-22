#Requires AutoHotkey v2.0
; End-to-end test: starts OnAirKey with a temporary config and drives it with simulated keys.
; Uses Caps Lock as the indicator and Ctrl+Shift+F20..F22, which neither Wispr Flow nor the
; legacy script listen to. Keys are sent with SendLevel 1 so OnAirKey's hotkeys see them.
; Run: AutoHotkey64.exe /ErrorStdOut tests\TestIntegration.ahk

#Include %A_LineFile%\..\TestLib.ahk

dir := A_Temp "\onairkey-integration"
try DirDelete(dir, true)
DirCreate(dir)
FileAppend("
(
[Shortcuts]
PushToTalk=Ctrl+Shift+F20
HandsFree=Ctrl+Shift+F21
Cancel=Ctrl+Shift+F22
[Indicator]
Lock=CapsLock
[General]
Debug=1
[Advanced]
SyncIntervalMs=50
ResyncDelayMs=0
HookReinstallDelaysMs=
)", dir "\config.ini", "UTF-16")

SetCapsLockState(false)
Run('"' A_AhkPath '" "' A_LineFile '\..\..\src\OnAirKey.ahk" --config "' dir '\config.ini"', , , &pid)
Sleep(1500)

SendLevel(1)
Caps() => GetKeyState("CapsLock", "T")
Tap(key) {
    Send("{Ctrl down}{Shift down}{" key " down}")
    Sleep(60)
    Send("{" key " up}{Shift up}{Ctrl up}")
    Sleep(250)
}

Check("idle off", Caps(), 0)

Send("{Ctrl down}{Shift down}{F20 down}")
Sleep(250)
Check("ptt held on", Caps(), 1)
Send("{F20 up}{Shift up}{Ctrl up}")
Sleep(250)
Check("ptt released off", Caps(), 0)

Tap("F21")
Check("hands-free on", Caps(), 1)
Tap("F21")
Check("hands-free off", Caps(), 0)

Tap("F21")
Tap("F22")
Check("cancel off", Caps(), 0)

Send("{Ctrl down}{F20 down}")
Sleep(250)
Check("wrong modifiers ignored", Caps(), 0)
Send("{F20 up}{Ctrl up}")
Sleep(150)

; Auto-repeat while holding the hands-free shortcut must toggle only once
Send("{Ctrl down}{Shift down}{F21 down}")
Loop 5 {
    Sleep(40)
    Send("{F21 down}")
}
Send("{F21 up}{Shift up}{Ctrl up}")
Sleep(250)
Check("auto-repeat toggles once", Caps(), 1)
Tap("F22")
Check("cleanup off", Caps(), 0)

DetectHiddenWindows(true)
WinClose("ahk_class AutoHotkey ahk_pid " pid)
Check("exits cleanly", ProcessWaitClose(pid, 3), 0)
SetCapsLockState(false)
Out(FileRead(dir "\onairkey.log"))
Finish()
