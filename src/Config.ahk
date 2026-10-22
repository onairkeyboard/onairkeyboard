; Settings stored in %APPDATA%\OnAirKey\config.ini (UTF-16, so Windows INI functions read it reliably).
; Missing values fall back to defaults silently; invalid values fall back with a warning.
class Config {
    static Actions := ["PushToTalk", "HandsFree", "Cancel", "CommandMode"]
    static Locks := ["ScrollLock", "NumLock", "CapsLock"]
    static Languages := ["auto", "pl", "en"]

    static DataDir() => A_AppData "\OnAirKey"
    static DefaultPath() => Config.DataDir() "\config.ini"

    __New() {
        this.Path := ""
        this.IsFirstRun := false
        this.Warnings := []
        this.Shortcuts := Map()
        for action in Config.Actions
            this.Shortcuts[action] := ""
        this.Lock := "ScrollLock"
        this.TrayIconShowsState := true
        this.Language := "auto"
        this.StartWithWindows := true
        this.Debug := false
        this.SyncIntervalMs := 150
        this.ResyncDelayMs := 2000
        this.WisprHelperProcess := "Wispr Flow Helper.exe"
        this.HookReinstallDelaysMs := [3000, 15000]
    }

    ; Reads the file, creating it with defaults on first run.
    static Load(path) {
        cfg := Config()
        cfg.Path := path
        cfg.IsFirstRun := !FileExist(path)
        if cfg.IsFirstRun
            cfg.Save()
        cfg._Read()
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
        this.Lock := this._Enum("Indicator", "Lock", Config.Locks, this.Lock)
        this.TrayIconShowsState := this._Bool("Indicator", "TrayIconShowsState", this.TrayIconShowsState)
        this.Language := this._Enum("General", "Language", Config.Languages, this.Language)
        this.StartWithWindows := this._Bool("General", "StartWithWindows", this.StartWithWindows)
        this.Debug := this._Bool("General", "Debug", this.Debug)
        this.SyncIntervalMs := this._Int("Advanced", "SyncIntervalMs", 50, 2000, this.SyncIntervalMs)
        this.ResyncDelayMs := this._Int("Advanced", "ResyncDelayMs", 0, 30000, this.ResyncDelayMs)
        process := this._Get("Advanced", "WisprHelperProcess", this.WisprHelperProcess)
        if process = ""
            this._Warn("Advanced", "WisprHelperProcess", process, this.WisprHelperProcess)
        else
            this.WisprHelperProcess := process
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
; OnAirKey settings. The easiest way to change them: tray icon > Settings.
; Edits made in this file take effect after OnAirKey restarts.

[Shortcuts]
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
; 1: write a diagnostic log (onairkey.log) next to this file
Debug={9}

[Advanced]
SyncIntervalMs={10}
ResyncDelayMs={11}
WisprHelperProcess={12}
HookReinstallDelaysMs={13}
        )"
        , this.Shortcuts["PushToTalk"], this.Shortcuts["HandsFree"], this.Shortcuts["Cancel"]
        , this.Shortcuts["CommandMode"], this.Lock, b(this.TrayIconShowsState), this.Language
        , b(this.StartWithWindows), b(this.Debug), this.SyncIntervalMs, this.ResyncDelayMs
        , this.WisprHelperProcess, Config._JoinInts(this.HookReinstallDelaysMs)) "`n"
    }
}
