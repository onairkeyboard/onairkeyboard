; Diagnostic log, written only when enabled (config: [General] Debug=1).
class Log {
    static Enabled := false
    static File := ""
    static MaxBytes := 1024 * 1024

    static Init(file, enabled) {
        Log.File := file
        Log.Enabled := enabled
    }

    static Write(msg) {
        if !Log.Enabled || Log.File = ""
            return
        line := FormatTime(, "yyyy-MM-dd HH:mm:ss") "." A_MSec "  " msg "`n"
        ; Someone reading the log (a test, an editor) may hold it for a moment: retry briefly
        ; instead of losing the line
        loop 5 {
            try {
                if FileExist(Log.File) && FileGetSize(Log.File) > Log.MaxBytes
                    FileMove(Log.File, RegExReplace(Log.File, "\.log$", ".old.log"), true)
                FileAppend(line, Log.File, "UTF-8")
                return
            }
            Sleep(10)
        }
    }
}
