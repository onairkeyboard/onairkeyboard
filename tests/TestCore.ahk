#Requires AutoHotkey v2.0
; Unit tests for the pure logic (config, recording state).
; Run: AutoHotkey64.exe /ErrorStdOut tests\TestCore.ahk   (exit code = number of failures)

#Include %A_LineFile%\..\..\src\Log.ahk
#Include %A_LineFile%\..\..\src\MicWatch.ahk
#Include %A_LineFile%\..\..\src\Config.ahk
#Include %A_LineFile%\..\..\src\State.ahk
#Include %A_LineFile%\..\..\src\Lang.ahk
#Include %A_LineFile%\..\..\src\Support.ahk
#Include %A_LineFile%\..\..\src\Installer.ahk
#Include %A_LineFile%\..\..\src\Json.ahk
#Include %A_LineFile%\..\TestLib.ahk

TempConfig() {
    dir := A_Temp "\onairkeyboard-test-" A_TickCount "-" Random(1000, 9999)
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

; --- Lang: every key exists in both languages ---
for key in Lang.Strings["en"]
    Check("pl has " key, Lang.Strings["pl"].Has(key), true)
for key in Lang.Strings["pl"]
    Check("en has " key, Lang.Strings["en"].Has(key), true)
Lang.Set("pl")
Check("T pl", T("tray.exit"), "Wyjście")
Check("T format", T("about.title", "9.9.9"), "OnAir keyboard 9.9.9")
Lang.Set("xx")
Check("unknown language falls back", Lang.Current, "en")
Check("missing key returns key", T("no.such.key"), "no.such.key")

; --- Support: platforms depend on the language ---
Names(links) {
    text := ""
    for link in links
        text .= (text = "" ? "" : ", ") link.Name
    return text
}
Check("support pl", Names(Support.Links("pl")), "Buycoffee.to, GitHub Sponsors")
Check("support en", Names(Support.Links("en")), "GitHub Sponsors, Buycoffee.to")
Check("support urls", Support.BuyCoffee.Url " " Support.Sponsors.Url,
    "https://buycoffee.to/onairkeyboard https://github.com/sponsors/onairkeyboard")

; --- Bug report e-mail text: current language, details at the end ---
Check("bug address", Support.BugEmail, "hello@onairkeyboard.com")
Lang.Set("pl")
body := Support.BugBody("Windows 10`nShortcuts: Cancel=Ctrl+Shift+F16")
Check("bug body pl", InStr(body, "Co się stało?") = 1, true)
Check("bug body details last", SubStr(body, -StrLen("Cancel=Ctrl+Shift+F16")), "Cancel=Ctrl+Shift+F16")
Lang.Set("en")
Check("bug body en", InStr(Support.BugBody(""), "What happened?") = 1, true)

; --- Installer: what the EXE does when it starts ---
Check("installed copy just runs", Installer.Decide(true, "0.1.0", "0.1.0", true, false), "")
Check("first start offers install", Installer.Decide(false, "", "0.1.0", false, false), "install")
Check("portable is not asked", Installer.Decide(false, "", "0.1.0", false, true), "")
Check("newer offers update", Installer.Decide(false, "0.1.0", "0.2.0", false, false), "update")
Check("newer offers update when portable", Installer.Decide(false, "0.1.0", "0.2.0", false, true), "update")
Check("10 is newer than 9", Installer.Decide(false, "0.9.0", "0.10.0", false, false), "update")
Check("same version, other build", Installer.Decide(false, "0.1.0", "0.1.0", false, false), "update")
Check("same file runs installed", Installer.Decide(false, "0.1.0", "0.1.0", true, false), "run-installed")
Check("older runs installed", Installer.Decide(false, "0.2.0", "0.1.0", false, false), "run-installed")
Check("file version shortened", Installer.ShortVersion("0.1.0.0"), "0.1.0")

; --- Config: Portable, read before the file exists without creating it ---
portablePath := TempConfig()
Check("peek without file", Config.PeekBool(portablePath, "General", "Portable", false), false)
Check("peek creates nothing", FileExist(portablePath), "")
portableCfg := Config.Load(portablePath)
Check("portable off by default", portableCfg.Portable, false)
portableCfg.Portable := true
portableCfg.Save()
Check("peek portable", Config.PeekBool(portablePath, "General", "Portable", false), true)
Check("portable saved", Config.Load(portablePath).Portable, true)

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

; --- JSON for the window messages ---
msg := Json.Parse('{"cmd":"set","key":"app","value":{"id":"Wispr Flow.exe","checked":true},"list":[1,2.5,null,false],"s":"a\"b\\c\nd\u0105"}')
Check("json cmd", msg["cmd"], "set")
Check("json nested", msg["value"]["id"] " " msg["value"]["checked"], "Wispr Flow.exe 1")
Check("json array", msg["list"].Length " " msg["list"][2] " " msg["list"][3] " " msg["list"][4], "4 2.5  0")
Check("json escapes", msg["s"], 'a"b\c' "`n" "dą")
Check("json stringify", Json.Stringify(Map("a", [1, "x"], "b", 'q"' "`n")), '{"a":[1,"x"],"b":"q\"\n"}')
Check("json round trip", Json.Stringify(Json.Parse(Json.Stringify(Map("t", "zażółć\t\\")))), Json.Stringify(Map("t", "zażółć\t\\")))
try {
    Json.Parse('{"a":1,}')
    Check("json bad throws", false, true)
} catch ValueError
    Check("json bad throws", true, true)

; --- Every text the window's page uses exists in both languages ---
pageJs := FileRead(A_LineFile "\..\..\ui\app.js", "UTF-8")
pageKeys := Map()
pos := 1
while pos := RegExMatch(pageJs, "\bt\('([\w.]+)'[,)]", &m, pos) {  ; t('key') and t('key', ...)
    pageKeys[m[1]] := true
    pos += m.Len
}
; Keys the page builds from a prefix
for prefix, suffixes in Map("action.", ["PushToTalk", "HandsFree", "Cancel", "CommandMode"], "type.", ["hold", "toggle", "reset"]
        , "lock.", ["ScrollLock", "NumLock", "CapsLock", "ScrollLock_rec"], "lang.name.", ["pl", "en"]
        , "section.", ["source", "shortcuts", "indicator", "general", "diag", "about", "obs"]
        , "source.", ["Microphone", "Shortcuts", "Both", "Microphone_text", "Shortcuts_text", "Both_text"]
        , "bug.copied_", ["address", "subject", "text"])
    for name in suffixes
        pageKeys[prefix name] := true
Check("page keys found", pageKeys.Count > 100, true)
for language in ["en", "pl"]
    for key in pageKeys
        Check(language " has page text " key, Lang.Strings[language].Has("ui." key) || Lang.Strings[language].Has(key), true)

Finish()
