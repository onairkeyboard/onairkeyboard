#Requires AutoHotkey v2.0
; Unit tests for the pure logic (config, recording state).
; Run: AutoHotkey64.exe /ErrorStdOut tests\TestCore.ahk   (exit code = number of failures)

#Include %A_LineFile%\..\..\src\Log.ahk
#Include %A_LineFile%\..\..\src\Config.ahk
#Include %A_LineFile%\..\..\src\State.ahk

failures := 0
passed := 0

Check(name, actual, expected) {
    global failures, passed
    if actual == expected
        passed++
    else {
        failures++
        Out("FAIL " name ": expected [" expected "], got [" actual "]")
    }
}

Out(text) => FileAppend(text "`n", "*", "UTF-8")

TempConfig() {
    dir := A_Temp "\onairkey-test-" A_TickCount "-" Random(1000, 9999)
    DirCreate(dir)
    return dir "\config.ini"
}

; --- Config: parsing helpers ---
Check("bool 1", Config.ParseBool("1", &v) && v, true)
Check("bool off", Config.ParseBool(" off ", &v) && !v, true)
Check("bool junk", Config.ParseBool("maybe", &v), false)
Check("int ok", Config.ParseInt(" 150 ", 50, 2000, &v) && v = 150, true)
Check("int low", Config.ParseInt("10", 50, 2000, &v), false)
Check("int text", Config.ParseInt("abc", 0, 10, &v), false)
Check("list ok", Config.ParseIntList("3000, 15000", 0, 120000, 5, &l) && l.Length = 2 && l[2] = 15000, true)
Check("list empty", Config.ParseIntList("", 0, 120000, 5, &l) && l.Length = 0, true)
Check("list bad", Config.ParseIntList("3000, x", 0, 120000, 5, &l), false)
Check("list too long", Config.ParseIntList("1,2,3,4,5,6", 0, 120000, 5, &l), false)

; --- Config: language ---
Check("lang auto pl", Config.ResolveLanguage("auto", "0415"), "pl")
Check("lang auto other", Config.ResolveLanguage("auto", "0409"), "en")
Check("lang forced en", Config.ResolveLanguage("en", "0415"), "en")
Check("lang forced pl", Config.ResolveLanguage("PL", "0409"), "pl")

; --- Config: first run creates defaults ---
path := TempConfig()
cfg := Config.Load(path)
Check("first run flag", cfg.IsFirstRun, true)
Check("file created", FileExist(path) != "", true)
Check("default lock", cfg.Lock, "ScrollLock")
Check("default shortcut empty", cfg.Shortcuts["PushToTalk"], "")
Check("default sync", cfg.SyncIntervalMs, 150)
Check("default delays", cfg.HookReinstallDelaysMs.Length, 2)
Check("no warnings", cfg.Warnings.Length, 0)
Check("second load not first run", Config.Load(path).IsFirstRun, false)

; --- Config: round trip ---
cfg.Shortcuts["PushToTalk"] := "Ctrl+Shift+F13"
cfg.Shortcuts["Cancel"] := "Escape"
cfg.Lock := "NumLock"
cfg.Debug := true
cfg.SyncIntervalMs := 200
cfg.HookReinstallDelaysMs := [1000]
cfg.Save()
cfg2 := Config.Load(path)
Check("rt shortcut", cfg2.Shortcuts["PushToTalk"], "Ctrl+Shift+F13")
Check("rt escape", cfg2.Shortcuts["Cancel"], "Escape")
Check("rt lock", cfg2.Lock, "NumLock")
Check("rt debug", cfg2.Debug, true)
Check("rt sync", cfg2.SyncIntervalMs, 200)
Check("rt delays", cfg2.HookReinstallDelaysMs.Length = 1 && cfg2.HookReinstallDelaysMs[1] = 1000, true)

; --- Config: invalid values fall back with warnings, case-insensitive enums ---
IniWrite("scrolllock", path, "Indicator", "Lock")
IniWrite("9", path, "Advanced", "SyncIntervalMs")
IniWrite("maybe", path, "General", "Debug")
IniWrite("", path, "Advanced", "WisprHelperProcess")
cfg3 := Config.Load(path)
Check("enum case", cfg3.Lock, "ScrollLock")
Check("bad int default", cfg3.SyncIntervalMs, 150)
Check("bad bool default", cfg3.Debug, false)
Check("empty process default", cfg3.WisprHelperProcess, "Wispr Flow Helper.exe")
Check("warnings count", cfg3.Warnings.Length, 3)

; --- RecState ---
changes := []
st := RecState((rec) => changes.Push(rec))
Check("idle", st.IsRecording, false)
st.HoldDown("PushToTalk")
Check("ptt down", st.IsRecording, true)
st.HoldDown("PushToTalk")  ; auto-repeat must not fire another change
st.HoldUp("PushToTalk")
Check("ptt up", st.IsRecording, false)
Check("ptt changes", changes.Length, 2)
st.ToggleHandsFree()
Check("hf on", st.IsRecording, true)
st.HoldDown("CommandMode")
st.HoldUp("CommandMode")
Check("hold ends, hf keeps", st.IsRecording, true)
st.ToggleHandsFree()
Check("hf off", st.IsRecording, false)
st.ToggleHandsFree()
st.HoldDown("PushToTalk")
st.Reset()
Check("reset", st.IsRecording, false)
Check("reset clears hold", st.pttHeld, false)
Check("total changes", changes.Length, 6)
try {
    st.HoldDown("HandsFree")
    Check("bad hold throws", false, true)
} catch ValueError
    Check("bad hold throws", true, true)

Out(passed " passed, " failures " failed")
ExitApp(failures)
