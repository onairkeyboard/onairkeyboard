#Requires AutoHotkey v2.0
; Saves PNG screenshots of the OnAir keyboard window: every view, in the light and the dark
; ("Grafit") theme, from a temporary instance with a fake microphone history and a fake mixer
; (Caps Lock as the indicator, the user's apps keep their sound, so a running setup isn't
; disturbed). Nothing is left on screen.
;   AutoHotkey64.exe /ErrorStdOut tools\screenshot-window.ahk [pl|en] [output folder]
#SingleInstance Off
#NoTrayIcon
#Include %A_LineFile%\..\..\tests\WindowLib.ahk
#Include %A_LineFile%\..\..\tests\FakeMic.ahk

OnError(ShotError)
ShotError(e, *) {
    FileAppend("ERROR " e.Message " at line " e.Line "`n", "*")
    Cleanup()
    ExitApp(1)
}
SetTimer(() => (FileAppend("TIMEOUT`n", "*"), Cleanup(), ExitApp(2)), -180000)

Language := A_Args.Length >= 1 ? A_Args[1] : "pl"
OutDir := A_Args.Length >= 2 ? A_Args[2] : A_Temp "\onairkeyboard-shots"
DirCreate(OutDir)
Dir := A_Temp "\onairkeyboard-shot-" Language
try DirDelete(Dir, true)
DirCreate(Dir)
LogFile := Dir "\onairkeyboard.log"
FileAppend(Format("
(
[Signal]
Source=Microphone
[Microphone]
Apps=Wispr Flow.exe|Claude|OpenAI.ChatGPT-Desktop|Aqua Voice.exe
[Shortcuts]
PushToTalk=Ctrl+Shift+F13
HandsFree=Ctrl+Shift+F14
Cancel=Ctrl+Shift+F16
[Indicator]
Lock=CapsLock
[General]
Language={1}
Debug=1
[Ducking]
Enabled=1
)", Language), Dir "\config.ini", "UTF-16")
; What plays meanwhile: lowered while Wispr Flow is on air
Mixer := Dir "\mixer.ini"
FileAppend("[spotify]`nExe=Spotify.exe`nVolume=0.6`n[chrome]`nExe=chrome.exe`nVolume=0.8`n[system]`nSystem=1`nVolume=1`n", Mixer, "UTF-16")

; A typical microphone history; Wispr Flow is on air
FakeMic.Reset()
FakeMic.Set("C:#Users#me#AppData#Local#WisprFlow#app-1.6.1264#Wispr Flow.exe", 900, 0, true)
FakeMic.Set("Claude_pzs8sxrjxfjjc", 880, 890)
FakeMic.Set("OpenAI.ChatGPT-Desktop_2p2nqsd0c76g0", 870, 875)
FakeMic.Set("C:#Program Files#Microsoft#Teams#ms-teams.exe", 860, 865, true)
FakeMic.Set("C:#Users#me#AppData#Local#Discord#app-1.0#Discord.exe", 850, 855, true)
FakeMic.Set("C:#Program Files#Google#Chrome#Application#chrome.exe", 840, 845, true)
FakeMic.Set("C:#Program Files#Zoom#bin#Zoom.exe", 830, 835, true)
FakeMic.Set("C:#Program Files#Microsoft#Edge#msedge.exe", 820, 825, true)
FakeMic.Set("C:#Program Files#obs-studio#bin#64bit#obs64.exe", 810, 815, true)
FakeMic.Set("C:#Users#me#AppData#Local#slack#app-4.41#slack.exe", 800, 805, true)
FakeMic.Set("C:#Program Files#Mozilla Firefox#firefox.exe", 790, 795, true)
FakeMic.Set("Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe", 780, 785)

Pid := 0
Run('"' A_AhkPath '" "' A_LineFile '\..\..\src\OnAirKeyboard.ahk" --config "' Dir '\config.ini" --mic-key "' FakeMic.Key '" --audio-file "' Mixer '"', , , &Pid)
WaitLog("started")
Win := "OnAir keyboard ahk_class AutoHotkeyGUI ahk_pid " Pid

Cleanup() {
    global Pid
    ; A clean exit closes WebView2 at once; killing the instance leaves its processes ending slowly
    if Pid {
        DetectHiddenWindows(true)
        try WinClose("ahk_class AutoHotkey ahk_pid " Pid)
        if ProcessWaitClose(Pid, 3)
            try ProcessClose(Pid)
    }
    Pid := 0
    FakeMic.Delete()
    SetCapsLockState(false)
}

WaitLog(text, timeoutMs := 8000) {
    start := A_TickCount
    while A_TickCount - start < timeoutMs {
        try if InStr(FileRead(LogFile), text)
            return true
        Sleep(50)
    }
    throw Error("log line not seen: " text)
}

Eval(js) => PageEval(Pid, LogFile, js)

; JavaScript that switches the page to a view / section without a mouse
Show(view, section := "") {
    if section != ""
        Eval("go('advanced', '" section "'); 1")
    else
        Eval("go('" view "'); 1")
    Sleep(500)
}

; The instance drives Caps Lock (like the tests), the pictures show the recommended Scroll Lock;
; and they show the installed program, which manages autostart
Shot(name, after := "") {
    Eval("S.settings.lock = 'ScrollLock'; S.settings.autostartManaged = 1; render(); " (after != "" ? after "; " : "") "1")
    Sleep(after != "" ? 400 : 150)
    hwnd := WinExist(Win)
    WinGetPos(, , &w, &h, hwnd)
    file := OutDir "\window-" Language "-" name ".png"
    SaveWindow(hwnd, file)
    FileAppend(file "`n", "*")
}

; PrintWindow with PW_RENDERFULLCONTENT captures the WebView2 content and the frame, even when
; other windows cover it; GDI+ writes the PNG
SaveWindow(hwnd, file) {
    rect := Buffer(16)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect)
    w := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int"), h := NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")
    ; the visible frame (without the invisible resize borders of Windows 10)
    frame := Buffer(16)
    DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 9, "Ptr", frame, "UInt", 16)
    fx := NumGet(frame, 0, "Int") - NumGet(rect, 0, "Int"), fy := NumGet(frame, 4, "Int") - NumGet(rect, 4, "Int")
    fw := NumGet(frame, 8, "Int") - NumGet(frame, 0, "Int"), fh := NumGet(frame, 12, "Int") - NumGet(frame, 4, "Int")
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    mem := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    full := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", w, "Int", h, "Ptr")
    DllCall("SelectObject", "Ptr", mem, "Ptr", full)
    DllCall("PrintWindow", "Ptr", hwnd, "Ptr", mem, "UInt", 2)
    mem2 := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    crop := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", fw, "Int", fh, "Ptr")
    DllCall("SelectObject", "Ptr", mem2, "Ptr", crop)
    DllCall("BitBlt", "Ptr", mem2, "Int", 0, "Int", 0, "Int", fw, "Int", fh, "Ptr", mem, "Int", fx, "Int", fy, "UInt", 0x00CC0020)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)

    static token := 0
    if !token {
        DllCall("LoadLibrary", "Str", "gdiplus")
        si := Buffer(24, 0), NumPut("UInt", 1, si)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0)
    }
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", crop, "Ptr", 0, "Ptr*", &bitmap := 0)
    clsid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "Str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)  ; PNG encoder
    DllCall("gdiplus\GdipSaveImageToFile", "Ptr", bitmap, "Str", file, "Ptr", clsid, "Ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
    for obj in [full, crop]
        DllCall("DeleteObject", "Ptr", obj)
    for dc in [mem, mem2]
        DllCall("DeleteDC", "Ptr", dc)
}

for theme in ["light", "dark"] {
    CopyCommand(Pid, 2, theme)
    PostMessage(0x8001, 7, 0, , "ahk_class AutoHotkey ahk_pid " Pid)  ; open the window
    WaitLog("window ready")
    WinMove(20, 20, , , Win)
    Sleep(800)
    Shot(theme "-main-on-air")
    Shot(theme "-main-tooltip", "document.querySelectorAll('.tip button')[2].click()")
    Shot(theme "-main-show-all", "S.showAll = true; refresh('apps')")
    Eval("S.showAll = false; 1")
    FakeMic.Set("C:#Users#me#AppData#Local#WisprFlow#app-1.6.1264#Wispr Flow.exe", 900, 950, true)
    Sleep(2500)  ; the sound comes back after the delay
    Shot(theme "-main-quiet")
    PostMessage(0x8001, 1, 0, , "ahk_class AutoHotkey ahk_pid " Pid)  ; pause
    Sleep(500)
    Shot(theme "-main-paused")
    PostMessage(0x8001, 1, 0, , "ahk_class AutoHotkey ahk_pid " Pid)  ; resume
    FakeMic.Set("C:#Users#me#AppData#Local#WisprFlow#app-1.6.1264#Wispr Flow.exe", 960, 0, true)
    Sleep(800)
    for section in ["source", "shortcuts", "indicator", "sound", "general", "diag", "about"] {
        Show("advanced", section)
        Shot(theme "-advanced-" section)
    }
    for view in ["howto", "support"] {
        Show(view)
        Shot(theme "-" view)
    }
    Eval("send('bug'); 1")
    Sleep(800)
    Shot(theme "-bug")
    PostMessage(0x8001, 8, 0, , "ahk_class AutoHotkey ahk_pid " Pid)  ; close the window
    Sleep(800)
    ; next theme: the log must show a fresh "window ready"
    FileAppend("", LogFile)
    try FileDelete(LogFile)
}
Cleanup()
ExitApp(0)
