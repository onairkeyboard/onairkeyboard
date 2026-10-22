; Decides what modifier-only shortcuts (such as Wispr's default Ctrl+Win) do, from a stream of
; modifier changes and other key presses. Pure logic: returns [action, "down" | "up"] pairs
; for the caller to dispatch, so it can be unit-tested without a keyboard.
;
; Rules (mirroring Wispr Flow):
; - a hold action is active while the held modifiers exactly match it;
; - a toggle / reset action fires once when the modifiers first match, per session;
; - a session lasts until all modifiers are released;
; - pressing an unrelated key within ForeignWindowMs of a hold starting cancels it
;   (Wispr cancels when you switch to a system shortcut such as Ctrl+Win+Left), and
;   an unrelated key pressed before any match stops the session from matching later.
class ModSession {
    ; entries: array of {Action, Mods, IsHold}
    __New(entries, foreignWindowMs := 1000) {
        this.Entries := entries
        this.ForeignWindowMs := foreignWindowMs
        this._Reset()
    }

    _Reset() {
        this.Mods := 0
        this.Active := ""
        this.StartTick := 0
        this.Foreign := false
        this.Fired := Map()
    }

    OnModsChanged(mods, tick) {
        out := []
        if mods = 0 {
            if this.Active != ""
                out.Push([this.Active, "up"])
            this._Reset()
            return out
        }
        this.Mods := mods
        if this.Foreign
            return out

        newActive := ""
        for entry in this.Entries {
            if entry.Mods != mods
                continue
            if entry.IsHold
                newActive := entry.Action
            else if !this.Fired.Has(entry.Action) {
                this.Fired[entry.Action] := true
                out.Push([entry.Action, "down"])
            }
            break
        }
        if newActive != this.Active {
            ; start the new hold before ending the old one, so recording never blinks off
            if newActive != "" {
                out.Push([newActive, "down"])
                this.StartTick := tick
            }
            if this.Active != ""
                out.Push([this.Active, "up"])
            this.Active := newActive
        }
        return out
    }

    ; isShortcutKey: the key is the main key of a configured shortcut (that shortcut handles it)
    OnOtherKey(isShortcutKey, tick) {
        out := []
        if this.Mods = 0 || isShortcutKey
            return out
        if this.Active = "" {
            this.Foreign := true
        } else if tick - this.StartTick < this.ForeignWindowMs {
            out.Push([this.Active, "up"])
            this.Active := ""
            this.Foreign := true
        }
        return out
    }
}
