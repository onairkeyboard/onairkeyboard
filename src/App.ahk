; Wires the modules together. Apply() can be called again after settings change,
; so new settings take effect without restarting the program.
class App {
    static Name := "OnAirKey"
    static Version := "0.1.0"
    ; Product website (videos, tutorials, FAQ and feedback will live there)
    static WebsiteUrl := "https://onairkey.com"
    static WebsiteName := "onairkey.com"
    ; GitHub organisation until the public repository exists
    static RepoUrl := "https://github.com/onairkey"
    ; Ready SayoDevice 2x2 setup (keys and LEDs as in the README), restored in the Sayo web app
    static SayoPresetUrl := "https://github.com/onairkey/onairkey/raw/main/presets/WisprFlow_2x2.sayobak"
    static SayoAppUrl := "https://sayodevice.com"

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
        this.LogoFile := ""
        this.SettingsShown := false
    }

    Start() {
        this.Cfg := Config.Load(this.ConfigPath)
        SplitPath(this.Cfg.Path, , &dir)
        this.DataDir := dir
        this.LogoFile := App._LogoFile(dir)
        this.Apply()
        Log.Write(App.Name " " App.Version " started, config " this.Cfg.Path (this.Cfg.IsFirstRun ? " (created)" : ""))

        OnMessage(0x0219, (*) => this.Led.ScheduleResync(1000))  ; WM_DEVICECHANGE
        OnMessage(0x0218, (*) => this.Led.ScheduleResync(1000))  ; WM_POWERBROADCAST
        OnMessage(App.WM_COMMAND, ObjBindMethod(this, "OnCommand"))
        OnExit(ObjBindMethod(this, "Shutdown"))

        ; First run: no welcome screen, the settings window opens on "How it works"
        if this.Cfg.IsFirstRun
            SetTimer(() => this.OpenSettings(), -500)
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

    ; The script uses the asset directly; the EXE carries it inside and unpacks it once.
    static _LogoFile(dataDir) {
        if !A_IsCompiled
            return TrayUI._FullPath(A_LineFile "\..\..\assets\logo-ui.png")
        target := dataDir "\logo-ui.png"
        ; FileInstall must start its own line, or Ahk2Exe won't embed the file
        try {
            FileInstall("..\assets\logo-ui.png", target, 1)
        }
        return target
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

    ShowAbout() => SettingsWindow.Open(this, SettingsWindow.TAB_ABOUT)

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
