#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; Compiler settings (build.ps1 checks that the version matches App.Version)
;@Ahk2Exe-SetName OnAir keyboard
;@Ahk2Exe-SetDescription OnAir keyboard - shows when Wispr Flow is recording
;@Ahk2Exe-SetVersion 0.1.0
;@Ahk2Exe-SetProductVersion 0.1.0
;@Ahk2Exe-SetCopyright (c) 2026 Patryk Szulczewski - MIT License
;@Ahk2Exe-SetCompanyName OnAir keyboard - onairkeyboard.com
;@Ahk2Exe-SetOrigFilename OnAirKeyboard.exe
;@Ahk2Exe-SetMainIcon ..\assets\app.ico
;@Ahk2Exe-AddResource ..\assets\tray-idle-light.ico, 160
;@Ahk2Exe-AddResource ..\assets\tray-rec.ico, 161
;@Ahk2Exe-AddResource ..\assets\tray-idle-dark.ico, 162

#Include %A_LineFile%\..\Log.ahk
#Include %A_LineFile%\..\Lang.ahk
#Include %A_LineFile%\..\MicWatch.ahk
#Include %A_LineFile%\..\Signal.ahk
#Include %A_LineFile%\..\Config.ahk
#Include %A_LineFile%\..\State.ahk
#Include %A_LineFile%\..\Indicator.ahk
#Include %A_LineFile%\..\WisprWatch.ahk
#Include %A_LineFile%\..\Shortcut.ahk
#Include %A_LineFile%\..\ModSession.ahk
#Include %A_LineFile%\..\Hotkeys.ahk
#Include %A_LineFile%\..\Support.ahk
#Include %A_LineFile%\..\Tray.ahk
#Include %A_LineFile%\..\KeyRecorder.ahk
#Include %A_LineFile%\..\Autostart.ahk
#Include %A_LineFile%\..\Installer.ahk
#Include %A_LineFile%\..\ScrollPane.ahk
#Include %A_LineFile%\..\SettingsGui.ahk
#Include %A_LineFile%\..\BugReport.ahk
#Include %A_LineFile%\..\App.ahk

; Unexpected errors go to the diagnostic log (the standard error dialog still appears)
OnError((e, *) => Log.Write("ERROR " e.Message " (" e.Extra ") at " e.File ":" e.Line))

; A held key auto-repeats, which would trip the default hotkey rate limit
A_MaxHotkeysPerInterval := 500

; Test options: --config <path> overrides the settings file; --install-dir <folder> and
; --install-answer yes|no exercise the self-install of the EXE without touching the real one;
; --mic-key <key under HKCU> reads a fake microphone registry instead of Windows' one
configPath := Config.DefaultPath(), installDir := "", installAnswer := "", micKey := ""
for i, arg in A_Args {
    if i = A_Args.Length
        break
    switch arg {
        case "--config": configPath := A_Args[i + 1]
        case "--install-dir": installDir := A_Args[i + 1]
        case "--install-answer": installAnswer := A_Args[i + 1]
        case "--mic-key": micKey := A_Args[i + 1]
    }
}

OnAirKeyboardApp := App(configPath, installDir, installAnswer, micKey)
OnAirKeyboardApp.Start()
