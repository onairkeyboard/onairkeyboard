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

    ; Tab numbers
    static TAB_HOWTO := 1, TAB_SHORTCUTS := 2, TAB_INDICATOR := 3, TAB_GENERAL := 4
    static TAB_ADVANCED := 5, TAB_ABOUT := 6

    ; tab: 0 picks the default (How it works the very first time, Shortcuts afterwards)
    static Open(owner, tab := 0) {
        if SettingsWindow.Instance {
            if tab
                SettingsWindow.Instance.ShowTab(tab)
            SettingsWindow.Instance.Win.Show()
            return SettingsWindow.Instance
        }
        ; Building the window takes longer than AutoHotkey's 15 ms before another thread may
        ; interrupt. Without Critical, a queued command (open, record) would find no instance
        ; yet and open a second window; a shortcut recorded there was lost on save.
        Critical
        return SettingsWindow.Instance := SettingsWindow(owner, tab)
    }

    __New(owner, tab := 0) {
        this.Owner := owner
        this.Draft := Map()
        for action in Config.Actions
            this.Draft[action] := owner.Cfg.Shortcuts[action]
        this.Recording := ""
        this.Recorder := KeyRecorder()
        this.Rows := Map()
        this.LockRadios := Map()
        this._Build()
        if !tab
            tab := owner.Cfg.IsFirstRun && !owner.SettingsShown ? SettingsWindow.TAB_HOWTO : SettingsWindow.TAB_SHORTCUTS
        owner.SettingsShown := true
        this.Tabs.Value := tab
        this._Validate()
        this._UpdateWisprStatus()
        this._statusTimer := ObjBindMethod(this, "_UpdateWisprStatus")
        SetTimer(this._statusTimer, 2000)
        this.Win.Show("w600 h610")
        this.HowtoPane.Fill(this.HowtoHeight)
        this._SyncPanes()
        this.Tabs.Focus()  ; otherwise the header link gets the focus rectangle
    }

    ShowTab(tab) {
        this.Tabs.Value := tab
        this._SyncPanes()
    }

    ; The How it works pane is a separate window, so it follows the selected tab by hand
    _SyncPanes() => this.HowtoPane.Visible := this.Tabs.Value = SettingsWindow.TAB_HOWTO

    ; y below a control, plus a gap
    static _Below(ctrl, gap) {
        ctrl.GetPos(, &y, , &h)
        return y + h + gap
    }

    _Build() {
        cfg := this.Owner.Cfg
        muted := SettingsWindow.ColorMuted
        win := Gui("-MaximizeBox -MinimizeBox", T("settings.title", App.Version))
        win.SetFont("s9", "Segoe UI")
        win.OnEvent("Close", (*) => this.Close())
        this.Win := win

        ; --- Header: logo (opens the website), Wispr status in the middle, Report a bug on the right ---
        logo := this.Owner.LogoFile
        if logo != "" && FileExist(logo)
            win.AddPicture("x16 y7 h40 w-1", logo).OnEvent("Click", (*) => Run(App.WebsiteUrl))
        win.SetFont("bold")
        this.WisprStatus := win.AddText("x150 y20 w300 Center", "")
        win.SetFont("norm")
        ; Right-aligned to the tab edge: the link is sized to its text, then moved
        bugLink := win.AddLink("x0 y20", '<a id="bug">' T("header.bug") '</a>')
        bugLink.OnEvent("Click", (*) => this.Owner.ReportBug())
        bugLink.GetPos(, , &linkW)
        bugLink.Move(586 - linkW)
        bugIcon := this.Owner.BugIconFile
        if bugIcon != "" && FileExist(bugIcon)
            win.AddPicture(Format("x{} y20 w16 h16", 582 - linkW - 16), bugIcon).OnEvent("Click", (*) => this.Owner.ReportBug())

        tabs := win.AddTab3("x12 y52 w576 h404",
            [T("tab.howto"), T("tab.shortcuts"), T("tab.indicator"), T("tab.general"), T("tab.advanced"), T("tab.about")])
        tabs.OnEvent("Change", (*) => this._SyncPanes())
        this.Tabs := tabs

        ; --- How it works: a scrolling pane over the tab page, so the text can breathe and grow
        ; (later maybe a video). Each control goes below the previous one by its real height.
        ; Tab3 keeps the page controls in a dialog window; the pane goes inside it, so the page
        ; can't paint over it
        page := DllCall("FindWindowEx", "Ptr", win.Hwnd, "Ptr", 0, "Str", "#32770", "Ptr", 0, "Ptr")
        pane := ScrollPane(page, "White")
        p := pane.Gui
        Below := ObjBindMethod(SettingsWindow, "_Below")
        p.SetFont("s14 bold", "Segoe UI")
        y := Below(p.AddText("x20 y20 w516", T("howto.title")), 12)
        p.SetFont("s9 norm")
        y := Below(p.AddText(Format("x20 y{} w516", y), T("howto.problem")), 12)
        y := Below(p.AddText(Format("x20 y{} w516", y), T("howto.solution")), 28)
        p.SetFont("s11 bold")
        y := Below(p.AddText(Format("x20 y{} w516", y), T("howto.steps_title")), 14)
        p.SetFont("s9 norm")
        for i, step in ["howto.step1", "howto.step2", "howto.step3"] {
            p.SetFont("bold")
            p.AddText(Format("x20 y{} w20", y), i ".")
            p.SetFont("norm")
            y := Below(p.AddText(Format("x40 y{} w496", y), T(step)), i = 1 ? 8 : 18)
            if i = 1  ; SayoDevice 2x2 owners can skip step 1 with the ready backup
                y := Below(p.AddLink(Format("x40 y{} w496", y), T("howto.sayo", App.SayoPresetUrl, App.SayoAppUrl)), 18)
        }
        y := Below(p.AddText(Format("x20 y{} w516 {}", y + 10, muted), T("howto.no_led")), 10)
        y := Below(p.AddText(Format("x20 y{} w516", y), T("howto.tray_tip")), 14)
        y := Below(p.AddLink(Format("x20 y{} w516", y), T("howto.more") " " SettingsWindow.WebsiteLink()), 20)
        this.HowtoPane := pane
        this.HowtoHeight := y

        ; --- Shortcuts ---
        tabs.UseTab(SettingsWindow.TAB_SHORTCUTS)
        win.AddText("x28 y88 w544", T("shortcuts.hint"))
        y := 128
        for action in Config.Actions {
            row := {}
            win.AddText(Format("x28 y{} w118", y + 4), T("action." action))
            row.Field := win.AddEdit(Format("x148 y{} w186 ReadOnly", y))
            win.AddText(Format("x342 y{} w88 {}", y + 4, muted), T("type." SettingsWindow.Types[action]))
            row.Record := win.AddButton(Format("x432 y{} w90 h24", y - 1), T("btn.record"))
            row.Record.OnEvent("Click", ObjBindMethod(this, "_OnRecordClick", action))
            row.Clear := win.AddButton(Format("x528 y{} w40 h24", y - 1), "✕")
            row.Clear.OnEvent("Click", ObjBindMethod(this, "_OnClearClick", action))
            row.Message := win.AddText(Format("x148 y{} w420 h28", y + 25), "")
            this.Rows[action] := row
            y += 58
        }
        win.AddText(Format("x28 y{} w544 h48 {}", y + 4, muted), T("shortcuts.escape_hint"))

        ; --- Indicator ---
        tabs.UseTab(SettingsWindow.TAB_INDICATOR)
        win.AddText("x28 y88 w544", T("indicator.lock_label"))
        y := 112
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
        win.AddText(Format("x28 y{} w544 h44 {}", y + 114, muted), T("indicator.keyboard_hint"))

        ; --- General ---
        tabs.UseTab(SettingsWindow.TAB_GENERAL)
        win.AddText("x28 y88 w300", T("general.language"))
        autoName := T("lang.name." Config.ResolveLanguage("auto"))
        this.LanguageList := win.AddDropDownList("x28 y108 w260", [T("lang.auto", autoName), "Polski", "English"])
        this.LanguageList.Value := cfg.Language = "pl" ? 2 : cfg.Language = "en" ? 3 : 1
        this.StartWithWindows := win.AddCheckbox("x28 y150 w540", T("general.autostart"))
        this.StartWithWindows.Value := cfg.StartWithWindows
        if !A_IsCompiled
            win.AddText("x46 y170 w520 " muted, T("general.autostart_dev"))
        this.DebugLog := win.AddCheckbox("x28 y198 w540", T("general.debug"))
        this.DebugLog.Value := cfg.Debug
        win.AddButton("x28 y230 w150 h26", T("btn.open_folder")).OnEvent("Click", (*) => Run(this.Owner.DataDir))

        ; --- Advanced ---
        tabs.UseTab(SettingsWindow.TAB_ADVANCED)
        this.Advanced := Map()
        y := 88
        for item in [["SyncIntervalMs", "adv.sync", "Number"], ["ResyncDelayMs", "adv.resync", "Number"]
                , ["WisprHelperProcess", "adv.process", ""], ["HookReinstallDelaysMs", "adv.hook", ""]] {
            win.AddText(Format("x28 y{} w544", y), T(item[2]))
            this.Advanced[item[1]] := win.AddEdit(Format("x28 y{} w260 {}", y + 18, item[3]))
            y += 52
        }
        this._FillAdvanced(cfg)
        win.AddButton(Format("x28 y{} w150 h26", y + 2), T("btn.restore")).OnEvent("Click", (*) => this._FillAdvanced(Config()))
        win.AddButton(Format("x186 y{} w150 h26", y + 2), T("btn.open_config")).OnEvent("Click", (*) => Run('notepad.exe "' this.Owner.Cfg.Path '"'))
        win.AddText(Format("x28 y{} w544 {}", y + 40, muted), T("adv.hint"))

        ; --- About ---
        tabs.UseTab(SettingsWindow.TAB_ABOUT)
        win.SetFont("s12 bold")
        win.AddText("x28 y88 w544", T("about.title", App.Version))
        win.SetFont("s10 bold")
        win.AddText("x28 y122 w544", T("about.why_title"))
        win.SetFont("s9 norm")
        win.AddText("x28 y144 w544 h48", T("about.why"))
        win.SetFont("s10 bold")
        win.AddText("x28 y204 w544", T("about.oss_title"))
        win.SetFont("s9 norm")
        win.AddText("x28 y226 w544 h32", T("about.oss"))
        win.AddLink("x28 y262 w544", Format('<a href="{1}">{1}</a>', App.RepoUrl))
        win.AddLink("x28 y288 w544", T("about.website") " " SettingsWindow.WebsiteLink())
        win.AddLink("x28 y312 w544", T("about.bug", Support.BugEmail)).OnEvent("Click", (*) => this.Owner.ReportBug())
        win.AddText("x28 y342 w544", T("about.author"))
        win.AddText(Format("x28 y364 w544 h32 {}", muted), T("about.disclaimer"))
        win.AddText(Format("x28 y400 w544 h32 {}", muted), T("about.config", this.Owner.Cfg.Path))
        tabs.UseTab()

        ; --- Support (visible on every tab): a greeting, the story, then donation buttons ---
        win.SetFont("s11 bold")
        win.AddText("x16 y484 w568", T("support.hello"))
        win.SetFont("s9 norm")
        win.AddText("x16 y510 w568 h32", T("support.cta"))
        x := 16
        for link in Support.Links(Lang.Current) {
            width := link.Name = "GitHub Sponsors" ? 120 : 100
            win.AddButton(Format("x{} y564 w{} h28", x, width), link.Name).OnEvent("Click", ((l, *) => Support.Open(l)).Bind(link))
            x += width + 6
        }

        ; --- Footer ---
        win.AddButton("x396 y564 w90 h28", T("btn.cancel")).OnEvent("Click", (*) => this.Close())
        win.AddButton("x494 y564 w90 h28 Default", T("btn.save")).OnEvent("Click", (*) => this.Save())
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
        this.ShowTab(SettingsWindow.TAB_SHORTCUTS)
        this.Recording := action
        this.Owner.Hotkeys.SetPaused(true)
        row := this.Rows[action]
        row.Field.Value := T("record.prompt")
        row.Record.Text := T("btn.stop_record")
        this.Recorder.Start(ObjBindMethod(this, "_OnRecorded"), ObjBindMethod(this, "_OnRecordTimeout"))
        Log.Write("recording shortcut for " action)
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
        this.Owner.UpdateHotkeys()
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
        this.WisprStatus.SetFont(running ? "c1E7B34" : SettingsWindow.ColorError)
        this.WisprStatus.Value := T(running ? "wispr.running" : "wispr.not_running")
    }

    Save() {
        this._EndRecording()
        errors := []
        for issue in this._Validate()
            if issue.Level = "error"
                errors.Push(T("action." issue.Action) ": " SettingsWindow.IssueText(issue))
        if errors.Length {
            this.ShowTab(SettingsWindow.TAB_SHORTCUTS)
            MsgBox(T("save.errors") "`n`n" SettingsWindow._Lines(errors), T("settings.title", App.Version), "Icon!")
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
            this.ShowTab(SettingsWindow.TAB_ADVANCED)
            MsgBox(T("save.errors") "`n`n" SettingsWindow._Lines(advErrors), T("settings.title", App.Version), "Icon!")
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
        this.HowtoPane.Destroy()
        this.Win.Destroy()
        SettingsWindow.Instance := ""
    }

    static WebsiteLink() => Format('<a href="{1}">{2}</a>', App.WebsiteUrl, App.WebsiteName)

    static _Lines(list) {
        text := ""
        for line in list
            text .= "• " line "`n"
        return text
    }
}
