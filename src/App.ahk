; Wires the modules together. Apply() can be called again after settings change,
; so new settings take effect without restarting the program.
class App {
    static Name := "OnAirKey"
    static Version := "0.1.0"

    ; Private window message for test / automation commands (wParam = command)
    static WM_COMMAND := 0x8001
    static CMD_TOGGLE_PAUSE := 1
    static CMD_TEST_LED := 2
    static CMD_OPEN_SETTINGS := 3
    static CMD_RECORD := 4        ; lParam = action index in Config.Actions
    static CMD_SAVE_SETTINGS := 5

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

        if A_IsCompiled {
            try Autostart.Sync(cfg.StartWithWindows)
            catch as e
                Log.Write("autostart failed: " e.Message)
        } else {
            Log.Write("autostart not managed (script, not EXE)")
        }

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

    OpenSettings() => SettingsWindow.Open(this)

    OpenLog() {
        file := this.DataDir "\onairkey.log"
        if this.Cfg.Debug && FileExist(file)
            Run('notepad.exe "' file '"')
        else
            MsgBox(T("log.disabled"), App.Name, "Iconi")
    }

    ShowAbout() => MsgBox(T("about.text", App.Version), App.Name, "Iconi")

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
