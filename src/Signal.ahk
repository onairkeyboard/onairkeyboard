; Where "are we on air?" comes from ([Signal] Source):
;   Microphone  a ticked app uses the microphone (default, nothing to set up)
;   Shortcuts   the state from the Wispr Flow shortcuts, as in v0.1
;   Both        a shortcut turns it on at once, the microphone corrects it (HybridGate)
class Signal {
    static Sources := ["Microphone", "Shortcuts", "Both"]

    static OnAir(source, shortcutsOn, micOn) {
        switch source {
            case "Shortcuts": return shortcutsOn
            case "Both": return shortcutsOn || micOn
            default: return micOn
        }
    }

    static UsesShortcuts(source) => source = "Shortcuts" || source = "Both"
}

; Hybrid mode: after a shortcut turned recording on, Wispr Flow's microphone must open within
; graceMs and stay open (with gaps shorter than graceMs). Otherwise the shortcut state is reset,
; which ends the drift after stopping with the mouse or an automatic end of recording.
; graceMs is long by default because Wispr's Push to talk opens the microphone after 4-5 s.
class HybridGate {
    __New(graceMs) {
        this.GraceMs := graceMs
        this.Since := 0
    }

    ; Called on every microphone poll. Returns true when the shortcut state should be reset.
    Tick(now, shortcutsOn, wisprMicOn) {
        if !shortcutsOn || wisprMicOn {
            this.Since := 0
            return false
        }
        if !this.Since {
            this.Since := now
            return false
        }
        if now - this.Since < this.GraceMs
            return false
        this.Since := 0  ; counted afresh after the reset
        return true
    }
}

; Self-protection while setting up Wispr Flow: when its window is active, OnAir keyboard ignores
; shortcuts and leaves the Lock alone, because the injected Lock key would land inside the
; combination being recorded in Wispr Flow. onChange(active) runs when the window gains or loses focus.
class WindowGuard {
    __New(processName, onChange := "") {
        this.ProcessName := processName
        this.OnChange := onChange
        this.Active := false
        this._check := ObjBindMethod(this, "Check")
    }

    Start(intervalMs := 250) {
        this.Check()
        SetTimer(this._check, intervalMs)
    }

    Stop() {
        SetTimer(this._check, 0)
        if this.Active {
            this.Active := false
            if this.OnChange
                this.OnChange.Call(false)
        }
    }

    Check() {
        active := WinActive("ahk_exe " this.ProcessName) != 0
        if active = this.Active
            return
        this.Active := active
        Log.Write("Wispr Flow window " (active ? "active, shortcuts on hold" : "inactive"))
        if this.OnChange
            this.OnChange.Call(active)
    }
}
