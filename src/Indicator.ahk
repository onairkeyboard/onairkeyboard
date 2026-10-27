; Drives the keyboard LED through a Lock key state (Scroll Lock by default).
;
; The state is enforced by a timer instead of being set once: right after dictation stops,
; Wispr Flow briefly blocks injected keys, so a single change can get lost.
; Resync flips the Lock back and forth, because Windows sends the Lock state to keyboards
; only when it changes (after boot, replug or wake the LED can show a stale state).
class Indicator {
    static Setters := Map("ScrollLock", SetScrollLockState, "NumLock", SetNumLockState, "CapsLock", SetCapsLockState)

    ; wantFn: returns true while recording
    __New(lockName, wantFn) {
        this.LockName := lockName
        this.WantFn := wantFn
        this.Paused := false
        this.Testing := false
        this.Held := false  ; leave the Lock as it is (the Wispr Flow window is active)
        this._sync := ObjBindMethod(this, "Sync")
        this._resync := ObjBindMethod(this, "Resync")
    }

    Wanted => !this.Paused && this.WantFn.Call()

    ; Blinks the LED so the user can check the keyboard setup. Sync is held off meanwhile.
    Blink(times := 3, intervalMs := 300) {
        if this.Testing
            return
        this.Testing := true
        Loop times {
            this.Set(true)
            Sleep(intervalMs)
            this.Set(false)
            Sleep(intervalMs)
        }
        this.Testing := false
        this.Sync()
    }
    IsOn => GetKeyState(this.LockName, "T")

    Set(on) => Indicator.Setters[this.LockName].Call(on ? true : false)

    Start(syncIntervalMs, resyncDelayMs) {
        this.Sync()
        SetTimer(this._sync, syncIntervalMs)
        this.ScheduleResync(resyncDelayMs)
    }

    Stop() {
        SetTimer(this._sync, 0)
        SetTimer(this._resync, 0)
        this.Set(false)
    }

    Sync() {
        if this.Testing || this.Held
            return
        want := this.Wanted
        if this.IsOn != want {
            this.Set(want)
            Log.Write(this.LockName " -> " want)
        }
    }

    ; Repeated calls within the delay collapse into one resync.
    ScheduleResync(delayMs) => SetTimer(this._resync, -Max(delayMs, 1))

    Resync() {
        if this.Testing || this.Held
            return
        want := this.Wanted
        this.Set(!want)
        Sleep(50)
        this.Set(want)
        Log.Write("resync " this.LockName)
    }
}
