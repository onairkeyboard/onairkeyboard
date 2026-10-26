; Tray icon and menu. The icon mirrors the recording state (red keycap while recording), so
; OnAirKey works as an indicator even without a keyboard LED. The idle keycap is black on a
; light taskbar and white on a dark one, so it never blends in.
class TrayUI {
    __New(owner) {
        this.Owner := owner
        this.PauseLabel := ""
        this.Icon := ""
    }

    static IconFile(name) {
        if A_IsCompiled
            return A_ScriptFullPath
        return TrayUI._FullPath(A_LineFile "\..\..\assets\" name ".ico")
    }

    ; Resource numbers of the tray icons embedded by Ahk2Exe (see build script)
    static IconResource := Map("tray-idle-light", -160, "tray-rec", -161, "tray-idle-dark", -162)

    ; Windows 10 / 11 taskbar colour (the "Windows mode" setting; absent before 1903 = dark)
    static LightTaskbar() => RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "SystemUsesLightTheme", 0) = 1

    Build() {
        ; Note: AutoHotkey names are case-insensitive, so locals must not be called
        ; "menu", "support" or "app" (they would hide the Menu, Support and App classes).
        tray := A_TrayMenu
        tray.Delete()
        owner := this.Owner

        supportMenu := Menu()
        for link in Support.Links(Lang.Current)
            supportMenu.Add(link.Name, ((l, *) => Support.Open(l)).Bind(link))

        tray.Add(T("tray.settings"), (*) => owner.OpenSettings())
        tray.Add(T("tray.support"), supportMenu)
        tray.Add()
        tray.Add(T("tray.test_led"), (*) => owner.TestLed())
        this.PauseLabel := T(owner.Paused ? "tray.resume" : "tray.pause")
        tray.Add(this.PauseLabel, (*) => owner.TogglePause())
        tray.Add(T("tray.open_log"), (*) => owner.OpenLog())
        tray.Add(T("tray.report_bug"), (*) => owner.ReportBug())
        tray.Add()
        tray.Add(T("tray.website"), (*) => Run(App.WebsiteUrl))
        tray.Add(T("tray.about"), (*) => owner.ShowAbout())
        tray.Add(T("tray.exit"), (*) => ExitApp())
        tray.Default := T("tray.settings")
        tray.ClickCount := 2
        this.Update()
    }

    Update() {
        owner := this.Owner
        label := T(owner.Paused ? "tray.resume" : "tray.pause")
        if this.PauseLabel != "" && label != this.PauseLabel {
            A_TrayMenu.Rename(this.PauseLabel, label)
            this.PauseLabel := label
        }

        recording := !owner.Paused && owner.State.IsRecording
        if recording && owner.Cfg.TrayIconShowsState
            icon := "tray-rec"
        else
            icon := TrayUI.LightTaskbar() ? "tray-idle-light" : "tray-idle-dark"
        if icon != this.Icon {
            if A_IsCompiled
                TraySetIcon(A_ScriptFullPath, TrayUI.IconResource[icon])
            else
                TraySetIcon(TrayUI.IconFile(icon))
            this.Icon := icon
            Log.Write("tray icon " icon)
        }

        if owner.Paused
            A_IconTip := T("tip.paused")
        else if !owner.WisprRunning
            A_IconTip := T("tip.no_wispr")
        else if !owner.Hotkeys.HasShortcuts
            A_IconTip := T("tip.no_shortcuts")
        else
            A_IconTip := T(recording ? "tip.recording" : "tip.idle")
    }

    static _FullPath(path) {
        buf := Buffer(1040)
        DllCall("GetFullPathNameW", "Str", path, "UInt", 520, "Ptr", buf, "Ptr", 0)
        return StrGet(buf)
    }
}
