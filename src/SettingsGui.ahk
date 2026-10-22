; Settings window (light, native controls). Edits a draft; Save writes config.ini,
; applies everything without a restart and closes the window.
; Remember: AutoHotkey names are case-insensitive, so locals must not shadow classes
; (gui, menu, config, shortcut, lang, log, support, app, autostart...).
class SettingsWindow {
    static Instance := ""
    static Types := Map("PushToTalk", "hold", "CommandMode", "hold", "HandsFree", "toggle", "Cancel", "reset")
    static ColorError := "cB3261E"
    static ColorWarning := "c8A5300"
    static ColorMuted := "c6B6B6B"

    static Open(owner) {
        if SettingsWindow.Instance {
            SettingsWindow.Instance.Win.Show()
            return SettingsWindow.Instance
        }
        return SettingsWindow.Instance := SettingsWindow(owner)
    }

    __New(owner) {
        this.Owner := owner
        this.Draft := Map()
        for action in Config.Actions
            this.Draft[action] := owner.Cfg.Shortcuts[action]
        this.Recording := ""
        this.Recorder := KeyRecorder()
        this.Rows := Map()
        this.LockRadios := Map()
        this._Build()
        this._Validate()
        this._UpdateWisprStatus()
        this._statusTimer := ObjBindMethod(this, "_UpdateWisprStatus")
        SetTimer(this._statusTimer, 2000)
        this.Win.Show("w600")
    }

    _Build() {
        cfg := this.Owner.Cfg
        win := Gui("-MaximizeBox -MinimizeBox", T("settings.title"))
        win.SetFont("s9", "Segoe UI")
        win.OnEvent("Close", (*) => this.Close())
        this.Win := win
        this.WisprStatus := win.AddText("x16 y12 w568 Right", "")

        tabs := win.AddTab3("x12 y34 w576 h352",
            [T("tab.shortcuts"), T("tab.indicator"), T("tab.general"), T("tab.advanced")])
        this.Tabs := tabs

        ; --- Shortcuts ---
        tabs.UseTab(1)
        win.AddText("x28 y70 w544", T("shortcuts.hint"))
        y := 108
        for action in Config.Actions {
            row := {}
            win.AddText(Format("x28 y{} w118", y + 4), T("action." action))
            row.Field := win.AddEdit(Format("x148 y{} w186 ReadOnly", y))
            win.AddText(Format("x342 y{} w88 {}", y + 4, SettingsWindow.ColorMuted), T("type." SettingsWindow.Types[action]))
            row.Record := win.AddButton(Format("x432 y{} w90 h24", y - 1), T("btn.record"))
            row.Record.OnEvent("Click", ObjBindMethod(this, "_OnRecordClick", action))
            row.Clear := win.AddButton(Format("x528 y{} w40 h24", y - 1), "✕")
            row.Clear.OnEvent("Click", ObjBindMethod(this, "_OnClearClick", action))
            row.Message := win.AddText(Format("x148 y{} w420 h28", y + 25), "")
            this.Rows[action] := row
            y += 56
        }
        win.AddText(Format("x28 y{} w544 h44 {}", y, SettingsWindow.ColorMuted), T("shortcuts.escape_hint"))

        ; --- Indicator ---
        tabs.UseTab(2)
        win.AddText("x28 y70 w544", T("indicator.lock_label"))
        y := 94
        for i, lock in Config.Locks {
            radio := win.AddRadio(Format("x40 y{} w300 {}", y, i = 1 ? "Group" : ""), T("lock." lock))
            radio.Value := cfg.Lock = lock
            radio.OnEvent("Click", (*) => this._Validate())
            this.LockRadios[lock] := radio
            y += 24
        }
        this.CapsWarning := win.AddText(Format("x40 y{} w528 h32 {}", y, SettingsWindow.ColorWarning), T("indicator.caps_warning"))
        this.TrayState := win.AddCheckbox(Format("x28 y{} w540", y + 40), T("indicator.tray_state"))
        this.TrayState.Value := cfg.TrayIconShowsState
        win.AddButton(Format("x28 y{} w150 h26", y + 74), T("btn.test_led")).OnEvent("Click", (*) => this._TestLed())
        win.AddText(Format("x28 y{} w544 h44 {}", y + 114, SettingsWindow.ColorMuted), T("indicator.keyboard_hint"))

        ; --- General ---
        tabs.UseTab(3)
        win.AddText("x28 y70 w300", T("general.language"))
        autoName := T("lang.name." Config.ResolveLanguage("auto"))
        this.LanguageList := win.AddDropDownList("x28 y90 w260", [T("lang.auto", autoName), "Polski", "English"])
        this.LanguageList.Value := cfg.Language = "pl" ? 2 : cfg.Language = "en" ? 3 : 1
        this.StartWithWindows := win.AddCheckbox("x28 y132 w540", T("general.autostart"))
        this.StartWithWindows.Value := cfg.StartWithWindows
        if !A_IsCompiled
            win.AddText("x46 y152 w520 " SettingsWindow.ColorMuted, T("general.autostart_dev"))
        this.DebugLog := win.AddCheckbox("x28 y180 w540", T("general.debug"))
        this.DebugLog.Value := cfg.Debug
        win.AddButton("x28 y212 w150 h26", T("btn.open_folder")).OnEvent("Click", (*) => Run(this.Owner.DataDir))

        ; --- Advanced ---
        tabs.UseTab(4)
        this.Advanced := Map()
        y := 70
        for item in [["SyncIntervalMs", "adv.sync", "Number"], ["ResyncDelayMs", "adv.resync", "Number"]
                , ["WisprHelperProcess", "adv.process", ""], ["HookReinstallDelaysMs", "adv.hook", ""]] {
            win.AddText(Format("x28 y{} w544", y), T(item[2]))
            this.Advanced[item[1]] := win.AddEdit(Format("x28 y{} w260 {}", y + 18, item[3]))
            y += 52
        }
        this._FillAdvanced(cfg)
        win.AddButton(Format("x28 y{} w150 h26", y + 2), T("btn.restore")).OnEvent("Click", (*) => this._FillAdvanced(Config()))
        win.AddText(Format("x28 y{} w544 {}", y + 40, SettingsWindow.ColorMuted), T("adv.hint"))
        tabs.UseTab()

        ; --- Support bar (visible on every tab) ---
        win.AddText("x16 y400 w250 h32", T("support.cta"))
        x := 272
        for link in Support.Links(Lang.Current) {
            width := link.Name = "GitHub Sponsors" ? 116 : 96
            win.AddButton(Format("x{} y398 w{} h26", x, width), link.Name).OnEvent("Click", ((l, *) => Support.Open(l)).Bind(link))
            x += width + 6
        }

        ; --- Footer ---
        win.AddButton("x16 y442 w140 h28", T("btn.open_config")).OnEvent("Click", (*) => Run('notepad.exe "' this.Owner.Cfg.Path '"'))
        win.AddButton("x396 y442 w90 h28", T("btn.cancel")).OnEvent("Click", (*) => this.Close())
        win.AddButton("x494 y442 w90 h28 Default", T("btn.save")).OnEvent("Click", (*) => this.Save())
    }

    _FillAdvanced(source) {
        this.Advanced["SyncIntervalMs"].Value := source.SyncIntervalMs
        this.Advanced["ResyncDelayMs"].Value := source.ResyncDelayMs
        this.Advanced["WisprHelperProcess"].Value := source.WisprHelperProcess
        this.Advanced["HookReinstallDelaysMs"].Value := Config._JoinInts(source.HookReinstallDelaysMs)
    }

    DraftLock {
        get {
            for lock, radio in this.LockRadios
                if radio.Value
                    return lock
            return "ScrollLock"
        }
    }

    ; --- Recording ---

    _OnRecordClick(action, *) {
        if this.Recording = action {
            this._EndRecording()
            this._Validate()
            return
        }
        this.StartRecording(action)
    }

    StartRecording(action) {
        if this.Recording != ""
            this._EndRecording()
        this.Recording := action
        this.Owner.Hotkeys.SetPaused(true)
        row := this.Rows[action]
        row.Field.Value := T("record.prompt")
        row.Record.Text := T("btn.stop_record")
        this.Recorder.Start(ObjBindMethod(this, "_OnRecorded"), ObjBindMethod(this, "_OnRecordTimeout"))
    }

    _OnRecorded(text) {
        action := this.Recording
        this._EndRecording()
        this.Draft[action] := text
        Log.Write("recorded " action ": " text)
        this._Validate()
    }

    _OnRecordTimeout() {
        this._EndRecording()
        this._Validate()
    }

    _EndRecording() {
        if this.Recording = ""
            return
        this.Recorder.Stop()
        this.Rows[this.Recording].Record.Text := T("btn.record")
        this.Recording := ""
        this.Owner.Hotkeys.SetPaused(this.Owner.Paused)
    }

    _OnClearClick(action, *) {
        if this.Recording = action
            this._EndRecording()
        this.Draft[action] := ""
        this._Validate()
    }

    ; --- Validation ---

    ; Refreshes the shortcut fields and messages; returns the issues.
    _Validate() {
        lock := this.DraftLock
        issues := Shortcut.ValidateSet(this.Draft, lock)
        byAction := Map()
        for issue in issues
            if !byAction.Has(issue.Action) || issue.Level = "error"
                byAction[issue.Action] := issue

        for action, row in this.Rows {
            if action = this.Recording
                continue
            text := this.Draft[action]
            try {
                parsed := Shortcut.Parse(text)
                text := IsObject(parsed) ? parsed.Text : ""
            }
            row.Field.Value := text = "" ? T("shortcut.none") : text
            if byAction.Has(action) {
                issue := byAction[action]
                row.Message.SetFont(issue.Level = "error" ? SettingsWindow.ColorError : SettingsWindow.ColorWarning)
                row.Message.Value := SettingsWindow.IssueText(issue)
            } else {
                row.Message.Value := ""
            }
        }
        this.CapsWarning.Visible := lock = "CapsLock"
        return issues
    }

    static IssueText(issue) {
        if issue.Code = "duplicate"
            return T("issue.duplicate", T("action." issue.Detail))
        return T("issue." issue.Code, issue.Detail)
    }

    ; --- Actions ---

    _TestLed() {
        lock := this.DraftLock
        if lock = this.Owner.Cfg.Lock {
            this.Owner.TestLed()
            return
        }
        probe := Indicator(lock, () => false)
        probe.Blink()
    }

    _UpdateWisprStatus() {
        running := this.Owner.Wispr && this.Owner.Wispr.IsRunning
        this.WisprStatus.SetFont(running ? "c1E7B34" : SettingsWindow.ColorMuted)
        this.WisprStatus.Value := T(running ? "wispr.running" : "wispr.not_running")
    }

    Save() {
        this._EndRecording()
        errors := []
        for issue in this._Validate()
            if issue.Level = "error"
                errors.Push(T("action." issue.Action) ": " SettingsWindow.IssueText(issue))
        if errors.Length {
            this.Tabs.Value := 1
            MsgBox(T("save.errors") "`n`n" SettingsWindow._Lines(errors), T("settings.title"), "Icon!")
            return false
        }

        adv := this.Advanced
        advErrors := []
        if !Config.ParseInt(adv["SyncIntervalMs"].Value, 50, 2000, &syncMs)
            advErrors.Push(T("save.invalid_number", T("adv.sync"), 50, 2000))
        if !Config.ParseInt(adv["ResyncDelayMs"].Value, 0, 30000, &resyncMs)
            advErrors.Push(T("save.invalid_number", T("adv.resync"), 0, 30000))
        process := Trim(adv["WisprHelperProcess"].Value)
        if process = ""
            advErrors.Push(T("save.invalid_process", T("adv.process")))
        if !Config.ParseIntList(adv["HookReinstallDelaysMs"].Value, 0, 120000, 5, &delays)
            advErrors.Push(T("save.invalid_list", T("adv.hook")))
        if advErrors.Length {
            this.Tabs.Value := 4
            MsgBox(T("save.errors") "`n`n" SettingsWindow._Lines(advErrors), T("settings.title"), "Icon!")
            return false
        }

        cfg := this.Owner.Cfg
        for action in Config.Actions {
            parsed := Shortcut.Parse(this.Draft[action])
            cfg.Shortcuts[action] := IsObject(parsed) ? parsed.Text : ""
        }
        cfg.Lock := this.DraftLock
        cfg.TrayIconShowsState := this.TrayState.Value = 1
        cfg.Language := ["auto", "pl", "en"][this.LanguageList.Value]
        cfg.StartWithWindows := this.StartWithWindows.Value = 1
        cfg.Debug := this.DebugLog.Value = 1
        cfg.SyncIntervalMs := syncMs
        cfg.ResyncDelayMs := resyncMs
        cfg.WisprHelperProcess := process
        cfg.HookReinstallDelaysMs := delays
        cfg.Warnings := []
        cfg.Save()
        Log.Write("settings saved")
        this.Close()
        this.Owner.Apply()
        return true
    }

    Close() {
        this._EndRecording()
        SetTimer(this._statusTimer, 0)
        this.Win.Destroy()
        SettingsWindow.Instance := ""
    }

    static _Lines(list) {
        text := ""
        for line in list
            text .= "• " line "`n"
        return text
    }
}
