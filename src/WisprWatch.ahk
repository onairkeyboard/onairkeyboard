; Watches the Wispr Flow helper process.
;
; The most recently installed keyboard hook sees keys first. When the helper starts after
; OnAirKey (typical at Windows startup), it intercepts its own shortcuts and OnAirKey never
; sees them. After every (re)start of the helper we reinstall our hook to be first again;
; more than one attempt, because the helper may install its hook with a delay.
; onChange(running) is called after the first check and whenever the helper starts or exits.
class WisprWatch {
    __New(processName, reinstallDelaysMs, onChange := "") {
        this.ProcessName := processName
        this.ReinstallDelaysMs := reinstallDelaysMs
        this.OnChange := onChange
        this.Pid := 0
        this.Checked := false
        this._check := ObjBindMethod(this, "Check")
    }

    IsRunning => ProcessExist(this.ProcessName) != 0

    Start(intervalMs := 3000) {
        this.Check()
        SetTimer(this._check, intervalMs)
    }

    Stop() => SetTimer(this._check, 0)

    Check() {
        pid := ProcessExist(this.ProcessName)
        if pid && pid != this.Pid {
            Log.Write("Wispr helper running, pid " pid)
            ; A separate bound object per delay, so the timers don't replace each other
            for delay in this.ReinstallDelaysMs
                SetTimer(ObjBindMethod(WisprWatch, "ReinstallHook"), -Max(delay, 1))
        } else if !pid && (this.Pid || !this.Checked) {
            Log.Write(this.Checked ? "Wispr helper exited" : "Wispr helper not running")
        }
        changed := !this.Checked || (pid != 0) != (this.Pid != 0)
        this.Pid := pid
        this.Checked := true
        if changed && this.OnChange
            this.OnChange.Call(pid != 0)
    }

    static ReinstallHook() {
        InstallKeybdHook(true, true)
        Log.Write("keyboard hook reinstalled")
    }
}
