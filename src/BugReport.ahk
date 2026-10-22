; "Report a bug" window: the address, a subject and a prefilled e-mail text to copy into any
; mail app. No mailto: many people only use webmail and have no mail app set up.
class BugReportWindow {
    static Instance := ""

    ; diag: technical details, one per line; logFile: diagnostic log, "" while it's turned off
    static Open(diag, logFile) {
        if BugReportWindow.Instance
            BugReportWindow.Instance.Close()  ; rebuilt, because the details may have changed
        Critical  ; same reason as SettingsWindow.Open
        BugReportWindow.Instance := BugReportWindow(diag, logFile)
    }

    __New(diag, logFile) {
        this.Body := StrReplace(Support.BugBody(diag), "`n", "`r`n")
        win := Gui("-MaximizeBox -MinimizeBox", T("bug.title"))
        win.SetFont("s9", "Segoe UI")
        win.OnEvent("Close", (*) => this.Close())
        win.OnEvent("Escape", (*) => this.Close())
        this.Win := win

        win.AddText("x16 y14 w488", T("bug.intro"))
        win.AddText("x16 y43 w60", T("bug.address"))
        win.AddEdit("x80 y40 w424 ReadOnly", Support.BugEmail)
        win.AddText("x16 y73 w60", T("bug.subject_label"))
        win.AddEdit("x80 y70 w424 ReadOnly", T("bug.subject", App.Version))

        ; The text below is a template: it must be completed, and the log attached
        win.SetFont("bold")
        win.AddText(Format("x16 y106 w488 h32 {}", SettingsWindow.ColorWarning), T("bug.notice"))
        win.SetFont("norm")
        if logFile != "" && FileExist(logFile)
            win.AddLink("x16 y142 w488", T("bug.log_show"))
                .OnEvent("Click", (*) => Run('explorer.exe /select,"' logFile '"'))
        else
            win.AddText(Format("x16 y142 w488 h32 {}", SettingsWindow.ColorMuted), T("bug.log_off"))

        win.AddText("x16 y180 w488", T("bug.text_label"))
        win.AddEdit("x16 y200 w488 h220 ReadOnly Multi VScroll", this.Body)

        win.AddButton("x16 y432 w130 h28", T("bug.copy_address"))
            .OnEvent("Click", (*) => this._Copy(Support.BugEmail, "bug.address_copied"))
        copyText := win.AddButton("x154 y432 w130 h28", T("bug.copy_text"))
        copyText.OnEvent("Click", (*) => this._Copy(this.Body, "bug.text_copied"))
        this.Status := win.AddText("x292 y438 w124 c1E7B34", "")
        win.AddButton("x424 y432 w80 h28", T("btn.close")).OnEvent("Click", (*) => this.Close())

        win.Show("w520 h476")
        copyText.Focus()
    }

    _Copy(text, doneKey) {
        A_Clipboard := text
        this.Status.Value := T(doneKey)
    }

    Close() {
        this.Win.Destroy()
        BugReportWindow.Instance := ""
    }
}
