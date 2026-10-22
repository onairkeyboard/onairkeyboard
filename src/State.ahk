; Recording state derived from the Wispr shortcuts the user pressed.
; recording := pttHeld || cmdHeld || handsFree  (no double-tap detection, by design)
class RecState {
    __New(onChange := "") {
        this.pttHeld := false
        this.cmdHeld := false
        this.handsFree := false
        this.OnChange := onChange
    }

    IsRecording => this.pttHeld || this.cmdHeld || this.handsFree

    ; action: "PushToTalk" or "CommandMode"
    HoldDown(action) => this._Change(() => this._SetHold(action, true))
    HoldUp(action) => this._Change(() => this._SetHold(action, false))
    ToggleHandsFree() => this._Change(() => this.handsFree := !this.handsFree)
    Reset() => this._Change(() => (this.pttHeld := false, this.cmdHeld := false, this.handsFree := false))

    _SetHold(action, held) {
        if action = "PushToTalk"
            this.pttHeld := held
        else if action = "CommandMode"
            this.cmdHeld := held
        else
            throw ValueError("Not a hold action: " action)
    }

    _Change(mutate) {
        before := this.IsRecording
        mutate()
        after := this.IsRecording
        if before != after && this.OnChange
            this.OnChange.Call(after)
    }
}
