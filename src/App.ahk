; Wires the modules together. Apply() can be called again after settings change,
; so new settings take effect without restarting the program.
class App {
    static Name := "OnAir keyboard"
    static Version := "0.3.5"
    ; Product website (videos, tutorials, FAQ and feedback will live there)
    static WebsiteUrl := "https://onairkeyboard.com"
    static WebsiteName := "onairkeyboard.com"
    ; Source code, releases and issues
    static RepoUrl := "https://github.com/onairkeyboard/onairkeyboard"
    ; Ready SayoDevice 2x2 setup (keys and LEDs as in the README), restored in the Sayo web app
    static SayoPresetUrl := "https://github.com/onairkeyboard/onairkeyboard/raw/main/presets/WisprFlow_2x2.sayobak"
    static SayoAppUrl := "https://sayodevice.com"

    ; Private window message for test / automation commands (wParam = command)
    static WM_COMMAND := 0x8001
    static CMD_TOGGLE_PAUSE := 1
    static CMD_TEST_LED := 2
    static CMD_REPORT_BUG := 6
    static CMD_OPEN_WINDOW := 7   ; lParam = view index in AppWindow.Views (0: main)
    static CMD_CLOSE_WINDOW := 8
    ; WM_COPYDATA commands for tests (dwData = command, the data a string)
    static COPY_EVAL := 1         ; run JavaScript in the window, log the result
    static COPY_THEME := 2        ; "light", "dark" or "auto"
    static COPY_CAPTURE := 3      ; save a PNG of the page

    ; installDir / installAnswer: test overrides for the self-install (see Installer);
    ; micKey: test override for the microphone registry key (under HKEY_CURRENT_USER);
    ; noWebView2: behave as if the WebView2 Runtime were missing;
    ; audioFile: test override, a fake mixer (FileMixer) instead of the apps' real volumes
    __New(configPath, installDir := "", installAnswer := "", micKey := "", noWebView2 := false, audioFile := "") {
        this.ConfigPath := configPath
        this.InstallDir := installDir
        this.InstallAnswer := installAnswer
        this.MicKey := micKey != "" ? micKey : MicWatch.DefaultKey
        this.NoWebView2 := noWebView2
        this.AudioFile := audioFile
        this.Ducker := ""
        this.Paused := false
        this.Cfg := ""
        this.State := RecState(ObjBindMethod(this, "OnRecordingChange"))
        this.Led := ""
        this.Hotkeys := HotkeyEngine(this.State)
        this.Mic := ""
        this.Gate := ""
        this.Guard := ""
        this.LastOnAir := false
        this.Assigning := ""  ; action whose shortcut is being assigned in the window
        this.Recorder := KeyRecorder()
        this._hybrid := ObjBindMethod(this, "HybridTick")
        this.Wispr := ""
        this.WisprRunning := true  ; until the first check says otherwise
        this.Tray := TrayUI(this)
    }

    Start() {
        ; The EXE on the real settings file may install itself (tests name an install folder).
        ; Asked before Config.Load creates the settings file, so the installed copy sees a first run.
        install := ""
        if A_IsCompiled && (this.ConfigPath = Config.DefaultPath() || this.InstallDir != "") {
            dir := this.InstallDir != "" ? this.InstallDir : Installer.DefaultDir()
            args := this.InstallDir = "" ? "" : Format(' --config "{1}" --install-dir "{2}"', this.ConfigPath, this.InstallDir)
            if args != "" && this.MicKey != MicWatch.DefaultKey
                args .= Format(' --mic-key "{1}"', this.MicKey)
            if args != "" && this.AudioFile != ""
                args .= Format(' --audio-file "{1}"', this.AudioFile)
            install := Installer.Check(App.Version, this.ConfigPath, dir, this.InstallAnswer, args)
            if install = "exit"
                ExitApp()
        }
        this.Cfg := Config.Load(this.ConfigPath)
        if install = "portable" && !this.Cfg.Portable {
            this.Cfg.Portable := true
            this.Cfg.Save()
        }
        SplitPath(this.Cfg.Path, , &dir)
        this.DataDir := dir
        ; Before anything can be lowered: closing the program during the start must bring the
        ; sound back too
        OnExit(ObjBindMethod(this, "Shutdown"))
        this.Ducker := Ducker(this._Mixer(), dir "\ducking.ini", ObjBindMethod(this, "DuckExcluded")
            , ObjBindMethod(this, "OnDuckChange"))
        Log.Init(dir "\onairkeyboard.log", this.Cfg.Debug)
        this.Ducker.Recover()  ; before anything is lowered again
        this.Apply()
        Log.Write(App.Name " " App.Version " started, config " this.Cfg.Path (this.Cfg.IsFirstRun ? " (created)" : ""))
        if this.Cfg.Migrated
            Log.Write("settings from v0.1 migrated: source Microphone, apps " MicWatch.JoinApps(this.Cfg.MicApps) ", shortcuts kept")

        OnMessage(0x0219, (*) => this.Led.ScheduleResync(1000))  ; WM_DEVICECHANGE
        OnMessage(0x0218, ObjBindMethod(this, "OnPower"))  ; WM_POWERBROADCAST
        OnMessage(0x001A, ObjBindMethod(this, "OnSettingChange"))
        OnMessage(App.WM_COMMAND, ObjBindMethod(this, "OnCommand"))
        if this.IsTestInstance
            OnMessage(0x004A, ObjBindMethod(this, "OnCopyData"))  ; WM_COPYDATA

        ; First run: no welcome screen, the window opens on "How it works"
        if this.Cfg.IsFirstRun
            SetTimer(() => this.OpenWindow("howto"), -500)
    }

    ; Other apps' volumes: the real mixer, or the fake one of a test (--audio-file)
    _Mixer() {
        if this.AudioFile != ""
            return FileMixer(this.AudioFile)
        try return AudioMixer()
        catch as e {
            Log.Write("audio sessions unavailable: " e.Message)
            return FileMixer("")  ; no sessions: nothing is ever lowered
        }
    }

    ; Sleep: the sound comes back first (the computer may wake up much later, off air)
    OnPower(wParam, *) {
        if wParam = 4 && this.Ducker  ; PBT_APMSUSPEND
            this.Ducker.RestoreNow("sleep")
        this.Led.ScheduleResync(1000)
    }

    ; Not lowered: every app using the microphone now (a voice chat), and Wispr Flow (its sounds)
    DuckExcluded() {
        ids := this.Mic ? this.Mic.LiveAll() : []
        ids.Push(this.Cfg.WisprAppProcess, this.Cfg.WisprHelperProcess)
        return ids
    }

    OnDuckChange() {
        if AppWindow.Instance
            AppWindow.Instance.SendState()
    }

    _SyncDuck() {
        if this.Ducker
            this.Ducker.SetOnAir(!this.Paused && this.OnAir, this.Paused)
    }

    ; Instances on a custom settings file (tests, demo) accept test commands
    IsTestInstance => this.ConfigPath != Config.DefaultPath()

    ; Only the EXE on the real settings file manages autostart, so tests and development runs
    ; (--config, or the script) never touch the Startup folder
    ManagesAutostart => A_IsCompiled && !this.IsTestInstance

    ; WM_SETTINGCHANGE: the taskbar and the apps may have turned light / dark
    OnSettingChange(*) {
        this.Tray.Update()
        if AppWindow.Instance
            AppWindow.Instance.ApplyTheme()
    }

    ; (Re)applies the current settings to every module.
    Apply() {
        cfg := this.Cfg
        Log.Init(this.DataDir "\onairkeyboard.log", cfg.Debug)
        for warning in cfg.Warnings
            Log.Write(warning)
        Lang.Set(Config.ResolveLanguage(cfg.Language))

        Log.Write("signal source " cfg.Source)
        if this.Led
            this.Led.Stop()
        this.Led := Indicator(cfg.Lock, () => this.OnAir)
        this.Led.Paused := this.Paused
        ; No Lock press while a shortcut is held (it disturbs Wispr Flow's Push to talk), so Push
        ; to talk shows in the tray icon only. With the microphone, Wispr Flow closes it
        ; 0.1-0.25 s after the release: the LED doesn't light for that moment.
        this.Led.WaitFn := ObjBindMethod(Indicator, "KeysHeld")
        if cfg.Source != "Shortcuts"
            this.Led.ReleaseHoldMs := 400

        ; The microphone also runs for the Shortcuts source: the window shows who uses it
        if this.Mic
            this.Mic.Stop()
        this.Mic := MicWatch(this.MicKey, cfg.MicApps, ObjBindMethod(this, "OnMicChange"))
        this.Mic.CheckProcess := this.MicKey = MicWatch.DefaultKey
        this.Mic.Start(cfg.MicPollMs)

        ; Shortcuts, the Wispr Flow helper watch and the window guard only matter for the
        ; Shortcuts and Both sources. With the microphone alone OnAir keyboard listens to no key.
        shortcuts := Signal.UsesShortcuts(cfg.Source)
        if this.Wispr
            this.Wispr.Stop()
        this.Wispr := ""
        this.WisprRunning := true
        if this.Guard
            this.Guard.Stop()
        this.Guard := ""
        if shortcuts {
            this.Hotkeys.Register(Shortcut.ValidShortcuts(cfg.Shortcuts, cfg.Lock, &issues))
            for issue in issues
                Log.Write(Format("shortcut {1} for {2}: {3} {4}", issue.Level, issue.Action, issue.Code, issue.Detail))
            if cfg.PauseInWisprWindow {
                this.Guard := WindowGuard(cfg.WisprAppProcess, ObjBindMethod(this, "OnGuardChange"))
                this.Guard.Start()
            }
        } else {
            this.Hotkeys.Unregister()
        }
        this.UpdateHotkeys()

        SetTimer(this._hybrid, 0)
        this.Gate := ""
        if cfg.Source = "Both" {
            this.Gate := HybridGate(cfg.HybridGraceMs)
            SetTimer(this._hybrid, 250)
        }

        this.Led.Start(cfg.SyncIntervalMs, cfg.ResyncDelayMs)
        if this.Ducker {
            this.Ducker.Configure(cfg)
            this._SyncDuck()
        }

        if shortcuts {
            this.Wispr := WisprWatch(cfg.WisprHelperProcess, cfg.HookReinstallDelaysMs, ObjBindMethod(this, "OnWisprChange"))
            this.Wispr.Start()
        }

        this._SyncAutostart()
        this.Tray.Build()
        if AppWindow.Instance {
            AppWindow.Instance.SendSettings()
            AppWindow.Instance.SendState()
        }
    }

    _SyncAutostart() {
        if !this.ManagesAutostart {
            Log.Write("autostart not managed (script or custom config)")
            return
        }
        try Autostart.Sync(this.Cfg.StartWithWindows)
        catch as e
            Log.Write("autostart failed: " e.Message)
    }

    ; "Are we on air?" from the chosen source. Pause is applied by the indicator and the tray.
    OnAir => Signal.OnAir(this.Cfg.Source, this.State.IsRecording, this.Mic && this.Mic.OnAir)

    ; Who is on air, for the tray tip and the window: the apps using the microphone, or
    ; Wispr Flow when its shortcuts turned recording on
    OnAirWho() {
        if this.Cfg.Source = "Shortcuts" || this.Cfg.Source = "Both" && this.State.IsRecording
            return "Wispr Flow"
        return this.Mic ? this.Mic.LiveNames() : ""
    }

    ; State from the shortcuts
    OnRecordingChange(recording) {
        Log.Write("recording " (recording ? "on" : "off"))
        this.UpdateOnAir()
    }

    OnMicChange(liveIds) {
        Log.Write(liveIds.Length ? "microphone in use: " this.Mic.LiveNames() : "microphone free")
        this.UpdateOnAir()
        if this.Ducker
            this.Ducker.Refresh()  ; an app that now uses the microphone keeps its sound
    }

    UpdateOnAir() {
        onAir := this.OnAir ? true : false
        if onAir != this.LastOnAir {
            this.LastOnAir := onAir
            Log.Write(onAir ? "on air (" this.OnAirWho() ")" : "off air")
        }
        if this.Led
            this.Led.Sync()
        this._SyncDuck()
        this.Tray.Update()
        if AppWindow.Instance
            AppWindow.Instance.SendState()
    }

    ; Both: a shortcut state that Wispr Flow's microphone doesn't confirm ends after the grace time
    HybridTick() {
        if this.Paused || !this.Gate || !this.Mic
            return
        if this.Gate.Tick(A_TickCount, this.State.IsRecording, this.Mic.IsLive(this.Cfg.WisprAppProcess)) {
            Log.Write("hybrid: Wispr Flow's microphone closed for " this.Cfg.HybridGraceMs " ms, shortcut state reset")
            this.State.Reset()
        }
    }

    ; Wispr Flow's window is active (the user may be setting its shortcuts there): shortcuts
    ; are ignored and the Lock is left alone. Hands-free keeps its state, so a quick look at the
    ; window doesn't turn the LED off; holds end, because their key-up would be missed.
    OnGuardChange(active) {
        this.Hotkeys.Ignored := active
        if active {
            this.State.HoldUp("PushToTalk")
            this.State.HoldUp("CommandMode")
        }
        if this.Led {
            this.Led.Held := active
            if !active
                this.Led.Sync()
        }
    }

    ; Shortcuts are ignored while paused, while a shortcut is being assigned in the window and
    ; while Wispr Flow isn't running (it wouldn't record, so the LED would be wrong).
    UpdateHotkeys() {
        this.Hotkeys.SetPaused(this.Paused || this.Assigning != "" || !this.WisprRunning)
    }

    OnWisprChange(running) {
        this.WisprRunning := running
        this.UpdateHotkeys()
        this.Tray.Update()
        if AppWindow.Instance
            AppWindow.Instance.SendState()
    }

    TogglePause() {
        this.Paused := !this.Paused
        Log.Write(this.Paused ? "paused" : "resumed")
        this.UpdateHotkeys()
        this.Led.Paused := this.Paused
        this.Led.Sync()
        this._SyncDuck()
        this.Tray.Update()
        if AppWindow.Instance
            AppWindow.Instance.SendState()
    }

    TestLed() => this.Led.Blink()

    TestDuck() => this.Ducker && this.Ducker.Test()

    OpenWindow(view := "") => AppWindow.Open(this, view)

    OpenLog() {
        file := this.LogFile
        if this.Cfg.Debug && FileExist(file)
            Run('notepad.exe "' file '"')
        else
            MsgBox(T("log.disabled"), App.Name, "Iconi")
    }

    LogFile => this.DataDir "\onairkeyboard.log"

    ShowAbout() => this.OpenWindow("about")

    ; Report a bug. Once the form on the website exists (App.BugReportUrl), it opens there with
    ; technical details in the address only, together with Explorer showing the log file. Until
    ; then the window shows a ready e-mail template to copy.
    static BugReportUrl := ""

    ReportBug() {
        Log.Write("bug report opened")
        if App.BugReportUrl != "" {
            Run(Format("{1}?v={2}&win={3}&lang={4}&mode={5}", App.BugReportUrl, App.Version, A_OSVersion
                , Lang.Current, StrLower(this.Cfg.Source)))
            if FileExist(this.LogFile)
                Run('explorer.exe /select,"' this.LogFile '"')
            return
        }
        if win := this.OpenWindow("bug")
            win.Send(Map("type", "bug", "bug", this.BugPayload()))
    }

    BugPayload() {
        cfg := this.Cfg
        shortcuts := ""
        for action in Config.Actions
            shortcuts .= (shortcuts = "" ? "" : ", ") action "=" cfg.Shortcuts[action]
        diag := Format("OnAir keyboard {1} ({2})`nWindows {3}`nSignal: {4}`nApps: {5}`nWispr Flow: {6}`nIndicator: {7}"
            . "`nShortcuts: {8}`nLanguage: {9}`nDiagnostic log: {10}`nDucking: {11}"
            , App.Version, A_IsCompiled ? "EXE" : "script", A_OSVersion, cfg.Source, MicWatch.JoinApps(cfg.MicApps)
            , ProcessExist(cfg.WisprAppProcess) ? "running" : "not running", cfg.Lock, shortcuts, Lang.Current
            , cfg.Debug ? this.LogFile : "off"
            , cfg.DuckEnabled ? Format("on, {1}%, system sounds {2}", cfg.DuckLevel, cfg.DuckSystemSounds ? "on" : "off") : "off")
        return Map("email", Support.BugEmail, "subject", T("bug.subject", App.Version), "body", Support.BugBody(diag)
            , "logExists", cfg.Debug && FileExist(this.LogFile) ? 1 : 0)
    }

    ; --- Assigning a shortcut in the window: the keys pressed next become the shortcut ---

    StartAssign(action) {
        if !App._In(action, Config.Actions)
            return
        this.EndAssign()
        this.Assigning := action
        this.UpdateHotkeys()
        this.Recorder.Start(ObjBindMethod(this, "_OnAssigned"), ObjBindMethod(this, "EndAssign"))
        Log.Write("assigning shortcut for " action)
        if AppWindow.Instance
            AppWindow.Instance.SendState()
    }

    EndAssign() {
        if this.Assigning = ""
            return
        this.Recorder.Stop()
        this.Assigning := ""
        this.UpdateHotkeys()
        if AppWindow.Instance
            AppWindow.Instance.SendState()
    }

    ; Saved at once, unless Wispr Flow wouldn't accept it (then the old shortcut stays and the
    ; window says why); warnings are shown but don't block
    _OnAssigned(text) {
        action := this.Assigning
        this.EndAssign()
        draft := this.Cfg.Shortcuts.Clone()
        draft[action] := text
        found := ""
        for issue in Shortcut.ValidateSet(draft, this.Cfg.Lock) {
            mine := issue.Action = action || issue.Code = "duplicate" && issue.Detail = action
            if mine && (found = "" || issue.Level = "error")
                found := issue
        }
        if found != "" && found.Level = "error" {
            Log.Write("assigned " action " rejected: " text " (" found.Code ")")
            other := found.Action != action ? T("issue.duplicate", T("action." found.Action)) : App.IssueText(found)
            this._SendAssign(action, "error", text ": " other)
            return
        }
        parsed := Shortcut.Parse(text)
        this.Cfg.Shortcuts[action] := parsed.Text
        this.Cfg.Save()
        Log.Write("assigned " action ": " parsed.Text)
        this._ApplyShortcuts()
        this._SendAssign(action, found = "" ? "" : "warning", found = "" ? "" : App.IssueText(found))
    }

    ClearShortcut(action) {
        if !App._In(action, Config.Actions)
            return
        if this.Assigning = action
            this.EndAssign()
        this.Cfg.Shortcuts[action] := ""
        this.Cfg.Save()
        Log.Write("cleared " action)
        this._ApplyShortcuts()
        this._SendAssign(action, "", "")
    }

    _ApplyShortcuts() {
        cfg := this.Cfg
        if Signal.UsesShortcuts(cfg.Source) {
            this.Hotkeys.Register(Shortcut.ValidShortcuts(cfg.Shortcuts, cfg.Lock, &issues))
            this.UpdateHotkeys()
        }
        this.Tray.Update()
        if AppWindow.Instance
            AppWindow.Instance.SendSettings()
    }

    _SendAssign(action, level, text) {
        if AppWindow.Instance
            AppWindow.Instance.Send(Map("type", "assign", "action", action, "level", level, "text", text))
    }

    ; Commands run on a timer so the sender's PostMessage returns immediately.
    OnCommand(wParam, lParam, *) {
        switch wParam {
            case App.CMD_TOGGLE_PAUSE: SetTimer(() => this.TogglePause(), -1)
            case App.CMD_TEST_LED: SetTimer(() => this.TestLed(), -1)
            case App.CMD_REPORT_BUG: SetTimer(() => this.ReportBug(), -1)
            case App.CMD_OPEN_WINDOW:
                view := lParam >= 1 && lParam <= AppWindow.Views.Length ? AppWindow.Views[lParam] : ""
                SetTimer(() => this.OpenWindow(view), -1)
            case App.CMD_CLOSE_WINDOW:
                SetTimer(() => AppWindow.Instance && AppWindow.Instance.Close(), -1)
        }
        return 1
    }

    ; Test commands with text (tests, screenshots); only test instances listen
    OnCopyData(wParam, lParam, *) {
        cmd := NumGet(lParam, 0, "UPtr")
        text := StrGet(NumGet(lParam, 2 * A_PtrSize, "Ptr"), NumGet(lParam, A_PtrSize, "UInt") // 2, "UTF-16")
        switch cmd {
            case App.COPY_EVAL:
                SetTimer(() => AppWindow.Instance ? AppWindow.Instance.Eval(text) : Log.Write("page eval: no window"), -1)
            case App.COPY_THEME:
                AppWindow.ForcedScheme := text = "light" ? 1 : text = "dark" ? 2 : 0
                SetTimer(() => AppWindow.Instance && AppWindow.Instance.ApplyTheme(), -1)
            case App.COPY_CAPTURE:
                SetTimer(() => AppWindow.Instance && AppWindow.Instance.Capture(text), -1)
            default:
                return 0
        }
        return 1
    }

    ; --- The window: what the page shows, and what it asks for ---

    StatePayload() => Map("onAir", !this.Paused && this.OnAir ? 1 : 0, "who", this.OnAirWho()
        , "paused", this.Paused ? 1 : 0, "wispr", this.WisprRunning ? 1 : 0
        , "hasShortcuts", this.Hotkeys.HasShortcuts ? 1 : 0, "assigning", this.Assigning
        , "ducked", this.Ducker && this.Ducker.Active ? 1 : 0, "duckTesting", this.Ducker && this.Ducker.Testing ? 1 : 0
        , "duckedApps", this.Ducker ? this.Ducker.Names() : [])

    SettingsPayload() {
        cfg := this.Cfg
        issues := []
        for issue in Shortcut.ValidateSet(cfg.Shortcuts, cfg.Lock)
            issues.Push(Map("action", issue.Action, "level", issue.Level, "text", App.IssueText(issue)))
        return Map("lock", cfg.Lock, "source", cfg.Source, "apps", cfg.MicApps
            , "autostart", cfg.StartWithWindows ? 1 : 0, "autostartManaged", this.ManagesAutostart ? 1 : 0
            , "trayState", cfg.TrayIconShowsState ? 1 : 0, "language", cfg.Language
            , "autoLanguage", Config.ResolveLanguage("auto"), "debug", cfg.Debug ? 1 : 0
            , "pauseInWispr", cfg.PauseInWisprWindow ? 1 : 0, "graceS", Round(cfg.HybridGraceMs / 1000)
            , "shortcuts", cfg.Shortcuts, "issues", issues, "configPath", cfg.Path
            , "logPath", this.LogFile, "logExists", FileExist(this.LogFile) != "" ? 1 : 0
            , "duck", cfg.DuckEnabled ? 1 : 0, "duckLevel", cfg.DuckLevel, "duckSystem", cfg.DuckSystemSounds ? 1 : 0
            , "duckDown", cfg.DuckFadeDownMs, "duckUp", cfg.DuckFadeUpMs, "duckDelay", cfg.DuckRestoreDelayMs)
    }

    AppsPayload() {
        list := []
        if this.Mic
            for item in this.Mic.List()
                list.Push(Map("id", item.Id, "name", item.Name, "live", item.Live ? 1 : 0, "checked", item.Checked ? 1 : 0))
        return list
    }

    LinksPayload() {
        donations := []  ; not "support": names are case-insensitive, it would hide the Support class
        for link in Support.Links(Lang.Current)
            donations.Push(Map("name", link.Name, "url", link.Url))
        return Map("website", App.WebsiteUrl, "websiteName", App.WebsiteName, "repo", App.RepoUrl
            , "sayoPreset", App.SayoPresetUrl, "sayoApp", App.SayoAppUrl, "support", donations
            , "bugEmail", Support.BugEmail)
    }

    static IssueText(issue) {
        if issue.Code = "duplicate"
            return T("issue.duplicate", T("action." issue.Detail))
        return T("issue." issue.Code, issue.Detail)
    }

    ; msg: {cmd, ...} from the page
    OnWindowCommand(msg) {
        win := AppWindow.Instance
        get(key, default := "") => msg.Has(key) ? msg[key] : default
        switch msg["cmd"] {
            case "set": this.SetOption(get("key"), get("value"))
            case "testLed": this.TestLed()
            case "testDuck": this.TestDuck()
            case "pause": this.TogglePause()
            case "open": AppWindow.OpenExternal(get("url"))
            case "openLog": this.OpenLog()
            case "showLog":
                if FileExist(this.LogFile)
                    Run('explorer.exe /select,"' this.LogFile '"')
                else
                    Run('explorer.exe "' this.DataDir '"')
            case "openConfig": Run('notepad.exe "' this.Cfg.Path '"')
            case "copy": A_Clipboard := get("text")
            case "bug": this.ReportBug()
            case "assign": this.StartAssign(get("action"))
            case "cancelAssign": this.EndAssign()
            case "clear": this.ClearShortcut(get("action"))
            case "view":
                if win
                    win.View := get("view")
            case "layout":
                if win
                    win.SetLayout(get("layout"))
            case "close":
                if win
                    win.Close()
            default: Log.Write("unknown window command " msg["cmd"])
        }
    }

    OnWindowClosing() {
        this.EndAssign()
        this.UpdateHotkeys()
    }

    ; A change from the window takes effect at once and is saved
    SetOption(key, value) {
        cfg := this.Cfg
        Log.Write("window set " key)
        switch key {
            case "lock":
                if !App._In(value, Config.Locks)
                    return
                cfg.Lock := value
                this._SaveAndApply()
            case "source":
                if !App._In(value, Config.Sources)
                    return
                cfg.Source := value
                this._SaveAndApply()
            case "app":  ; {id, checked}: one app of the list ticked or unticked
                id := value["id"], apps := []
                for known in cfg.MicApps
                    if known != id
                        apps.Push(known)
                if value["checked"]
                    apps.Push(id)
                cfg.MicApps := apps
                cfg.Save()
                this.Mic.SetApps(apps)
                this.UpdateOnAir()
                if AppWindow.Instance
                    AppWindow.Instance.SendApps(true)
            case "autostart":
                cfg.StartWithWindows := value ? true : false
                cfg.Save()
                this._SyncAutostart()
            case "trayState":
                cfg.TrayIconShowsState := value ? true : false
                cfg.Save()
                this.Tray.Update()
            case "debug":
                cfg.Debug := value ? true : false
                cfg.Save()
                Log.Init(this.LogFile, cfg.Debug)
                Log.Write("diagnostic log turned on")
            case "pauseInWispr":
                cfg.PauseInWisprWindow := value ? true : false
                this._SaveAndApply()
            case "duck", "duckSystem":
                if key = "duck"
                    cfg.DuckEnabled := value ? true : false
                else
                    cfg.DuckSystemSounds := value ? true : false
                this._SaveDuck()
            case "duckLevel", "duckDown", "duckUp", "duckDelay":
                ; the slider moves in steps of 1 % up to 50 %, the times arrive in ms
                limits := Map("duckLevel", 50, "duckDown", 2000, "duckUp", 5000, "duckDelay", 10000)
                if !IsNumber(value) || value < 0 || value > limits[key]
                    return
                value := Round(value)
                switch key {
                    case "duckLevel": cfg.DuckLevel := value
                    case "duckDown": cfg.DuckFadeDownMs := value
                    case "duckUp": cfg.DuckFadeUpMs := value
                    default: cfg.DuckRestoreDelayMs := value
                }
                this._SaveDuck()
            case "graceS":
                if !Config.ParseInt(String(value), 1, 60, &seconds)
                    return
                cfg.HybridGraceMs := seconds * 1000
                cfg.Save()
                if this.Gate
                    this.Gate.GraceMs := cfg.HybridGraceMs
            case "language":
                if !App._In(value, Config.Languages)
                    return
                cfg.Language := value
                cfg.Save()
                Lang.Set(Config.ResolveLanguage(value))
                this.Tray.Build()
                if AppWindow.Instance {
                    AppWindow.Instance.Win.Title := T("ui.window_title", App.Version)
                    AppWindow.Instance.SendInit()
                }
                return
            default:
                return
        }
        if AppWindow.Instance
            AppWindow.Instance.SendSettings()
    }

    _SaveDuck() {
        this.Cfg.Save()
        this.Ducker.Configure(this.Cfg)
        this._SyncDuck()
        if AppWindow.Instance
            AppWindow.Instance.SendState()
    }

    _SaveAndApply() {
        this.Cfg.Warnings := []
        this.Cfg.Save()
        this.Apply()
    }

    static _In(value, list) {
        for item in list
            if value == item
                return true
        return false
    }

    Shutdown(*) {
        if this.Ducker {
            this.Ducker.RestoreNow("exit")
            this.Ducker.Stop()
        }
        ; WebView2 is closed here, not in AutoHotkey's own clean-up: exiting with the window open
        ; crashed (0xC000041D) and Windows held the EXE for seconds, so an update couldn't replace it
        if AppWindow.Instance
            try AppWindow.Instance.Close()
        this.Hotkeys.Unregister()
        SetTimer(this._hybrid, 0)
        if this.Mic
            this.Mic.Stop()
        if this.Guard
            this.Guard.Stop()
        if this.Wispr
            this.Wispr.Stop()
        if this.Led
            this.Led.Stop()
        Log.Write(App.Name " stopped")
    }
}
