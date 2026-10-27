#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
; Lists the audio sessions OnAir keyboard sees (every active output device) with their volume,
; the way the ducking reads them. Read-only: no volume is changed.
; Run: AutoHotkey64.exe /ErrorStdOut tools\audio-probe.ahk

#Include %A_LineFile%\..\..\src\Log.ahk
#Include %A_LineFile%\..\..\src\Lang.ahk
#Include %A_LineFile%\..\..\src\MicWatch.ahk
#Include %A_LineFile%\..\..\src\AudioMixer.ahk

OnError((e, *) => (FileAppend("ERROR " e.Message " " e.Extra " line " e.Line "`n", "*"), ExitApp(1)))
SetTimer(() => ExitApp(2), -10000)

Lang.Set("en")
mixer := AudioMixer()
sessions := mixer.Sessions()
FileAppend(sessions.Length " sessions`n", "*")
for s in sessions
    FileAppend(Format("{1:-6} {2:-24} {3:-28} vol {4:.2f}{5}`n", s.Pid, s.Exe != "" ? s.Exe : "-"
        , s.Package != "" ? s.Package : "-", s.Volume, s.System ? "  [system sounds]" : ""), "*")
ExitApp(0)
