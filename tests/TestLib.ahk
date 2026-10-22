; Shared helpers for the test scripts. Output goes to stdout; the exit code is the number of
; failures (100 for an unexpected runtime error, which otherwise would open a blocking dialog).

failures := 0
passed := 0

OnError(ReportError)

ReportError(e, *) {
    Out("ERROR " e.Message (e.Extra != "" ? " (" e.Extra ")" : "") " at " e.File ":" e.Line)
    ExitApp(100)
}

Check(name, actual, expected) {
    global failures, passed
    if actual == expected
        passed++
    else {
        failures++
        Out("FAIL " name ": expected [" expected "], got [" actual "]")
    }
}

Out(text) => FileAppend(text "`n", "*", "UTF-8")

Finish() {
    Out(passed " passed, " failures " failed")
    ExitApp(failures)
}
