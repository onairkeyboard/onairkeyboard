#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; Compiler settings (build.ps1 checks that the version matches App.Version)
;@Ahk2Exe-SetName OnAirKey
;@Ahk2Exe-SetDescription OnAirKey - shows when Wispr Flow is recording
;@Ahk2Exe-SetVersion 0.1.0
;@Ahk2Exe-SetProductVersion 0.1.0
;@Ahk2Exe-SetCopyright (c) 2026 Patryk Szulczewski - MIT License
;@Ahk2Exe-SetCompanyName OnAirKey - onairkey.com
;@Ahk2Exe-SetOrigFilename OnAirKey.exe
;@Ahk2Exe-SetMainIcon ..\assets\onairkey.ico
;@Ahk2Exe-AddResource ..\assets\tray-idle.ico, 160
;@Ahk2Exe-AddResource ..\assets\tray-rec.ico, 161

#Include %A_LineFile%\..\Log.ahk
#Include %A_LineFile%\..\Lang.ahk
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
; --install-answer yes|no exercise the self-install of the EXE without touching the real one
configPath := Config.DefaultPath(), installDir := "", installAnswer := ""
for i, arg in A_Args {
    if i = A_Args.Length
        break
    switch arg {
        case "--config": configPath := A_Args[i + 1]
        case "--install-dir": installDir := A_Args[i + 1]
        case "--install-answer": installAnswer := A_Args[i + 1]
    }
}

OnAirKeyApp := App(configPath, installDir, installAnswer)
OnAirKeyApp.Start()
