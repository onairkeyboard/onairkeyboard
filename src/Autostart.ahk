; "Start with Windows": a shortcut in the user's Startup folder.
; Managed only by the compiled EXE, so running the script during development never
; touches the real Startup folder.
class Autostart {
    static LinkPath(dir := A_Startup) => dir "\OnAir keyboard.lnk"

    static Sync(enabled, dir := A_Startup, target := A_ScriptFullPath) {
        link := Autostart.LinkPath(dir)
        if enabled {
            SplitPath(target, , &workDir)
            FileCreateShortcut(target, link, workDir, , "OnAir keyboard", target)
        } else if FileExist(link) {
            FileDelete(link)
        }
    }
}
