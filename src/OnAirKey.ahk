#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

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
#Include %A_LineFile%\..\App.ahk

; Unexpected errors go to the diagnostic log (the standard error dialog still appears)
OnError((e, *) => Log.Write("ERROR " e.Message " (" e.Extra ") at " e.File ":" e.Line))

; A held key auto-repeats, which would trip the default hotkey rate limit
A_MaxHotkeysPerInterval := 500

; --config <path> overrides the settings file (used for testing)
configPath := Config.DefaultPath()
for i, arg in A_Args
    if arg = "--config" && i < A_Args.Length
        configPath := A_Args[i + 1]

OnAirKeyApp := App(configPath)
OnAirKeyApp.Start()
