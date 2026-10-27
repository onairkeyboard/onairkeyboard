#Requires AutoHotkey v2.0
; Unit tests for the microphone source (MicWatch on a fake registry key), the signal sources,
; the hybrid gate and the v0.1 settings migration.
; Run: AutoHotkey64.exe /ErrorStdOut tests\TestMic.ahk   (exit code = number of failures)

#Include %A_LineFile%\..\..\src\Log.ahk
#Include %A_LineFile%\..\..\src\Lang.ahk
#Include %A_LineFile%\..\..\src\MicWatch.ahk
#Include %A_LineFile%\..\..\src\Signal.ahk
#Include %A_LineFile%\..\..\src\Config.ahk
#Include %A_LineFile%\..\TestLib.ahk
#Include %A_LineFile%\..\FakeMic.ahk

; --- App ids and names ---
Check("id non-packaged", MicWatch.AppId("C:#Users#me#AppData#Local#WisprFlow#app-1.6.1264#Wispr Flow.exe"), "Wispr Flow.exe")
Check("id packaged", MicWatch.AppId("OpenAI.ChatGPT-Desktop_2p2nqsd0c76g0"), "OpenAI.ChatGPT-Desktop")
Check("id packaged short", MicWatch.AppId("Claude_pzs8sxrjxfjjc"), "Claude")
Check("id without suffix", MicWatch.AppId("MSTeams"), "MSTeams")
Check("name known", MicWatch.DisplayName("OpenAI.ChatGPT-Desktop"), "ChatGPT")
Check("name known caseless", MicWatch.DisplayName("wispr flow.exe"), "Wispr Flow")
Check("name unknown drops exe", MicWatch.DisplayName("Hindenburg.exe"), "Hindenburg")
Lang.Set("pl")
Check("name translated pl", MicWatch.DisplayName("Microsoft.WindowsSoundRecorder"), "Dyktafon")
Lang.Set("en")
Check("name translated en", MicWatch.DisplayName("Microsoft.WindowsSoundRecorder"), "Sound Recorder")
Check("dictation wispr", MicWatch.IsDictation("Wispr Flow.exe"), true)
Check("dictation chatgpt", MicWatch.IsDictation("openai.chatgpt-desktop"), true)
Check("not dictation chrome", MicWatch.IsDictation("chrome.exe"), false)
Check("not dictation discord", MicWatch.IsDictation("Discord.exe"), false)
Check("parse apps", MicWatch.JoinApps(MicWatch.ParseApps(" a.exe | |B| a.exe|b ")), "a.exe|B")
Check("parse empty", MicWatch.ParseApps("").Length, 0)

; --- Reading the registry (fake key) ---
; FILETIME values: anything non-zero works; LastUsedTimeStop = 0 means "in use now".
; A non-packaged app counts as live only while its EXE runs: AutoHotkey64.exe (this test) does.
SplitPath(A_AhkPath, &ahkExe)
FakeMic.Reset()
FakeMic.Set("OpenAI.ChatGPT-Desktop_2p2nqsd0c76g0", 500, 600)
FakeMic.Set("Claude_pzs8sxrjxfjjc", 700, 0)
FakeMic.Set("Microsoft.WindowsCamera_8wekyb3d8bbwe", "", "")            ; never used: no values
FakeMic.Set("C:#Apps#WisprFlow#app-1.6.1000#Wispr Flow.exe", 100, 150, true)
FakeMic.Set("C:#Apps#WisprFlow#app-1.6.1264#Wispr Flow.exe", 900, 950, true)
FakeMic.Set("C:#Apps#Tool#v1#" ahkExe, 200, 210, true)
FakeMic.Set("C:#Apps#Tool#v2#" ahkExe, 300, 0, true)                    ; newer version, live
FakeMic.Set("C:#Gone#OnAirNoSuchApp.exe", 400, 0, true)                 ; killed, stuck "in use"
FakeMic.Set("C:#Apps#chrome.exe", 1000, 1001, true)                     ; a flash: 1 tick

entries := MicWatch.Read(FakeMic.Key)
Check("entries merged by app", entries.Count, 6)
Check("never used skipped", entries.Has("Microsoft.WindowsCamera"), false)
Check("versions merge latest start", entries["Wispr Flow.exe"].Start, 900)
Check("versions merge not live", entries["Wispr Flow.exe"].Live, false)
Check("live version wins", entries[ahkExe].Live, true)
Check("packaged live", entries["Claude"].Live, true)
Check("packaged not live", entries["OpenAI.ChatGPT-Desktop"].Live, false)
Check("stuck key of a dead process", entries["OnAirNoSuchApp.exe"].Live, false)
Check("flash is not live", entries["chrome.exe"].Live, false)
Check("missing key reads empty", MicWatch.Read("Software\OnAirKeyboardTest\nothing-here").Count, 0)

; --- Watching: only ticked apps count ---
changes := []
mw := MicWatch(FakeMic.Key, ["Wispr Flow.exe", "OpenAI.ChatGPT-Desktop"], (ids) => changes.Push(MicWatch.JoinApps(ids)))
mw.Poll()
Check("unticked live apps ignored", mw.OnAir, false)
Check("no change reported", changes.Length, 0)
FakeMic.Set("OpenAI.ChatGPT-Desktop_2p2nqsd0c76g0", 1100, 0)
mw.Poll()
Check("ticked app goes live", mw.OnAir, true)
Check("change reported", changes.Length = 1 && changes[1] = "OpenAI.ChatGPT-Desktop", true)
Check("live names", mw.LiveNames(), "ChatGPT")
mw.Poll()
Check("same state not reported again", changes.Length, 1)
mw.SetApps(["Wispr Flow.exe", "OpenAI.ChatGPT-Desktop", "Claude"])
Check("ticking a live app reports at once", changes.Length = 2 && changes[2] = "Claude|OpenAI.ChatGPT-Desktop", true)
Check("two live names", mw.LiveNames(), "Claude, ChatGPT")
FakeMic.Set("OpenAI.ChatGPT-Desktop_2p2nqsd0c76g0", 1100, 1300)
FakeMic.Set("Claude_pzs8sxrjxfjjc", 700, 1200)
mw.Poll()
Check("all stopped", mw.OnAir, false)
Check("stop reported", changes.Length = 3 && changes[3] = "", true)
mw.SetApps([])
FakeMic.Set("Claude_pzs8sxrjxfjjc", 1400, 0)
mw.Poll()
Check("empty selection lights nothing", mw.OnAir, false)

; --- List for the window: ticked first, then the most recently used ---
mw.SetApps(["Wispr Flow.exe", "Claude"])
order := ""
for item in mw.List()
    order .= item.Name (item.Checked ? "+" : "") (item.Live ? "*" : "") " "
Check("list order", Trim(order), "Claude+* Wispr Flow+ ChatGPT Google Chrome OnAirNoSuchApp " RegExReplace(ahkExe, "i)\.exe$") "*")

; --- Polling reads only after Windows signals a change (or after SafetyMs) ---
FakeMic.Set("Claude_pzs8sxrjxfjjc", 1400, 1500)
watched := MicWatch(FakeMic.Key, ["Claude"])
watched.SafetyMs := 600000
watched.Start(50)
Check("start reads once", watched.Reads, 1)
Sleep(300)
Check("no change, no read", watched.Reads, 1)
FakeMic.Set("Claude_pzs8sxrjxfjjc", 1600, 0)
Sleep(200)
Check("change read", watched.Reads >= 2, true)  ; two values written: one or two reads
Check("change seen", watched.OnAir, true)
watched.SafetyMs := 100
Sleep(300)
Check("safety reads", watched.Reads > 2, true)
watched.Stop()
reads := watched.Reads
Sleep(200)
Check("stopped", watched.Reads, reads)

FakeMic.Delete()

; --- Signal sources ---
Check("mic source", Signal.OnAir("Microphone", true, false), false)
Check("mic source on", Signal.OnAir("Microphone", false, true), true)
Check("shortcut source", Signal.OnAir("Shortcuts", true, false), true)
Check("shortcut source ignores mic", Signal.OnAir("Shortcuts", false, true), false)
Check("both: shortcut", Signal.OnAir("Both", true, false), true)
Check("both: mic", Signal.OnAir("Both", false, true), true)
Check("both: none", Signal.OnAir("Both", false, false), false)
Check("uses shortcuts", Signal.UsesShortcuts("Both") && Signal.UsesShortcuts("Shortcuts") && !Signal.UsesShortcuts("Microphone"), true)

; --- Hybrid gate: the shortcut state ends when Wispr's microphone stays closed ---
g := HybridGate(6000)
Check("gate idle", g.Tick(0, false, false), false)
Check("gate starts counting", g.Tick(1000, true, false), false)
Check("gate within grace", g.Tick(6900, true, false), false)
Check("gate grace over", g.Tick(7000, true, false), true)
g := HybridGate(6000)
g.Tick(0, true, false)
Check("mic opens in time", g.Tick(4500, true, true), false)
Check("mic open keeps it", g.Tick(60000, true, true), false)
Check("mic closes: counting again", g.Tick(61000, true, false), false)
Check("short gap is fine", g.Tick(63000, true, true), false)
g.Tick(64000, true, false)
Check("long gap resets", g.Tick(70000, true, false), true)
Check("shortcut off clears", g.Tick(70100, false, false), false)
Check("fresh count after off", g.Tick(70200, true, false), false)

; --- Config: new sections and migration from v0.1 ---
TempConfig() {
    dir := A_Temp "\onairkeyboard-test-" A_TickCount "-" Random(1000, 9999)
    DirCreate(dir)
    return dir "\config.ini"
}
path := TempConfig()
cfg := Config.Load(path)
Check("default source", cfg.Source, "Microphone")
Check("default apps", MicWatch.JoinApps(cfg.MicApps), MicWatch.JoinApps(MicWatch.Dictation))
Check("default poll", cfg.MicPollMs, 100)
Check("default grace", cfg.HybridGraceMs, 6000)
Check("default pause in wispr", cfg.PauseInWisprWindow, true)
Check("default wispr app", cfg.WisprAppProcess, "Wispr Flow.exe")
Check("first run is no migration", cfg.Migrated, false)
cfg.Source := "Both"
cfg.MicApps := ["Claude", "Zoom.exe"]
cfg.PauseInWisprWindow := false
cfg.Save()
cfg2 := Config.Load(path)
Check("rt source", cfg2.Source, "Both")
Check("rt apps", MicWatch.JoinApps(cfg2.MicApps), "Claude|Zoom.exe")
Check("rt pause in wispr", cfg2.PauseInWisprWindow, false)
Check("saved file no migration", cfg2.Migrated, false)
cfg2.MicApps := []
cfg2.Save()
Check("empty apps stay empty", Config.Load(path).MicApps.Length, 0)
IniWrite("Keyboard", path, "Signal", "Source")
IniWrite("5", path, "Microphone", "PollMs")
cfg3 := Config.Load(path)
Check("bad source falls back", cfg3.Source, "Microphone")
Check("bad poll falls back", cfg3.MicPollMs, 100)
Check("bad values warn", cfg3.Warnings.Length, 2)

; A settings file written by v0.1 (no [Signal]): shortcuts and the rest stay
oldPath := TempConfig()
FileAppend("
(
[Shortcuts]
PushToTalk=Ctrl+Shift+F13
HandsFree=Ctrl+Shift+F14
Cancel=Ctrl+Shift+F16
CommandMode=
[Indicator]
Lock=NumLock
TrayIconShowsState=0
[General]
Language=pl
StartWithWindows=1
Debug=1
[Advanced]
SyncIntervalMs=200
)", oldPath, "UTF-16")
old := Config.Load(oldPath)
Check("v0.1 migrated", old.Migrated, true)
Check("v0.1 gets microphone", old.Source, "Microphone")
Check("v0.1 gets default apps", MicWatch.JoinApps(old.MicApps), MicWatch.JoinApps(MicWatch.Dictation))
Check("v0.1 keeps shortcuts", old.Shortcuts["PushToTalk"] " " old.Shortcuts["Cancel"], "Ctrl+Shift+F13 Ctrl+Shift+F16")
Check("v0.1 keeps lock", old.Lock, "NumLock")
Check("v0.1 keeps tray", old.TrayIconShowsState, false)
Check("v0.1 keeps advanced", old.SyncIntervalMs, 200)
Check("v0.1 no warnings", old.Warnings.Length, 0)
oldText := FileRead(oldPath, "UTF-16")
Check("v0.1 file rewritten", InStr(oldText, "`nSource=Microphone`n") > 0, true)
Check("v0.1 file keeps shortcut", InStr(oldText, "HandsFree=Ctrl+Shift+F14`n") > 0, true)
Check("migration only once", Config.Load(oldPath).Migrated, false)

Finish()
