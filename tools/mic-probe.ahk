#Requires AutoHotkey v2.0
; Diagnostic probe for the microphone mode: logs which apps start and stop using the
; microphone (the registry Windows keeps for its microphone tray icon) and presses of F13–F16
; (the Sayo keys send Ctrl+Shift+F13..F16), so the delay from a key to the microphone shows.
; Run: AutoHotkey64.exe /ErrorStdOut tools\mic-probe.ahk [seconds] [log file]
#SingleInstance Off
#NoTrayIcon
OnError(ProbeError)

ProbeError(e, *) {
    FileAppend("ERROR: " e.Message " (line " e.Line ")`n", "*")
    ExitApp(1)
}

MicKey := "Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"
HKCU := -2147483647  ; HKEY_CURRENT_USER (0x80000001), sign-extended as Windows expects
Seconds := A_Args.Length >= 1 ? Integer(A_Args[1]) : 300
LogFile := A_Args.Length >= 2 ? A_Args[2] : A_Temp "\onairkeyboard-mic-probe.log"
try FileDelete(LogFile)

Out(msg) {
    line := FormatTime(, "HH:mm:ss") "." Format("{:03}", A_MSec) "  " msg "`n"
    FileAppend(line, LogFile, "UTF-8")
    FileAppend(line, "*", "UTF-8")
}

NowFileTime() {
    DllCall("GetSystemTimePreciseAsFileTime", "Int64*", &ft := 0)
    return ft
}

Ms(ft) => Round(ft / 10000)

; C:#...#Wispr Flow.exe -> Wispr Flow.exe; Claude_pzs8sxrjxfjjc -> Claude
ShortName(name) => InStr(name, "#") ? RegExReplace(name, ".*#") : RegExReplace(name, "_[a-z0-9]{13}$")

ReadQword(sub, value) {
    size := 8
    r := DllCall("Advapi32\RegGetValueW", "Ptr", HKCU, "Str", sub, "Str", value, "UInt", 0x40  ; RRF_RT_REG_QWORD
        , "Ptr", 0, "Int64*", &v := 0, "UInt*", &size, "UInt")
    return r = 0 ? v : ""
}

; name -> {start, stop}; stop = 0 means "using the microphone now"
ReadAll() {
    apps := Map()
    Add(sub, name) {
        stop := ReadQword(sub, "LastUsedTimeStop")
        start := ReadQword(sub, "LastUsedTimeStart")
        if stop != "" && start != ""
            apps[name] := {start: start, stop: stop}
    }
    Loop Reg, "HKCU\" MicKey, "K" {
        if A_LoopRegName != "NonPackaged"
            Add(MicKey "\" A_LoopRegName, A_LoopRegName)
    }
    Loop Reg, "HKCU\" MicKey "\NonPackaged", "K"
        Add(MicKey "\NonPackaged\" A_LoopRegName, A_LoopRegName)
    return apps
}

Prev := ReadAll()
Out("probe started, " Prev.Count " apps in the registry, runs " Seconds " s")
for name, v in Prev
    if v.stop = 0
        Out("IN USE at start: " ShortName(name))

Held := Map()
KeyDown(key, *) {
    if Held.Has(key)
        return
    Held[key] := true
    Out("key " key " down")
}
KeyUp(key, *) {
    Held.Delete(key)
    Out("key " key " up")
}
for key in ["F13", "F14", "F15", "F16"] {
    Hotkey("~*" key, KeyDown.Bind(key))
    Hotkey("~*" key " up", KeyUp.Bind(key))
}

Poll() {
    global Prev
    cur := ReadAll()
    for name, v in cur {
        p := Prev.Has(name) ? Prev[name] : {start: 0, stop: 1}
        if v.start = p.start && v.stop = p.stop
            continue
        who := ShortName(name)
        if v.stop = 0
            Out("MIC ON   " who "  (registry start " Ms(NowFileTime() - v.start) " ms ago)")
        else if p.stop = 0
            Out("MIC OFF  " who "  after " Ms(v.stop - v.start) " ms (registry stop " Ms(NowFileTime() - v.stop) " ms ago)")
        else
            Out("MIC ON+OFF between polls  " who "  lasted " Ms(v.stop - v.start) " ms")
    }
    Prev := cur
}

SetTimer(Poll, 100)
SetTimer(Finish, -Seconds * 1000)
Finish() {
    Out("probe finished")
    ExitApp(0)
}
