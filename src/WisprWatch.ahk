; Watches the Wispr Flow helper process.
;
; The most recently installed keyboard hook sees keys first. When the helper starts after
; OnAirKey (typical at Windows startup), it intercepts its own shortcuts and OnAirKey never
; sees them. After every (re)start of the helper we reinstall our hook to be first again;
; more than one attempt, because the helper may install its hook with a delay.
class WisprWatch {
    __New(processName, reinstallDelaysMs) {
        this.ProcessName := processName
        this.ReinstallDelaysMs := reinstallDelaysMs
        this.Pid := 0
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
        }
        this.Pid := pid
    }

    static ReinstallHook() {
        InstallKeybdHook(true, true)
        Log.Write("keyboard hook reinstalled")
    }
}
