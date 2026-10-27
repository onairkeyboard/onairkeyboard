; Settings stored in %APPDATA%\OnAirKeyboard\config.ini (UTF-16, so Windows INI functions read it reliably).
; Missing values fall back to defaults silently; invalid values fall back with a warning.
class Config {
    static Actions := ["PushToTalk", "HandsFree", "Cancel", "CommandMode"]
    static Locks := ["ScrollLock", "NumLock", "CapsLock"]
    static Languages := ["auto", "pl", "en"]
    static Sources := ["Microphone", "Shortcuts", "Both"]

    static DataDir() => A_AppData "\OnAirKeyboard"
    static DefaultPath() => Config.DataDir() "\config.ini"

    __New() {
        this.Path := ""
        this.IsFirstRun := false
        this.Migrated := false   ; a v0.1 file got the new sections
        this.Warnings := []
        this.Shortcuts := Map()
        for action in Config.Actions
            this.Shortcuts[action] := ""
        this.Source := "Microphone"
        this.PauseInWisprWindow := true
        this.MicApps := MicWatch.DefaultApps()
        this.MicPollMs := 100
        this.HybridGraceMs := 6000
        this.DuckEnabled := false
        this.DuckLevel := 20
        this.DuckSystemSounds := true
        this.DuckFadeDownMs := 250
        this.DuckFadeUpMs := 750
        this.DuckRestoreDelayMs := 1000
        this.Lock := "ScrollLock"
        this.TrayIconShowsState := true
        this.Language := "auto"
        this.StartWithWindows := true
        this.Debug := false
        this.Portable := false
        this.SyncIntervalMs := 150
        this.ResyncDelayMs := 2000
        this.WisprHelperProcess := "Wispr Flow Helper.exe"
        this.WisprAppProcess := "Wispr Flow.exe"
        this.HookReinstallDelaysMs := [3000, 15000]
    }

    ; Reads the file, creating it with defaults on first run.
    static Load(path) {
        cfg := Config()
        cfg.Path := path
        cfg.IsFirstRun := !FileExist(path)
        if cfg.IsFirstRun
            cfg.Save()
        ; A file without [Signal] comes from v0.1: it gets the microphone source and the default
        ; apps, its shortcuts stay for when the source changes
        cfg.Migrated := !cfg.IsFirstRun && IniRead(path, "Signal", , "") = ""
        cfg._Read()
        if cfg.Migrated
            cfg.Save()
        return cfg
    }

    ; Rewrites the whole file from the template, so comments always match the current version.
    Save() {
        SplitPath(this.Path, , &dir)
        DirCreate(dir)
        tmp := this.Path ".tmp"
        if FileExist(tmp)
            FileDelete(tmp)
        FileAppend(this._Render(), tmp, "UTF-16")
        FileMove(tmp, this.Path, true)
    }

    ; Reads one value without creating the file (used before the first run creates it)
    static Peek(path, section, key, default) {
        if !FileExist(path)
            return default
        value := IniRead(path, section, key, "")
        return Trim(value) = "" ? default : Trim(value)
    }

    static PeekBool(path, section, key, default) {
        return Config.ParseBool(Config.Peek(path, section, key, default ? "1" : "0"), &value) ? value : default
    }

    ; "pl" when chosen explicitly or when "auto" and Windows is Polish; otherwise "en".
    static ResolveLanguage(setting, windowsLanguage := A_Language) {
        if setting = "pl" || setting = "en"
            return StrLower(setting)
        return windowsLanguage = "0415" ? "pl" : "en"
    }

    static ParseBool(s, &out) {
        s := Trim(s)
        for v in ["1", "true", "yes", "on"]
            if s = v
                return (out := true, true)
        for v in ["0", "false", "no", "off"]
            if s = v
                return (out := false, true)
        return false
    }

    static ParseInt(s, min, max, &out) {
        s := Trim(s)
        if !IsInteger(s) || Integer(s) < min || Integer(s) > max
            return false
        out := Integer(s)
        return true
    }

    ; Comma-separated integers; an empty string is a valid empty list.
    static ParseIntList(s, min, max, maxCount, &out) {
        list := []
        if Trim(s) != "" {
            for part in StrSplit(s, ",") {
                if !Config.ParseInt(part, min, max, &n)
                    return false
                list.Push(n)
            }
        }
        if list.Length > maxCount
            return false
        out := list
        return true
    }

    _Read() {
        for action in Config.Actions
            this.Shortcuts[action] := this._Get("Shortcuts", action, "")
        this.Source := this._Enum("Signal", "Source", Config.Sources, this.Source)
        this.PauseInWisprWindow := this._Bool("Signal", "PauseInWisprWindow", this.PauseInWisprWindow)
        ; An empty list is a valid choice: no app lights the LED
        this.MicApps := MicWatch.ParseApps(this._Get("Microphone", "Apps", MicWatch.JoinApps(this.MicApps)))
        this.MicPollMs := this._Int("Microphone", "PollMs", 20, 2000, this.MicPollMs)
        this.HybridGraceMs := this._Int("Microphone", "HybridGraceMs", 500, 60000, this.HybridGraceMs)
        this.DuckEnabled := this._Bool("Ducking", "Enabled", this.DuckEnabled)
        this.DuckLevel := this._Int("Ducking", "Level", 0, 50, this.DuckLevel)
        this.DuckSystemSounds := this._Bool("Ducking", "SystemSounds", this.DuckSystemSounds)
        this.DuckFadeDownMs := this._Int("Ducking", "FadeDownMs", 0, 2000, this.DuckFadeDownMs)
        this.DuckFadeUpMs := this._Int("Ducking", "FadeUpMs", 0, 5000, this.DuckFadeUpMs)
        this.DuckRestoreDelayMs := this._Int("Ducking", "RestoreDelayMs", 0, 10000, this.DuckRestoreDelayMs)
        this.Lock := this._Enum("Indicator", "Lock", Config.Locks, this.Lock)
        this.TrayIconShowsState := this._Bool("Indicator", "TrayIconShowsState", this.TrayIconShowsState)
        this.Language := this._Enum("General", "Language", Config.Languages, this.Language)
        this.StartWithWindows := this._Bool("General", "StartWithWindows", this.StartWithWindows)
        this.Debug := this._Bool("General", "Debug", this.Debug)
        this.Portable := this._Bool("General", "Portable", this.Portable)
        this.SyncIntervalMs := this._Int("Advanced", "SyncIntervalMs", 50, 2000, this.SyncIntervalMs)
        this.ResyncDelayMs := this._Int("Advanced", "ResyncDelayMs", 0, 30000, this.ResyncDelayMs)
        process := this._Get("Advanced", "WisprHelperProcess", this.WisprHelperProcess)
        if process = ""
            this._Warn("Advanced", "WisprHelperProcess", process, this.WisprHelperProcess)
        else
            this.WisprHelperProcess := process
        process := this._Get("Advanced", "WisprAppProcess", this.WisprAppProcess)
        if process = ""
            this._Warn("Advanced", "WisprAppProcess", process, this.WisprAppProcess)
        else
            this.WisprAppProcess := process
        raw := this._Get("Advanced", "HookReinstallDelaysMs", Config._JoinInts(this.HookReinstallDelaysMs))
        if Config.ParseIntList(raw, 0, 120000, 5, &delays)
            this.HookReinstallDelaysMs := delays
        else
            this._Warn("Advanced", "HookReinstallDelaysMs", raw, Config._JoinInts(this.HookReinstallDelaysMs))
    }

    _Get(section, key, default) {
        static missing := "<<missing>>"
        value := IniRead(this.Path, section, key, missing)
        return value == missing ? default : Trim(value)
    }

    _Enum(section, key, allowed, default) {
        raw := this._Get(section, key, default)
        for value in allowed
            if raw = value
                return value
        this._Warn(section, key, raw, default)
        return default
    }

    _Bool(section, key, default) {
        raw := this._Get(section, key, default ? "1" : "0")
        if Config.ParseBool(raw, &value)
            return value
        this._Warn(section, key, raw, default ? "1" : "0")
        return default
    }

    _Int(section, key, min, max, default) {
        raw := this._Get(section, key, default)
        if Config.ParseInt(raw, min, max, &value)
            return value
        this._Warn(section, key, raw, default " (allowed " min "-" max ")")
        return default
    }

    _Warn(section, key, raw, default) {
        this.Warnings.Push(Format('Invalid value "{1}" for [{2}] {3}, using "{4}"', raw, section, key, default))
    }

    static _JoinInts(list) {
        text := ""
        for n in list
            text .= (A_Index > 1 ? ", " : "") n
        return text
    }

    _Render() {
        b(v) => v ? "1" : "0"
        return Format("
        (
; OnAir keyboard settings. The easiest way to change them: tray icon > Open OnAir keyboard.
; Edits made in this file take effect after OnAir keyboard restarts.

[Signal]
; What turns the LED on: Microphone, Shortcuts or Both
Source={15}
; 1: ignore shortcuts while the Wispr Flow window is active (Shortcuts and Both)
PauseInWisprWindow={16}

[Microphone]
; Apps that light the LED while they use the microphone: EXE or package names, separated by |
Apps={17}
PollMs={18}
; Both: turn the LED off when Wispr Flow's microphone stays closed this long after a shortcut
HybridGraceMs={19}

[Ducking]
; 1: lower other apps' sound while on air (not the app using the microphone, not Wispr Flow)
Enabled={21}
; Level the other apps go down to, in percent of their own volume (0-50)
Level={22}
; 1: also lower Windows' system sounds (notifications)
SystemSounds={23}
; Fade down 0-2000 ms, fade up 0-5000 ms
FadeDownMs={24}
FadeUpMs={25}
; Wait this long after going off air before the sound comes back (0-10000 ms)
RestoreDelayMs={26}

[Shortcuts]
; Used by the Shortcuts and Both sources.
; Format: Ctrl / Alt / Shift / Win + key, for example Ctrl+Shift+F13.
; Empty means the action is disabled. Use the same shortcuts as in Wispr Flow.
PushToTalk={1}
HandsFree={2}
Cancel={3}
CommandMode={4}

[Indicator]
; Lock key that drives the keyboard LED: ScrollLock, NumLock or CapsLock
Lock={5}
; 1: the tray icon turns red while recording
TrayIconShowsState={6}

[General]
; auto, pl or en
Language={7}
StartWithWindows={8}
; 1: write a diagnostic log (onairkeyboard.log) next to this file
Debug={9}
; 1: run OnAir keyboard from where its EXE is and don't offer to install it
Portable={14}

[Advanced]
SyncIntervalMs={10}
ResyncDelayMs={11}
WisprHelperProcess={12}
WisprAppProcess={20}
HookReinstallDelaysMs={13}
        )"
        , this.Shortcuts["PushToTalk"], this.Shortcuts["HandsFree"], this.Shortcuts["Cancel"]
        , this.Shortcuts["CommandMode"], this.Lock, b(this.TrayIconShowsState), this.Language
        , b(this.StartWithWindows), b(this.Debug), this.SyncIntervalMs, this.ResyncDelayMs
        , this.WisprHelperProcess, Config._JoinInts(this.HookReinstallDelaysMs), b(this.Portable)
        , this.Source, b(this.PauseInWisprWindow), MicWatch.JoinApps(this.MicApps), this.MicPollMs
        , this.HybridGraceMs, this.WisprAppProcess, b(this.DuckEnabled), this.DuckLevel
        , b(this.DuckSystemSounds), this.DuckFadeDownMs, this.DuckFadeUpMs, this.DuckRestoreDelayMs) "`n"
    }
}
