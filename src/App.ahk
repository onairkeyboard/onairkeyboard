; Wires the modules together. Apply() can be called again after settings change,
; so new settings take effect without restarting the program.
class App {
    static Name := "OnAirKey"
    static Version := "0.1.0"

    ; Private window message for test / automation commands (wParam = command)
    static WM_COMMAND := 0x8001
    static CMD_TOGGLE_PAUSE := 1
    static CMD_TEST_LED := 2

    __New(configPath) {
        this.ConfigPath := configPath
        this.Paused := false
        this.Cfg := ""
        this.State := RecState(ObjBindMethod(this, "OnRecordingChange"))
        this.Led := ""
        this.Hotkeys := HotkeyEngine(this.State)
        this.Wispr := ""
        this.Tray := TrayUI(this)
    }

    Start() {
        this.Cfg := Config.Load(this.ConfigPath)
        SplitPath(this.Cfg.Path, , &dir)
        this.DataDir := dir
        this.Apply()
        Log.Write(App.Name " " App.Version " started, config " this.Cfg.Path (this.Cfg.IsFirstRun ? " (created)" : ""))

        OnMessage(0x0219, (*) => this.Led.ScheduleResync(1000))  ; WM_DEVICECHANGE
        OnMessage(0x0218, (*) => this.Led.ScheduleResync(1000))  ; WM_POWERBROADCAST
        OnMessage(App.WM_COMMAND, ObjBindMethod(this, "OnCommand"))
        OnExit(ObjBindMethod(this, "Shutdown"))
    }

    ; (Re)applies the current settings to every module.
    Apply() {
        cfg := this.Cfg
        Log.Init(this.DataDir "\onairkey.log", cfg.Debug)
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
        this.Hotkeys.SetPaused(this.Paused)

        this.Led.Start(cfg.SyncIntervalMs, cfg.ResyncDelayMs)

        if this.Wispr
            this.Wispr.Stop()
        this.Wispr := WisprWatch(cfg.WisprHelperProcess, cfg.HookReinstallDelaysMs)
        this.Wispr.Start()

        this.Tray.Build()
    }

    OnRecordingChange(recording) {
        Log.Write("recording " (recording ? "on" : "off"))
        if this.Led
            this.Led.Sync()
        this.Tray.Update()
    }

    TogglePause() {
        this.Paused := !this.Paused
        Log.Write(this.Paused ? "paused" : "resumed")
        this.Hotkeys.SetPaused(this.Paused)
        this.Led.Paused := this.Paused
        this.Led.Sync()
        this.Tray.Update()
    }

    TestLed() => this.Led.Blink()

    ; Stage 4 replaces this with the settings window.
    OpenSettings() => Run('notepad.exe "' this.Cfg.Path '"')

    OpenLog() {
        file := this.DataDir "\onairkey.log"
        if this.Cfg.Debug && FileExist(file)
            Run('notepad.exe "' file '"')
        else
            MsgBox(T("log.disabled"), App.Name, "Iconi")
    }

    ShowAbout() => MsgBox(T("about.text", App.Version), App.Name, "Iconi")

    OnCommand(wParam, *) {
        if wParam = App.CMD_TOGGLE_PAUSE
            this.TogglePause()
        else if wParam = App.CMD_TEST_LED
            SetTimer(() => this.TestLed(), -1)
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
