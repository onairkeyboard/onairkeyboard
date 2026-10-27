; Helpers for driving the WebView2 window of a test instance (tests, screenshots).
; The instance must run on a custom settings file: only those accept WM_COPYDATA commands.

; WM_COPYDATA command (App.COPY_*) with a text, sent to the instance with this process id
CopyCommand(pid, cmd, text) {
    DetectHiddenWindows(true)
    size := (StrLen(text) + 1) * 2
    cds := Buffer(3 * A_PtrSize, 0)
    NumPut("UPtr", cmd, cds, 0)
    NumPut("UInt", size, cds, A_PtrSize)
    NumPut("Ptr", StrPtr(text), cds, 2 * A_PtrSize)
    return SendMessage(0x004A, 0, cds, , "ahk_class AutoHotkey ahk_pid " pid, , , , 5000)
}

; Runs JavaScript in the window and returns its result as JSON text ("" on timeout).
; The instance logs "page eval: <result>"; logFile is its diagnostic log.
PageEval(pid, logFile, script, timeoutMs := 3000) {
    before := 0
    try before := StrLen(FileRead(logFile, "UTF-8"))
    CopyCommand(pid, 1, script)
    start := A_TickCount
    while A_TickCount - start < timeoutMs {
        Sleep(50)
        try text := SubStr(FileRead(logFile, "UTF-8"), before + 1)
        catch
            continue
        if RegExMatch(text, "page eval: (.*)\R", &m)
            return m[1]
    }
    return ""
}
