; Records one shortcut from the keyboard, for the settings window.

; Pure logic: turns key down / up events into a shortcut text.
; - a non-modifier key finishes the shortcut with the modifiers held at that moment;
; - releasing all modifiers without another key finishes a modifier-only shortcut
;   made of every modifier that was held together (e.g. Ctrl+Win).
class ComboRecorder {
    __New() {
        this.Down := Map()
        this.PeakMods := 0
    }

    ; Returns the finished shortcut text, or "" while still recording.
    KeyDown(name) {
        if Shortcut.ModifierKeys.Has(name) {
            this.Down[name] := true
            this.PeakMods |= this._Mods()
            return ""
        }
        return Shortcut(this._Mods(), name).Text
    }

    KeyUp(name) {
        if !Shortcut.ModifierKeys.Has(name) || !this.Down.Has(name)
            return ""
        this.Down.Delete(name)
        if this.Down.Count = 0 && this.PeakMods
            return Shortcut(this.PeakMods, "").Text
        return ""
    }

    _Mods() {
        mods := 0
        for key in this.Down
            mods |= Shortcut.ModifierKeys[key]
        return mods
    }
}

; Keyboard wrapper. Keys are suppressed while recording, so Escape doesn't close anything,
; Caps Lock doesn't toggle and Win doesn't open the Start menu. Wispr Flow may still react,
; because its own hook can see keys before ours.
class KeyRecorder {
    __New() {
        this.Hook := ""
    }

    IsActive => this.Hook != ""

    ; onDone(text) gets the shortcut; onTimeout() runs when nothing was pressed in time.
    Start(onDone, onTimeout, timeoutMs := 5000) {
        this.Stop()
        logic := ComboRecorder()
        hook := InputHook("L0 T" Round(timeoutMs / 1000, 1))
        hook.KeyOpt("{All}", "NS")
        finish(text) {
            if text = ""
                return
            this.Stop()
            onDone(text)
        }
        hook.OnKeyDown := (ih, vk, sc) => finish(logic.KeyDown(KeyRecorder.KeyName(vk, sc)))
        hook.OnKeyUp := (ih, vk, sc) => finish(logic.KeyUp(KeyRecorder.KeyName(vk, sc)))
        hook.OnEnd := (ih) => (ih.EndReason = "Timeout" && this.Hook = ih) ? (this.Hook := "", onTimeout()) : ""
        this.Hook := hook
        hook.Start()
    }

    Stop() {
        hook := this.Hook
        this.Hook := ""
        if hook
            hook.Stop()
    }

    static KeyName(vk, sc) => GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
}
