; Wires the modules together. Apply() can be called again after settings change,
; so new settings take effect without restarting the program.
class App {
    static Name := "OnAir keyboard"
    static Version := "0.1.0"
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
    static CMD_OPEN_SETTINGS := 3
    static CMD_RECORD := 4        ; lParam = action index in Config.Actions
    static CMD_SAVE_SETTINGS := 5
    static CMD_REPORT_BUG := 6

    ; installDir / installAnswer: test overrides for the self-install (see Installer)
    __New(configPath, installDir := "", installAnswer := "") {
        this.ConfigPath := configPath
        this.InstallDir := installDir
        this.InstallAnswer := installAnswer
        this.Paused := false
        this.Cfg := ""
        this.State := RecState(ObjBindMethod(this, "OnRecordingChange"))
        this.Led := ""
        this.Hotkeys := HotkeyEngine(this.State)
        this.Wispr := ""
        this.WisprRunning := true  ; until the first check says otherwise
        this.Tray := TrayUI(this)
        this.LogoFile := ""
        this.BugIconFile := ""
        this.SettingsShown := false
    }

    Start() {
        ; The EXE on the real settings file may install itself (tests name an install folder).
        ; Asked before Config.Load creates the settings file, so the installed copy sees a first run.
        install := ""
        if A_IsCompiled && (this.ConfigPath = Config.DefaultPath() || this.InstallDir != "") {
            dir := this.InstallDir != "" ? this.InstallDir : Installer.DefaultDir()
            args := this.InstallDir = "" ? "" : Format(' --config "{1}" --install-dir "{2}"', this.ConfigPath, this.InstallDir)
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
        this.LogoFile := App._UiImage(dir, A_ScreenDPI > 120 ? "logo-ui-2x.png" : "logo-ui.png")
        this.BugIconFile := App._UiImage(dir, "bug-ui.png")
        this.Apply()
        Log.Write(App.Name " " App.Version " started, config " this.Cfg.Path (this.Cfg.IsFirstRun ? " (created)" : ""))
        if this.Cfg.Migrated
            Log.Write("settings from v0.1 migrated: source Microphone, apps " MicWatch.JoinApps(this.Cfg.MicApps) ", shortcuts kept")

        OnMessage(0x0219, (*) => this.Led.ScheduleResync(1000))  ; WM_DEVICECHANGE
        OnMessage(0x0218, (*) => this.Led.ScheduleResync(1000))  ; WM_POWERBROADCAST
        OnMessage(0x001A, (*) => this.Tray.Update())  ; WM_SETTINGCHANGE: the taskbar may turn light / dark
        OnMessage(App.WM_COMMAND, ObjBindMethod(this, "OnCommand"))
        OnExit(ObjBindMethod(this, "Shutdown"))

        ; First run: no welcome screen, the settings window opens on "How it works"
        if this.Cfg.IsFirstRun
            SetTimer(() => this.OpenSettings(), -500)
    }

    ; (Re)applies the current settings to every module.
    Apply() {
        cfg := this.Cfg
        Log.Init(this.DataDir "\onairkeyboard.log", cfg.Debug)
        for warning in cfg.Warnings
            Log.Write(warning)
        Lang.Set(Config.ResolveLanguage(cfg.Language))

        if this.Led
            this.Led.Stop()
        this.Led := Indicator(cfg.Lock, () => this.State.IsRecording)
        this.Led.Paused := this.Paused

        this.Hotkeys.Register(Shortcut.ValidShortcuts(cfg.Shortcuts, cfg.Lock, &issues))
        for issue in issues
            Log.Write(Format("shortcut {1} for {2}: {3} {4}", issue.Level, issue.Action, issue.Code, issue.Detail))
        this.UpdateHotkeys()

        this.Led.Start(cfg.SyncIntervalMs, cfg.ResyncDelayMs)

        if this.Wispr
            this.Wispr.Stop()
        this.Wispr := WisprWatch(cfg.WisprHelperProcess, cfg.HookReinstallDelaysMs, ObjBindMethod(this, "OnWisprChange"))
        this.Wispr.Start()

        ; Only the EXE on the real settings file manages autostart, so tests and
        ; development runs (--config, or the script) never touch the Startup folder.
        if A_IsCompiled && this.ConfigPath = Config.DefaultPath() {
            try Autostart.Sync(cfg.StartWithWindows)
            catch as e
                Log.Write("autostart failed: " e.Message)
        } else {
            Log.Write("autostart not managed (script or custom config)")
        }

        this.Tray.Build()
    }

    ; Images of the settings window. The script uses the assets directly; the EXE carries them
    ; inside and unpacks them once.
    static _UiImage(dataDir, name) {
        if !A_IsCompiled
            return TrayUI._FullPath(A_LineFile "\..\..\assets\" name)
        target := dataDir "\" name
        ; FileInstall needs a literal source and must start its own line, or Ahk2Exe won't embed the file
        try {
            if name = "logo-ui.png"
                FileInstall("..\assets\logo-ui.png", target, 1)
            else if name = "logo-ui-2x.png"
                FileInstall("..\assets\logo-ui-2x.png", target, 1)
            else if name = "bug-ui.png"
                FileInstall("..\assets\bug-ui.png", target, 1)
        }
        return target
    }

    OnRecordingChange(recording) {
        Log.Write("recording " (recording ? "on" : "off"))
        if this.Led
            this.Led.Sync()
        this.Tray.Update()
    }

    ; Shortcuts are ignored while paused, while a shortcut is being recorded in settings and
    ; while Wispr Flow isn't running (it wouldn't record, so the LED would be wrong).
    UpdateHotkeys() {
        recording := SettingsWindow.Instance && SettingsWindow.Instance.Recording != ""
        this.Hotkeys.SetPaused(this.Paused || recording || !this.WisprRunning)
    }

    OnWisprChange(running) {
        this.WisprRunning := running
        this.UpdateHotkeys()
        this.Tray.Update()
    }

    TogglePause() {
        this.Paused := !this.Paused
        Log.Write(this.Paused ? "paused" : "resumed")
        this.UpdateHotkeys()
        this.Led.Paused := this.Paused
        this.Led.Sync()
        this.Tray.Update()
    }

    TestLed() => this.Led.Blink()

    OpenSettings() => SettingsWindow.Open(this)

    OpenLog() {
        file := this.DataDir "\onairkeyboard.log"
        if this.Cfg.Debug && FileExist(file)
            Run('notepad.exe "' file '"')
        else
            MsgBox(T("log.disabled"), App.Name, "Iconi")
    }

    ShowAbout() => SettingsWindow.Open(this, SettingsWindow.TAB_ABOUT)

    ; Opens the window with the address and a prefilled e-mail text to copy
    ReportBug() {
        cfg := this.Cfg
        shortcuts := ""
        for action in Config.Actions
            shortcuts .= (shortcuts = "" ? "" : ", ") action "=" cfg.Shortcuts[action]
        diag := Format("OnAir keyboard {1} ({2})`nWindows {3}`nWispr Flow: {4}`nIndicator: {5}`nShortcuts: {6}`nLanguage: {7}`nDiagnostic log: {8}"
            , App.Version, A_IsCompiled ? "EXE" : "script", A_OSVersion
            , this.WisprRunning ? "detected" : "not running", cfg.Lock, shortcuts, Lang.Current
            , cfg.Debug ? this.DataDir "\onairkeyboard.log" : "off")
        Log.Write("bug report opened")
        BugReportWindow.Open(diag, cfg.Debug ? this.DataDir "\onairkeyboard.log" : "")
    }

    ; Commands run on a timer so the sender's PostMessage returns immediately.
    OnCommand(wParam, lParam, *) {
        switch wParam {
            case App.CMD_TOGGLE_PAUSE: SetTimer(() => this.TogglePause(), -1)
            case App.CMD_TEST_LED: SetTimer(() => this.TestLed(), -1)
            case App.CMD_OPEN_SETTINGS: SetTimer(() => this.OpenSettings(), -1)
            case App.CMD_RECORD:
                if lParam >= 1 && lParam <= Config.Actions.Length
                    SetTimer(() => SettingsWindow.Open(this).StartRecording(Config.Actions[lParam]), -1)
            case App.CMD_SAVE_SETTINGS:
                if SettingsWindow.Instance
                    SetTimer(() => SettingsWindow.Instance.Save(), -1)
            case App.CMD_REPORT_BUG: SetTimer(() => this.ReportBug(), -1)
        }
        return 1
    }

    Shutdown(*) {
        this.Hotkeys.Unregister()
        if this.Wispr
            this.Wispr.Stop()
        if this.Led
            this.Led.Stop()
        Log.Write(App.Name " stopped")
    }
}
