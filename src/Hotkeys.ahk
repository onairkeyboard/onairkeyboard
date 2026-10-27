; Listens for the Wispr shortcuts and feeds the recording state.
; Every hotkey uses ~ (the key still reaches Wispr) and * (fires regardless of modifiers;
; the exact modifiers are checked in code, so the release order of a macro pad doesn't matter).
class HotkeyEngine {
    static HoldActions := Map("PushToTalk", true, "CommandMode", true)

    __New(state) {
        this.State := state
        this.Paused := false
        this.Ignored := false       ; events dropped, state kept (the Wispr Flow window is active)
        this.Registered := []
        this.MainKeys := Map()      ; key -> array of {Action, Mods}
        this.KeysDown := Map()      ; main keys currently down (to skip auto-repeat)
        this.ActiveByKey := Map()   ; main key -> action started by it
        this.Session := ""
        this.Input := ""
    }

    ; shortcuts: action -> Shortcut (already validated)
    Register(shortcuts) {
        this.Unregister()
        modEntries := []
        for action, sc in shortcuts {
            if sc.IsModifierOnly {
                modEntries.Push({Action: action, Mods: sc.Mods, IsHold: HotkeyEngine.HoldActions.Has(action)})
                continue
            }
            if !this.MainKeys.Has(sc.Key) {
                this.MainKeys[sc.Key] := []
                this._Hotkey("~*" sc.Key, ObjBindMethod(this, "OnKeyDown", sc.Key))
                this._Hotkey("~*" sc.Key " up", ObjBindMethod(this, "OnKeyUp", sc.Key))
            }
            this.MainKeys[sc.Key].Push({Action: action, Mods: sc.Mods})
        }
        if modEntries.Length {
            this.Session := ModSession(modEntries)
            for key in Shortcut.ModifierKeys {
                this._Hotkey("~*" key, ObjBindMethod(this, "OnModifier", key, true))
                this._Hotkey("~*" key " up", ObjBindMethod(this, "OnModifier", key, false))
            }
            ; Sees every other key, to cancel a modifier-only hold on unrelated shortcuts
            this.Input := InputHook("V L0")
            this.Input.KeyOpt("{All}", "N")
            this.Input.OnKeyDown := ObjBindMethod(this, "OnAnyKey")
            this.Input.Start()
        }
        Log.Write("registered " this.Registered.Length " hotkeys")
    }

    Unregister() {
        for name in this.Registered
            try Hotkey(name, "Off")
        this.Registered := []
        this.MainKeys := Map()
        this.KeysDown := Map()
        this.ActiveByKey := Map()
        this.Session := ""
        if this.Input {
            this.Input.Stop()
            this.Input := ""
        }
    }

    ; Paused: events are ignored (used while recording a shortcut in settings and by Pause)
    SetPaused(paused) {
        this.Paused := paused
        this.KeysDown := Map()
        this.ActiveByKey := Map()
        if this.Session
            this.Session._Reset()
        this.State.Reset()
    }

    HasShortcuts => this.Registered.Length > 0

    _Hotkey(name, callback) {
        Hotkey(name, callback, "On")
        this.Registered.Push(name)
    }

    OnKeyDown(key, *) {
        if this.KeysDown.Has(key)  ; auto-repeat
            return
        this.KeysDown[key] := true
        if this.Paused || this.Ignored {
            Log.Write(key " ignored (" (this.Ignored ? "Wispr Flow window active" : "shortcuts paused") ")")
            return
        }
        mods := Shortcut.CurrentMods()
        for entry in this.MainKeys[key] {
            if entry.Mods = mods {
                this.ActiveByKey[key] := entry.Action
                this._Dispatch(entry.Action, "down")
                return
            }
        }
    }

    OnKeyUp(key, *) {
        if this.KeysDown.Has(key)
            this.KeysDown.Delete(key)
        if this.Paused || this.Ignored || !this.ActiveByKey.Has(key)
            return
        action := this.ActiveByKey.Delete(key)
        this._Dispatch(action, "up")
    }

    OnModifier(key, down, *) {
        if this.Paused || this.Ignored
            return
        for pair in this.Session.OnModsChanged(Shortcut.CurrentMods(key, down), A_TickCount)
            this._Dispatch(pair[1], pair[2])
    }

    OnAnyKey(ih, vk, sc) {
        if this.Paused || this.Ignored
            return
        name := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
        if Shortcut.ModifierKeys.Has(name)
            return
        for pair in this.Session.OnOtherKey(this.MainKeys.Has(name), A_TickCount)
            this._Dispatch(pair[1], pair[2])
    }

    _Dispatch(action, edge) {
        Log.Write(action " " edge)
        if HotkeyEngine.HoldActions.Has(action) {
            if edge = "down"
                this.State.HoldDown(action)
            else
                this.State.HoldUp(action)
        } else if edge = "down" {
            if action = "HandsFree"
                this.State.ToggleHandsFree()
            else if action = "Cancel"
                this.State.Reset()
        }
    }
}
