; Self-install: the EXE offers to copy itself to %LOCALAPPDATA%\Programs\OnAirKeyboard (no
; administrator rights needed) and to add a Start menu shortcut, so it no longer runs from
; Downloads, where a cleanup would silently break "Start with Windows". It asks first: a program
; that quietly copies itself and starts with Windows looks like malware, to people and to
; antivirus programs alike. "No" runs it from where it is and is remembered (Portable=1).
class Installer {
    static ExeName := "OnAirKeyboard.exe"
    static DefaultDir() => EnvGet("LOCALAPPDATA") "\Programs\OnAirKeyboard"

    ; What to do when the EXE starts (pure logic, unit-tested):
    ;   ""  nothing (this is the installed copy, or the user chose to run it from where it is)
    ;   "install", "update"  ask, then copy this EXE over
    ;   "run-installed"  an equal or newer copy is installed: start that one instead
    ; installedVersion: "" when nothing is installed; identical: the installed file is this file
    static Decide(isInstalledCopy, installedVersion, version, identical, portable) {
        if isInstalledCopy
            return ""
        if installedVersion = ""
            return portable ? "" : "install"
        cmp := VerCompare(version, installedVersion)
        if cmp > 0 || (cmp = 0 && !identical)
            return "update"
        return "run-installed"
    }

    ; Called before the settings file is created, so the installed copy still sees a first run.
    ; Returns "exit" (the installed copy was started), "portable" (remember "run from here")
    ; or "" (carry on). version: of this EXE; installDir / answer are set by tests ("yes", "no").
    static Check(version, configPath, installDir, answer, relaunchArgs) {
        target := installDir "\" Installer.ExeName
        installed := FileExist(target) ? Installer.ShortVersion(FileGetVersion(target)) : ""
        portable := Config.PeekBool(configPath, "General", "Portable", false)
        action := Installer.Decide(Installer._SamePath(A_ScriptFullPath, target), installed, version
            , installed != "" && Installer._SameFile(A_ScriptFullPath, target), portable)
        if action = ""
            return ""
        if action = "install" || action = "update" {
            Lang.Set(Config.ResolveLanguage(Config.Peek(configPath, "General", "Language", "auto")))
            if answer = "" {
                text := action = "install" ? T("install.ask", installDir) : T("install.update_ask", installed, version, installDir)
                answer := MsgBox(text, "OnAir keyboard", "YesNo Iconi") = "Yes" ? "yes" : "no"
            }
            if answer != "yes"
                return action = "install" ? "portable" : ""
            ; Tests install into a temporary folder; they get a Start menu folder there too
            startMenu := installDir = Installer.DefaultDir() ? A_Programs : installDir "\Start Menu"
            if !Installer._Copy(target, installDir, startMenu) {
                MsgBox(T("install.failed", installDir), "OnAir keyboard", "Icon!")
                return ""
            }
        }
        Run('"' target '"' relaunchArgs, installDir)
        return "exit"
    }

    ; "0.1.0.0" (file version) -> "0.1.0" (the app version)
    static ShortVersion(v) => RegExReplace(v, "^(\d+\.\d+\.\d+)\.0$", "$1")

    static _Copy(target, installDir, startMenuDir) {
        Installer._CloseRunning(target)
        try DirCreate(installDir)
        copied := false
        loop 10 {  ; the closed copy may hold its file for a moment
            try {
                FileCopy(A_ScriptFullPath, target, true)
                copied := true
                break
            }
            Sleep(300)
        }
        if !copied
            return false
        try {
            DirCreate(startMenuDir)
            FileCreateShortcut(target, startMenuDir "\OnAir keyboard.lnk", installDir, , "OnAir keyboard", target)
        }
        return true
    }

    ; A running installed copy holds its file: ask it to exit (it turns its LED off), then wait
    static _CloseRunning(target) {
        prev := DetectHiddenWindows(true)
        for hwnd in WinGetList("ahk_class AutoHotkey ahk_exe " Installer.ExeName) {
            try path := WinGetProcessPath(hwnd)
            catch
                continue
            if !Installer._SamePath(path, target)
                continue
            pid := WinGetPID(hwnd)
            WinClose(hwnd)
            if ProcessWaitClose(pid, 3)
                ProcessClose(pid)
        }
        DetectHiddenWindows(prev)
    }

    static _SamePath(a, b) => StrReplace(a, "/", "\") = StrReplace(b, "/", "\")

    static _SameFile(a, b) {
        if FileGetSize(a) != FileGetSize(b)
            return false
        bufA := FileRead(a, "RAW"), bufB := FileRead(b, "RAW")
        return DllCall("ntdll\RtlCompareMemory", "Ptr", bufA, "Ptr", bufB, "UPtr", bufA.Size, "UPtr") = bufA.Size
    }
}
