#Requires AutoHotkey v2.0
; End-to-end test: starts OnAir keyboard with a temporary config and drives it with simulated keys.
; Uses Caps Lock as the indicator and Ctrl+Shift+F20..F22, which neither Wispr Flow nor the
; legacy script listen to. Keys are sent with SendLevel 1 so OnAir keyboard's hotkeys see them.
; Run: AutoHotkey64.exe /ErrorStdOut tests\TestIntegration.ahk [--exe dist\OnAirKeyboard-<version>.exe]
; With --exe the compiled program is tested instead of the script.

#Include %A_LineFile%\..\TestLib.ahk
#Include %A_LineFile%\..\FakeMic.ahk
#Include %A_LineFile%\..\WindowLib.ahk

target := '"' A_AhkPath '" "' A_LineFile '\..\..\src\OnAirKeyboard.ahk"'
exePath := ""
for i, arg in A_Args
    if arg = "--exe" && i < A_Args.Length
        exePath := A_Args[i + 1], target := '"' exePath '"'
Out("target: " target)

; Every instance reads a fake microphone registry, so the user's dictation doesn't interfere
micArg := ' --mic-key "' FakeMic.Key '"'
FakeMic.Reset()

; Shortcuts only work while the Wispr helper runs, so a process that surely runs stands in
; for it: AutoHotkey running this test. signal: lines of the [Signal] and [Microphone] sections.
TestConfig(folder, helperProcess, signal := "Source=Shortcuts`nPauseInWisprWindow=0") {
    try DirDelete(folder, true)
    DirCreate(folder)
    FileAppend(Format("
    (
    [Signal]
    {2}
    [Shortcuts]
    PushToTalk=Ctrl+Shift+F20
    HandsFree=Ctrl+Shift+F21
    Cancel=Ctrl+Shift+F22
    [Indicator]
    Lock=CapsLock
    [General]
    Language=en
    Debug=1
    [Advanced]
    SyncIntervalMs=50
    ResyncDelayMs=0
    WisprHelperProcess={1}
    WisprAppProcess={1}
    HookReinstallDelaysMs=
    )", helperProcess, signal), folder "\config.ini", "UTF-16")
}

SplitPath(A_AhkPath, &ahkExe)
dir := A_Temp "\onairkeyboard-integration"
TestConfig(dir, ahkExe)

SetCapsLockState(false)
Run(target ' --config "' dir '\config.ini"' micArg, , , &pid)
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

logText := FileRead(dir "\onairkeyboard.log")
Check("tray icon goes red", InStr(logText, "tray icon tray-rec") > 0, true)
Check("tray icon back to idle", InStr(logText, "tray icon tray-idle") > 0, true)
Check("paused logged", InStr(logText, "paused") > 0, true)
Check("no runtime errors", InStr(logText, "ERROR"), 0)

; Settings window: record shortcuts with simulated keys, save, use them without a restart
; Waits until the app's log contains text (instead of guessing delays), up to timeoutMs
WaitLog(text, timeoutMs := 4000, logDir := "") {
    file := (logDir = "" ? dir : logDir) "\onairkeyboard.log"
    start := A_TickCount
    while A_TickCount - start < timeoutMs {
        try {  ; the app may be writing the log right now
            if InStr(FileRead(file), text)
                return true
        }
        Sleep(50)
    }
    return false
}

; The window (WebView2): checks run JavaScript in the page through a test command
appWin := "OnAir keyboard ahk_class AutoHotkeyGUI ahk_pid " pid
logFile := dir "\onairkeyboard.log"
Eval(js) => PageEval(pid, logFile, js)

; WebView2 processes of an earlier, killed instance may still be ending: only new ones count
webViewBefore := WebViewProcesses()

; Report a bug: the window shows the address and a prefilled text, no mail app involved
Command(6)
Check("bug report window opens", WinWait(appWin, , 5) != 0, true)
Check("window ready", WaitLog("window ready", 8000), true)
Sleep(300)
Check("bug report view", Eval("S.view"), '"bug"')
Check("bug report address", Eval("document.querySelector('.field .value').textContent"), '"hello@onairkeyboard.com"')
Check("bug report details", Eval("document.getElementById('body').value.includes('Cancel=Ctrl+Shift+F22')"), "true")
Check("page has no missing texts", Eval("[...document.body.querySelectorAll('*')].some(e => e.children.length === 0 && /^[a-z]+\.[a-z_.]+$/i.test(e.textContent.trim()))"), "false")
Command(7, 2)  ; the same window switches to the advanced view
Sleep(400)
Check("one window", WinGetList(appWin).Length, 1)
Check("advanced view", Eval("S.view"), '"advanced"')
Check("advanced has no missing texts", Eval("[...document.body.querySelectorAll('*')].some(e => e.children.length === 0 && /^[a-z]+\.[a-z_.]+$/i.test(e.textContent.trim()))"), "false")

; Assign shortcuts by pressing them; each one is saved and used at once
Eval("go('advanced', 'shortcuts'); send('assign', {action: 'PushToTalk'}); 1")
Check("assigning ptt starts", WaitLog("assigning shortcut for PushToTalk"), true)
Check("page shows the prompt", Eval("document.querySelector('.combo.wait') !== null"), "true")
Send("{Ctrl down}{Shift down}{F23}{Shift up}{Ctrl up}")
Check("ptt assigned", WaitLog("assigned PushToTalk: Ctrl+Shift+F23"), true)
Eval("send('assign', {action: 'Cancel'}); 1")  ; Escape must be assigned, not close anything
Check("assigning cancel starts", WaitLog("assigning shortcut for Cancel"), true)
Send("{Escape}")
Check("escape assigned", WaitLog("assigned Cancel: Escape"), true)
Sleep(200)
Check("escape warning shown", Eval("document.querySelector('.msg.warning') !== null"), "true")
Eval("send('assign', {action: 'HandsFree'}); 1")  ; modifier-only
Check("assigning hands-free starts", WaitLog("assigning shortcut for HandsFree"), true)
Send("{Ctrl down}{Alt down}")
Sleep(60)
Send("{Alt up}{Ctrl up}")
Check("modifier-only assigned", WaitLog("assigned HandsFree: Ctrl+Alt"), true)
Eval("send('assign', {action: 'CommandMode'}); 1")  ; the same as Push to talk: refused
Check("assigning command mode starts", WaitLog("assigning shortcut for CommandMode"), true)
Send("{Ctrl down}{Shift down}{F23}{Shift up}{Ctrl up}")
Check("duplicate refused", WaitLog("assigned CommandMode rejected: Ctrl+Shift+F23 (duplicate)"), true)
Sleep(200)
Check("duplicate error shown", Eval("document.querySelector('.msg.error') !== null"), "true")
Eval("send('assign', {action: 'CommandMode'}); 1")  ; press nothing: times out after 5 s
Sleep(300)
Check("assigning again", Eval("S.state.assigning"), '"CommandMode"')
Sleep(5600)
Check("window still open after Escape", WinExist(appWin) != 0, true)
Check("prompt gone after the time limit", Eval("document.querySelector('.combo.wait') === null"), "true")

cfgText := FileRead(dir "\config.ini", "UTF-16")
Check("saved push to talk", InStr(cfgText, "PushToTalk=Ctrl+Shift+F23`n") > 0, true)
Check("saved escape cancel", InStr(cfgText, "Cancel=Escape`n") > 0, true)
Check("saved modifier-only", InStr(cfgText, "HandsFree=Ctrl+Alt`n") > 0, true)
Check("refused and timed out leave empty", InStr(cfgText, "CommandMode=`n") > 0, true)

; A setting changed in the window is saved and applied at once
Eval("set('trayState', 0); 1")
Check("setting applied", WaitLog("window set trayState"), true)
Sleep(200)
Check("setting saved", InStr(FileRead(dir "\config.ini", "UTF-16"), "TrayIconShowsState=0`n") > 0, true)
Eval("set('trayState', 1); 1")
Eval("set('language', 'pl'); 1")
Sleep(500)
Check("language switches the page", Eval("S.lang"), '"pl"')
Eval("set('language', 'en'); 1")
Sleep(300)

Command(8)  ; close: WebView2 goes away with the window
Check("window closes", WinWaitClose(appWin, , 3) != 0, true)
Check("window closed logged", WaitLog("window closed"), true)
; WebView2 processes of our data folder end shortly after the window
WebViewProcesses() {
    count := 0
    for proc in ComObjGet("winmgmts:").ExecQuery("SELECT CommandLine FROM Win32_Process WHERE Name = 'msedgewebview2.exe'")
        if InStr(proc.CommandLine, "OnAirKeyboard\WebView2")
            count++
    return count
}
loop 100 {
    if WebViewProcesses() <= webViewBefore
        break
    Sleep(100)
}
Check("no WebView2 processes left", WebViewProcesses() <= webViewBefore, true)

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
    Out(FileRead(dir "\onairkeyboard.log"))

; Wispr Flow not running: shortcuts are ignored and the LED stays off. When the helper exits
; while recording, the LED turns off. A hidden ping process stands in for the helper.
failuresBefore := failures
wDir := A_Temp "\onairkeyboard-nowispr"
TestConfig(wDir, "PING.EXE")
Run(target ' --config "' wDir '\config.ini"' micArg, , , &pid3)
Check("missing helper logged", WaitLog("Wispr helper not running", 6000, wDir), true)
Tap("F21")
Check("no wispr ignores keys", Caps(), 0)
Run('ping.exe -n 60 127.0.0.1', , "Hide", &pingPid)
Check("helper start detected", WaitLog("Wispr helper running", 6000, wDir), true)
Tap("F21")
Check("keys work once wispr runs", Caps(), 1)
ProcessClose(pingPid)
Check("helper exit logged", WaitLog("Wispr helper exited", 6000, wDir), true)
Sleep(250)
Check("helper exit turns led off", Caps(), 0)
Tap("F21")
Check("keys ignored after exit", Caps(), 0)
WinClose("ahk_class AutoHotkey ahk_pid " pid3)
ProcessWaitClose(pid3, 3)
SetCapsLockState(false)
if failures > failuresBefore
    Out(FileRead(wDir "\onairkeyboard.log"))

; Waits until the Caps Lock LED shows the wanted state (the microphone is polled), up to timeoutMs
WaitCaps(want, timeoutMs := 1500) {
    start := A_TickCount
    while A_TickCount - start < timeoutMs {
        if Caps() = want
            return true
        Sleep(25)
    }
    return false
}

; Microphone source (the default): a ticked app using the microphone lights the LED, no shortcut
; is listened to. Store apps are used here, because a program counts only while its EXE runs.
failuresBefore := failures
micDir := A_Temp "\onairkeyboard-mic"
TestConfig(micDir, ahkExe, "Source=Microphone`n[Microphone]`nApps=Claude|OpenAI.ChatGPT-Desktop`nPollMs=50")
FakeMic.Reset()
FakeMic.Set("Claude_pzs8sxrjxfjjc", 100, 200)
FakeMic.Set("Discord_abcdefghijklm", 100, 200)
Run(target ' --config "' micDir '\config.ini"' micArg, , , &micPid)
Check("mic source starts", WaitLog("started, config", 4000, micDir) && InStr(FileRead(micDir "\onairkeyboard.log"), "signal source Microphone") > 0, true)
Check("mic idle off", Caps(), 0)
FakeMic.Set("Claude_pzs8sxrjxfjjc", 300, 0)
Check("mic in use lights", WaitCaps(1), true)
Check("mic on air logged", WaitLog("on air (Claude)", 2000, micDir), true)
FakeMic.Set("Claude_pzs8sxrjxfjjc", 300, 400)
Check("mic free turns off", WaitCaps(0), true)
FakeMic.Set("Discord_abcdefghijklm", 500, 0)
Sleep(400)
Check("unticked app ignored", Caps(), 0)
Tap("F21")
Check("shortcuts not used", Caps(), 0)
WinClose("ahk_class AutoHotkey ahk_pid " micPid)
ProcessWaitClose(micPid, 3)
SetCapsLockState(false)
if failures > failuresBefore
    Out(FileRead(micDir "\onairkeyboard.log"))

; Both: a shortcut lights the LED at once; when Wispr Flow's microphone (stand-in: this
; AutoHotkey, which runs) stays closed for HybridGraceMs, the LED goes off. A ticked app's
; microphone alone lights it too.
failuresBefore := failures
bothDir := A_Temp "\onairkeyboard-both"
TestConfig(bothDir, ahkExe, "Source=Both`nPauseInWisprWindow=0`n[Microphone]`nApps=Claude`nPollMs=50`nHybridGraceMs=1000")
FakeMic.Reset()
wisprKey := "C:#Apps#Wispr#" ahkExe
FakeMic.Set(wisprKey, 100, 200, true)
Run(target ' --config "' bothDir '\config.ini"' micArg, , , &bothPid)
Check("both source starts", WaitLog("started, config", 4000, bothDir) && InStr(FileRead(bothDir "\onairkeyboard.log"), "signal source Both") > 0, true)
Tap("F21")
Check("both: shortcut lights at once", Caps(), 1)
Check("both: no microphone, goes off", WaitCaps(0, 2500), true)
Check("both: reset logged", WaitLog("hybrid: Wispr Flow's microphone closed", 1000, bothDir), true)
Tap("F21")
Check("both: shortcut again", Caps(), 1)
FakeMic.Set(wisprKey, 300, 0, true)
Sleep(1600)
Check("both: microphone open keeps it", Caps(), 1)
FakeMic.Set(wisprKey, 300, 400, true)
Check("both: microphone closed, goes off", WaitCaps(0, 2500), true)
FakeMic.Set("Claude_pzs8sxrjxfjjc", 500, 0)
Check("both: ticked app alone lights", WaitCaps(1), true)
FakeMic.Set("Claude_pzs8sxrjxfjjc", 500, 600)
Check("both: and goes off", WaitCaps(0), true)
WinClose("ahk_class AutoHotkey ahk_pid " bothPid)
ProcessWaitClose(bothPid, 3)
SetCapsLockState(false)
if failures > failuresBefore
    Out(FileRead(bothDir "\onairkeyboard.log"))

; Self-protection: while a Wispr Flow window is active (stand-in: a window of this AutoHotkey)
; shortcuts are ignored and the Lock is left alone; Hands-free keeps its state.
failuresBefore := failures
guardDir := A_Temp "\onairkeyboard-guard"
TestConfig(guardDir, ahkExe, "Source=Shortcuts`nPauseInWisprWindow=1")
Run(target ' --config "' guardDir '\config.ini"' micArg, , , &guardPid)
WaitLog("started, config", 4000, guardDir)
fakeWispr := Gui("+AlwaysOnTop", "OnAir keyboard test: Wispr Flow stand-in")
fakeWispr.Show("w240 h60")
WinActivate(fakeWispr.Hwnd)
Check("guard: window active", WaitLog("Wispr Flow window active", 3000, guardDir), true)
Tap("F21")
Check("guard: shortcut ignored", Caps(), 0)
fakeWispr.Hide()
Check("guard: window inactive", WaitLog("Wispr Flow window inactive", 3000, guardDir), true)
Tap("F21")
Check("guard: shortcuts work again", Caps(), 1)
; Windows may refuse to bring a window back to the front at once: retry until the guard sees it
GuardActivations() {
    text := ""
    try text := FileRead(guardDir "\onairkeyboard.log")
    StrReplace(text, "window active, shortcuts on hold", , , &count)
    return count
}
fakeWispr.Show()
loop 20 {
    WinActivate(fakeWispr.Hwnd)
    DllCall("SetForegroundWindow", "Ptr", fakeWispr.Hwnd)
    Sleep(150)
    if GuardActivations() >= 2
        break
}
Check("guard: window active again", GuardActivations() >= 2, true)
Tap("F21")
Check("guard: hands-free kept, Lock left alone", Caps(), 1)
fakeWispr.Destroy()
Sleep(600)
Check("guard: still on after the window", Caps(), 1)
Tap("F21")
Check("guard: off by shortcut", Caps(), 0)
WinClose("ahk_class AutoHotkey ahk_pid " guardPid)
ProcessWaitClose(guardPid, 3)
SetCapsLockState(false)
if failures > failuresBefore
    Out(FileRead(guardDir "\onairkeyboard.log"))
FakeMic.Delete()

; First run (no config yet): the window opens by itself on "How it works" (the wide layout);
; opening it again later shows the main view (narrow). No log yet, so the size tells the view.
; Note: a fresh config uses Scroll Lock, so the keyboard LED may blink once here.
freshDir := A_Temp "\onairkeyboard-firstrun"
try DirDelete(freshDir, true)
Run(target ' --config "' freshDir '\config.ini"' micArg, , , &pid2)
firstWin := "OnAir keyboard ahk_class AutoHotkeyGUI ahk_pid " pid2
Check("first run opens the window", WinWait(firstWin, , 8) != 0, true)
Sleep(500)
WinGetClientPos(, , &firstW, , firstWin)
Check("first run shows how it works", firstW > 800 * A_ScreenDPI / 96, true)
Check("first run creates config", FileExist(freshDir "\config.ini") != "", true)
WinClose(firstWin)
WinWaitClose(firstWin, , 3)
PostMessage(0x8001, 7, 0, , "ahk_class AutoHotkey ahk_pid " pid2)
Check("window reopens", WinWait(firstWin, , 8) != 0, true)
Sleep(500)
WinGetClientPos(, , &laterW, , firstWin)
Check("later opens the main view", laterW < 700 * A_ScreenDPI / 96, true)
WinClose("ahk_class AutoHotkey ahk_pid " pid2)
ProcessWaitClose(pid2, 3)

; Without the WebView2 Runtime the program keeps running and explains where to get it
noDir := A_Temp "\onairkeyboard-noruntime"
TestConfig(noDir, ahkExe)
Run(target ' --config "' noDir '\config.ini"' micArg ' --no-webview2', , , &pid4)
WaitLog("started, config", 4000, noDir)
PostMessage(0x8001, 7, 0, , "ahk_class AutoHotkey ahk_pid " pid4)
noWin := "ahk_class AutoHotkeyGUI ahk_pid " pid4
Check("runtime message opens", WinWait(noWin, , 5) != 0, true)
Check("runtime message text", InStr(WinGetText(noWin), "WebView2") > 0, true)
Check("still running", ProcessExist(pid4) != 0, true)
WinClose(noWin)
WinClose("ahk_class AutoHotkey ahk_pid " pid4)
ProcessWaitClose(pid4, 3)

; Process id of the OnAirKeyboard.exe running from the test install folder, 0 if none
InstalledPid() {
    for hwnd in WinGetList("ahk_class AutoHotkey ahk_exe OnAirKeyboard.exe")
        try {  ; a closing copy's window may vanish between the list and the lookup
            if WinGetProcessPath(hwnd) = instDir "\OnAirKeyboard.exe"
                return WinGetPID(hwnd)
        }
    return 0
}
WaitInstalledPid(oldPid := 0) {
    loop 60 {
        if (p := InstalledPid()) && p != oldPid
            return p
        Sleep(100)
    }
    return 0
}

; Self-install (EXE only). Temporary folders stand in for Downloads and the install folder,
; so the real installation, Start menu and Startup folder stay untouched.
; Note: fresh configs use Scroll Lock, so the keyboard LED may blink here.
if exePath != "" {
    DetectHiddenWindows(true)
    dlDir := A_Temp "\onairkeyboard-download", instDir := A_Temp "\onairkeyboard-install"
    for folder in [dlDir, instDir, A_Temp "\onairkeyboard-install-no", A_Temp "\onairkeyboard-inst-cfg", A_Temp "\onairkeyboard-portable-cfg"]
        try DirDelete(folder, true)
    DirCreate(dlDir)
    ; Downloaded under its release name (OnAirKeyboard-<version>.exe); installed as OnAirKeyboard.exe
    SplitPath(exePath, &dlName)
    dlExe := dlDir "\" dlName
    FileCopy(exePath, dlExe)
    downloaded := '"' dlExe '" --install-dir "' instDir '"' micArg

    instCfg := A_Temp "\onairkeyboard-inst-cfg\config.ini"
    Run(downloaded ' --config "' instCfg '" --install-answer yes', , , &dlPid)
    Check("download exits after install", ProcessWaitClose(dlPid, 10), 0)
    Check("exe installed", FileExist(instDir "\OnAirKeyboard.exe") != "", true)
    Check("start menu shortcut", FileExist(instDir "\Start Menu\OnAir keyboard.lnk") != "", true)
    instPid := WaitInstalledPid()
    Check("installed copy runs", instPid != 0, true)
    Check("installed copy sees first run", WinWait("ahk_class AutoHotkeyGUI ahk_pid " instPid, , 5) != 0, true)
    ; The same build opened again from Downloads starts the installed copy without asking
    Run(downloaded ' --config "' instCfg '"', , , &dlPid2)
    Check("same build hands over", ProcessWaitClose(dlPid2, 10), 0)
    instPid2 := WaitInstalledPid(instPid)
    Check("installed copy restarted", instPid2 != 0, true)
    WinClose("ahk_class AutoHotkey ahk_pid " instPid2)
    ProcessWaitClose(instPid2, 3)

    ; "No": runs from Downloads, installs nothing and remembers Portable=1
    portableCfg := A_Temp "\onairkeyboard-portable-cfg\config.ini"
    Run('"' dlExe '" --install-dir "' A_Temp '\onairkeyboard-install-no" --config "' portableCfg '" --install-answer no' micArg, , , &portablePid)
    Sleep(2000)
    Check("no keeps running here", ProcessExist(portablePid) != 0, true)
    Check("no installs nothing", FileExist(A_Temp "\onairkeyboard-install-no\OnAirKeyboard.exe"), "")
    Check("no is remembered", InStr(FileRead(portableCfg, "UTF-16"), "Portable=1") > 0, true)
    WinClose("ahk_class AutoHotkey ahk_pid " portablePid)
    ProcessWaitClose(portablePid, 3)
}

Finish()
