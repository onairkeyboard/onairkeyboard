#Requires AutoHotkey v2.0
; Unit tests for shortcut parsing, validation and modifier-only sessions.
; Run: AutoHotkey64.exe /ErrorStdOut tests\TestShortcuts.ahk   (exit code = number of failures)

#Include %A_LineFile%\..\..\src\Log.ahk
#Include %A_LineFile%\..\..\src\Config.ahk
#Include %A_LineFile%\..\..\src\Shortcut.ahk
#Include %A_LineFile%\..\..\src\ModSession.ahk
#Include %A_LineFile%\..\..\src\KeyRecorder.ahk
#Include %A_LineFile%\..\..\src\Autostart.ahk
#Include %A_LineFile%\..\TestLib.ahk

ParseText(text) {
    try {
        sc := Shortcut.Parse(text)
        return IsObject(sc) ? sc.Text : "<empty>"
    } catch ValueError as e
        return "!" e.Message
}

Codes(shortcuts, lock := "ScrollLock") {
    text := ""
    for issue in Shortcut.ValidateSet(shortcuts, lock)
        text .= (text = "" ? "" : " ") issue.Action ":" issue.Level ":" issue.Code
    return text
}

Pairs(list) {
    text := ""
    for pair in list
        text .= (text = "" ? "" : " ") pair[1] ":" pair[2]
    return text
}

; --- Parse ---
Check("parse basic", ParseText("Ctrl+Shift+F13"), "Ctrl+Shift+F13")
Check("parse order + case", ParseText("shift + CONTROL + f13"), "Ctrl+Shift+F13")
Check("parse modifier only", ParseText("Win+Ctrl"), "Ctrl+Win")
Check("parse sided modifiers", ParseText("LCtrl+RWin"), "Ctrl+Win")
Check("parse esc alias", ParseText("Esc"), "Escape")
Check("parse letter", ParseText("Ctrl+Alt+a"), "Ctrl+Alt+A")
Check("parse space", ParseText("Ctrl+Win+Space"), "Ctrl+Win+Space")
Check("parse empty", ParseText("  "), "<empty>")
Check("parse unknown", ParseText("Ctrl+Bogus"), "!unknown_key")
Check("parse two keys", ParseText("Ctrl+A+B"), "!multiple_keys")
Check("parse dup mod", ParseText("Ctrl+Control+F1"), "!duplicate_modifier")
Check("parse empty part", ParseText("Ctrl++F1"), "!empty_part")
Check("parse too many", ParseText("Ctrl+Alt+Shift+F1"), "!too_many_keys")
Check("parse round trip", ParseText(ParseText("ctrl+shift+f24")), "Ctrl+Shift+F24")
sc := Shortcut.Parse("Ctrl+Win")
Check("modifier only flag", sc.IsModifierOnly, true)
Check("mods mask", sc.Mods, Shortcut.CTRL | Shortcut.WIN)

; --- ValidateSet ---
Check("valid sayo set", Codes(Map("PushToTalk", "Ctrl+Shift+F13", "HandsFree", "Ctrl+Shift+F14",
    "Cancel", "Ctrl+Shift+F16")), "")
Check("valid wispr defaults", Codes(Map("PushToTalk", "Ctrl+Win", "HandsFree", "Ctrl+Win+Space",
    "Cancel", "Escape", "CommandMode", "Ctrl+Win+Alt")), "Cancel:warning:escape_cancel")
Check("duplicate", Codes(Map("PushToTalk", "Ctrl+Shift+F13", "HandsFree", "shift+ctrl+f13")),
    "HandsFree:error:duplicate")
Check("needs modifier", Codes(Map("PushToTalk", "F13")), "PushToTalk:error:needs_modifier")
Check("escape only for cancel", Codes(Map("HandsFree", "Escape")), "HandsFree:error:needs_modifier")
Check("capslock alone ok", Codes(Map("PushToTalk", "CapsLock")), "")
Check("capslock alone not cancel", Codes(Map("Cancel", "CapsLock")), "Cancel:error:needs_modifier")
Check("capslock vs lock", Codes(Map("PushToTalk", "CapsLock"), "CapsLock"), "PushToTalk:error:capslock_conflict")
Check("single modifier", Codes(Map("PushToTalk", "Ctrl")), "PushToTalk:error:single_modifier")
Check("ctrl escape warns", Codes(Map("Cancel", "Ctrl+Escape")), "Cancel:warning:ctrl_escape")
Check("parse error reported", Codes(Map("Cancel", "Ctrl+Nope")), "Cancel:error:unknown_key")

valid := Shortcut.ValidShortcuts(Map("PushToTalk", "F13", "HandsFree", "Ctrl+F14", "Cancel", "Escape"), "ScrollLock", &issues)
Check("valid skips errors", valid.Has("PushToTalk"), false)
Check("valid keeps ok", valid.Has("HandsFree") && valid.Has("Cancel"), true)
Check("valid keeps warnings", issues.Length, 2)

; --- ModSession (Wispr defaults: PTT Ctrl+Win, Command Mode Ctrl+Win+Alt) ---
C := Shortcut.CTRL, A := Shortcut.ALT, W := Shortcut.WIN, SH := Shortcut.SHIFT
entries := [{Action: "PushToTalk", Mods: C | W, IsHold: true}
    , {Action: "CommandMode", Mods: C | W | A, IsHold: true}
    , {Action: "Cancel", Mods: C | SH, IsHold: false}]

ses := ModSession(entries)
Check("ctrl only", Pairs(ses.OnModsChanged(C, 0)), "")
Check("ctrl+win starts ptt", Pairs(ses.OnModsChanged(C | W, 10)), "PushToTalk:down")
Check("repeat no change", Pairs(ses.OnModsChanged(C | W, 20)), "")
Check("alt switches, new first", Pairs(ses.OnModsChanged(C | W | A, 30)), "CommandMode:down PushToTalk:up")
Check("alt released", Pairs(ses.OnModsChanged(C | W, 40)), "PushToTalk:down CommandMode:up")
Check("win released", Pairs(ses.OnModsChanged(C, 50)), "PushToTalk:up")
Check("all released", Pairs(ses.OnModsChanged(0, 60)), "")

ses := ModSession(entries)
ses.OnModsChanged(C | W, 0)
Check("shortcut key keeps hold", Pairs(ses.OnOtherKey(true, 100)), "")
Check("foreign key early cancels", Pairs(ses.OnOtherKey(false, 200)), "PushToTalk:up")
Check("no restart after foreign", Pairs(ses.OnModsChanged(C | W | A, 300)), "")
Check("release resets", Pairs(ses.OnModsChanged(0, 400)), "")
Check("new session works", Pairs(ses.OnModsChanged(C | W, 500)), "PushToTalk:down")

ses := ModSession(entries)
ses.OnModsChanged(C | W, 0)
Check("foreign key late keeps", Pairs(ses.OnOtherKey(false, 1500)), "")
Check("release ends hold", Pairs(ses.OnModsChanged(0, 1600)), "PushToTalk:up")

ses := ModSession(entries)
ses.OnModsChanged(C, 0)
Check("foreign before match", Pairs(ses.OnOtherKey(false, 10)), "")
Check("blocks later match", Pairs(ses.OnModsChanged(C | W, 20)), "")

ses := ModSession(entries)
Check("toggle fires once", Pairs(ses.OnModsChanged(C | SH, 0)), "Cancel:down")
Check("toggle not again", Pairs(ses.OnModsChanged(C | SH, 10)), "")
ses.OnModsChanged(C, 20)
Check("toggle not again same session", Pairs(ses.OnModsChanged(C | SH, 30)), "")
ses.OnModsChanged(0, 40)
Check("toggle next session", Pairs(ses.OnModsChanged(C | SH, 50)), "Cancel:down")

; --- ComboRecorder ---
Record(events) {
    rec := ComboRecorder()
    for ev in StrSplit(events, " ") {
        name := SubStr(ev, 2)
        result := SubStr(ev, 1, 1) = "+" ? rec.KeyDown(name) : rec.KeyUp(name)
        if result != ""
            return result
    }
    return "<none>"
}
Check("rec main key", Record("+LControl +LShift +F13"), "Ctrl+Shift+F13")
Check("rec right mods", Record("+RControl +RAlt +a"), "Ctrl+Alt+A")
Check("rec escape alone", Record("+Escape"), "Escape")
Check("rec capslock", Record("+CapsLock"), "CapsLock")
Check("rec modifier only", Record("+LControl +LWin -LWin -LControl"), "Ctrl+Win")
Check("rec peak mods", Record("+LControl +LWin +LAlt -LAlt -LWin -LControl"), "Ctrl+Alt+Win")
Check("rec partial release", Record("+LControl +LWin -LWin"), "<none>")
Check("rec stray up ignored", Record("-LShift +LControl +F1"), "Ctrl+F1")
Check("rec parses back", ParseText(Record("+LShift +LControl +F24")), "Ctrl+Shift+F24")

; --- Autostart (temporary folder, never the real Startup folder) ---
startDir := A_Temp "\onairkeyboard-autostart-" A_TickCount
DirCreate(startDir)
Autostart.Sync(true, startDir, A_AhkPath)
Check("autostart creates link", FileExist(Autostart.LinkPath(startDir)) != "", true)
FileGetShortcut(Autostart.LinkPath(startDir), &target)
Check("autostart target", target, A_AhkPath)
Autostart.Sync(false, startDir, A_AhkPath)
Check("autostart removes link", FileExist(Autostart.LinkPath(startDir)) = "", true)
Autostart.Sync(false, startDir, A_AhkPath)
Check("autostart remove twice ok", true, true)
DirDelete(startDir, true)

Finish()
