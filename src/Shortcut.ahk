; A parsed shortcut: modifier bitmask + optional main key.
;   "Ctrl+Shift+F13" -> Mods = Ctrl|Shift, Key = "F13"
;   "Ctrl+Win"       -> Mods = Ctrl|Win,   Key = ""   (modifier-only, Wispr's default push to talk)
;   "Escape"         -> Mods = 0,          Key = "Escape"
; Left and right modifiers are treated alike.
class Shortcut {
    static CTRL := 1, ALT := 2, SHIFT := 4, WIN := 8
    static ModNames := [["Ctrl", 1], ["Alt", 2], ["Shift", 4], ["Win", 8]]
    static ModAliases := Map(
        "ctrl", 1, "control", 1, "lctrl", 1, "rctrl", 1,
        "alt", 2, "lalt", 2, "ralt", 2,
        "shift", 4, "lshift", 4, "rshift", 4,
        "win", 8, "windows", 8, "lwin", 8, "rwin", 8)

    ; Physical modifier keys, used for hotkeys and to tell modifiers apart from other keys
    static ModifierKeys := Map(
        "LControl", 1, "RControl", 1, "LAlt", 2, "RAlt", 2,
        "LShift", 4, "RShift", 4, "LWin", 8, "RWin", 8)

    __New(mods, key) {
        this.Mods := mods
        this.Key := key
    }

    IsModifierOnly => this.Key = ""
    KeyCount => Shortcut.CountBits(this.Mods) + (this.Key = "" ? 0 : 1)
    Text => Shortcut.ModsText(this.Mods) (this.Key = "" ? "" : (this.Mods ? "+" : "") Shortcut.DisplayKey(this.Key))

    ; Returns a Shortcut, or "" for an empty string.
    ; Throws ValueError(code, , detail) with code: empty_part, duplicate_modifier, unknown_key,
    ; multiple_keys, too_many_keys.
    static Parse(text) {
        text := Trim(text)
        if text = ""
            return ""
        mods := 0, key := ""
        for part in StrSplit(text, "+") {
            part := Trim(part)
            if part = ""
                throw ValueError("empty_part", , text)
            if Shortcut.ModAliases.Has(StrLower(part)) {
                bit := Shortcut.ModAliases[StrLower(part)]
                if mods & bit
                    throw ValueError("duplicate_modifier", , part)
                mods |= bit
                continue
            }
            name := GetKeyName(part)
            if name = "" || Shortcut.ModifierKeys.Has(name)
                throw ValueError("unknown_key", , part)
            if key != ""
                throw ValueError("multiple_keys", , part)
            key := name
        }
        sc := Shortcut(mods, key)
        if sc.KeyCount > 3
            throw ValueError("too_many_keys", , text)
        return sc
    }

    static ModsText(mods) {
        text := ""
        for pair in Shortcut.ModNames
            if mods & pair[2]
                text .= (text = "" ? "" : "+") pair[1]
        return text
    }

    static DisplayKey(key) => StrLen(key) = 1 ? StrUpper(key) : key

    static CountBits(n) {
        count := 0
        while n {
            count += n & 1
            n >>= 1
        }
        return count
    }

    ; Logical modifier state right now, optionally overriding one physical key whose
    ; event is being handled (its state may not be updated yet).
    static CurrentMods(eventKey := "", eventDown := false) {
        mods := 0
        for key, bit in Shortcut.ModifierKeys {
            down := key = eventKey ? eventDown : GetKeyState(key)
            if down
                mods |= bit
        }
        return mods
    }

    ; Checks a whole set of shortcuts (action -> text) the way Wispr Flow would accept them.
    ; Returns an array of issues: {Action, Level: "error" | "warning", Code, Detail}.
    ; Actions with an error must not be registered.
    static ValidateSet(shortcuts, lockName) {
        issues := []
        seen := Map()
        add(action, level, code, detail := "") => issues.Push({Action: action, Level: level, Code: code, Detail: detail})
        for action in Config.Actions {
            text := shortcuts.Has(action) ? shortcuts[action] : ""
            try sc := Shortcut.Parse(text)
            catch ValueError as e {
                add(action, "error", e.Message, e.Extra)
                continue
            }
            if !IsObject(sc)
                continue

            if seen.Has(sc.Text) {
                add(action, "error", "duplicate", seen[sc.Text])
                continue
            }
            seen[sc.Text] := action

            if sc.Mods = 0 {
                allowed := (sc.Key = "CapsLock" && (action = "PushToTalk" || action = "HandsFree"))
                    || (sc.Key = "Escape" && action = "Cancel")
                if !allowed {
                    add(action, "error", "needs_modifier")
                    continue
                }
            }
            if sc.IsModifierOnly && Shortcut.CountBits(sc.Mods) < 2 {
                add(action, "error", "single_modifier")
                continue
            }
            if sc.Key = "CapsLock" && lockName = "CapsLock" {
                add(action, "error", "capslock_conflict")
                continue
            }
            if sc.Mods = 0 && sc.Key = "Escape"
                add(action, "warning", "escape_cancel")
            else if sc.Key = "Escape" && sc.Mods & Shortcut.CTRL
                add(action, "warning", "ctrl_escape")
        }
        return issues
    }

    ; Parsed shortcuts without errors: action -> Shortcut
    static ValidShortcuts(shortcuts, lockName, &issues) {
        issues := Shortcut.ValidateSet(shortcuts, lockName)
        bad := Map()
        for issue in issues
            if issue.Level = "error"
                bad[issue.Action] := true
        valid := Map()
        for action in Config.Actions
            if !bad.Has(action) && shortcuts.Has(action) && IsObject(sc := Shortcut.Parse(shortcuts[action]))
                valid[action] := sc
        return valid
    }
}
