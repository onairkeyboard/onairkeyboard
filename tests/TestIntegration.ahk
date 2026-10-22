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

; Commands normally triggered from the tray menu (App.WM_COMMAND = 0x8001)
DetectHiddenWindows(true)
Command(cmd, lp := 0) => PostMessage(0x8001, cmd, lp, , "ahk_class AutoHotkey ahk_pid " pid)

Tap("F21")
Command(1)  ; pause
Sleep(250)
Check("pause turns off", Caps(), 0)
Tap("F21")
Check("paused ignores keys", Caps(), 0)
Command(1)  ; resume
Sleep(250)
Check("resume stays off", Caps(), 0)
Tap("F21")
Check("works after resume", Caps(), 1)
Tap("F22")

Command(2)  ; test LED: 3 blinks, 300 ms on / 300 ms off
Sleep(150)
Check("blink on", Caps(), 1)
Sleep(300)
Check("blink off", Caps(), 0)
Sleep(1600)
Check("blink ends off", Caps(), 0)

logText := FileRead(dir "\onairkey.log")
Check("tray icon goes red", InStr(logText, "tray icon tray-rec") > 0, true)
Check("tray icon back to idle", InStr(logText, "tray icon tray-idle") > 0, true)
Check("paused logged", InStr(logText, "paused") > 0, true)

; Settings window: record shortcuts with simulated keys, save, use them without a restart
settingsWin := "ahk_class AutoHotkeyGUI ahk_pid " pid
Command(3)
Sleep(800)
Check("settings window opens", WinExist(settingsWin) != 0, true)

Command(4, 1)  ; record push to talk
Sleep(300)
Send("{Ctrl down}{Shift down}{F23}{Shift up}{Ctrl up}")
Sleep(300)
Command(4, 3)  ; record cancel: Escape must be recorded, not close anything
Sleep(300)
Send("{Escape}")
Sleep(300)
Command(4, 2)  ; record hands-free as a modifier-only shortcut
Sleep(300)
Send("{Ctrl down}{Alt down}")
Sleep(60)
Send("{Alt up}{Ctrl up}")
Sleep(300)
Command(4, 4)  ; record command mode, press nothing: times out after 5 s
Sleep(5600)
Check("window still open after Escape", WinExist(settingsWin) != 0, true)
Command(5)     ; save
Sleep(1000)
Check("save closes window", WinExist(settingsWin) = 0, true)

cfgText := FileRead(dir "\config.ini", "UTF-16")
Check("saved push to talk", InStr(cfgText, "PushToTalk=Ctrl+Shift+F23`n") > 0, true)
Check("saved escape cancel", InStr(cfgText, "Cancel=Escape`n") > 0, true)
Check("saved modifier-only", InStr(cfgText, "HandsFree=Ctrl+Alt`n") > 0, true)
Check("timeout leaves empty", InStr(cfgText, "CommandMode=`n") > 0, true)

Send("{Ctrl down}{Shift down}{F23 down}")
Sleep(250)
Check("new ptt works", Caps(), 1)
Send("{F23 up}{Shift up}{Ctrl up}")
Sleep(250)
Check("new ptt released", Caps(), 0)
Send("{Ctrl down}{Alt down}")
Sleep(60)
Send("{Alt up}{Ctrl up}")
Sleep(250)
Check("modifier-only hands-free on", Caps(), 1)
Send("{Ctrl down}{Alt down}")
Sleep(60)
Send("{Alt up}{Ctrl up}")
Sleep(250)
Check("modifier-only hands-free off", Caps(), 0)

WinClose("ahk_class AutoHotkey ahk_pid " pid)
Check("exits cleanly", ProcessWaitClose(pid, 3), 0)
SetCapsLockState(false)
if failures
    Out(FileRead(dir "\onairkey.log"))

; First run (no config yet): settings open by themselves on "How it works";
; opening them again later shows "Shortcuts".
; Note: a fresh config uses Scroll Lock, so the keyboard LED may blink once here.
freshDir := A_Temp "\onairkey-firstrun"
try DirDelete(freshDir, true)
Run('"' A_AhkPath '" "' A_LineFile '\..\..\src\OnAirKey.ahk" --config "' freshDir '\config.ini"', , , &pid2)
firstWin := "ahk_class AutoHotkeyGUI ahk_pid " pid2
Check("first run opens settings", WinWait(firstWin, , 5) != 0, true)
Sleep(300)
Check("first run shows how it works", ControlGetIndex("SysTabControl321", firstWin), 1)
Check("first run creates config", FileExist(freshDir "\config.ini") != "", true)
WinClose(firstWin)
Sleep(300)
PostMessage(0x8001, 3, 0, , "ahk_class AutoHotkey ahk_pid " pid2)
Check("settings reopen", WinWait(firstWin, , 5) != 0, true)
Sleep(300)
Check("later opens shortcuts", ControlGetIndex("SysTabControl321", firstWin), 2)
WinClose("ahk_class AutoHotkey ahk_pid " pid2)
ProcessWaitClose(pid2, 3)

Finish()
