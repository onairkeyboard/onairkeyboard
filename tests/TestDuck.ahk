#Requires AutoHotkey v2.0
; Unit tests for lowering other apps' sound (Ducker), on a mixer in memory: no real volume is
; ever touched. The time is passed to every call, so fades are checked step by step.
; Run: AutoHotkey64.exe /ErrorStdOut tests\TestDuck.ahk   (exit code = number of failures)

#Include %A_LineFile%\..\..\src\Log.ahk
#Include %A_LineFile%\..\..\src\Lang.ahk
#Include %A_LineFile%\..\..\src\MicWatch.ahk
#Include %A_LineFile%\..\..\src\AudioMixer.ahk
#Include %A_LineFile%\..\..\src\Ducker.ahk
#Include %A_LineFile%\..\TestLib.ahk

class MemMixer {
    __New() {
        this.S := Map()
        this.Next := 0
    }

    ; Returns the session key; ident: the app on its device (stays the same after a restart)
    Add(exe, volume, package := "", system := false, ident := "") {
        key := "s" (++this.Next)
        this.S[key] := {Ident: ident != "" ? ident : (system ? "system" : exe package), Pid: 1000 + this.Next
            , Exe: exe, Package: package, System: system, Volume: volume}
        return key
    }

    Sessions() {
        list := []
        for key, s in this.S
            list.Push({Key: key, Ident: s.Ident, Pid: s.Pid, Exe: s.Exe, Package: s.Package, System: s.System, Volume: s.Volume})
        return list
    }

    GetVolume(key) => this.S.Has(key) ? this.S[key].Volume : ""

    SetVolume(key, level) {
        if !this.S.Has(key)
            return false
        this.S[key].Volume := Round(level, 4)
        return true
    }

    Vol(key) => this.S[key].Volume
}

Settings(enabled := true, level := 20, system := true, down := 250, up := 750, delay := 1000) {
    return {DuckEnabled: enabled, DuckLevel: level, DuckSystemSounds: system, DuckFadeDownMs: down
        , DuckFadeUpMs: up, DuckRestoreDelayMs: delay}
}

StateFile() {
    dir := A_Temp "\onairkeyboard-duck-" A_TickCount "-" Random(1000, 9999)
    DirCreate(dir)
    return dir "\ducking.ini"
}

Lang.Set("en")
excludedIds := ["Wispr Flow.exe"]
Excluded() => excludedIds

; --- Pure helpers ---
Check("target 20% of 60%", Ducker.TargetOf(0.6, 20), 0.12)
Check("target 0%", Ducker.TargetOf(0.8, 0), 0)
Check("fade half", Ducker.FadeLevel(1, 0.2, 125, 250), 0.6)
Check("fade done", Ducker.FadeLevel(1, 0.2, 400, 250), 0.2)
Check("fade no time", Ducker.FadeLevel(1, 0.2, 0, 0), 0.2)
ids := Map(), ids.CaseSense := "Off", ids["wispr flow.exe"] := true, ids["OpenAI.ChatGPT-Desktop"] := true
Check("keeps excluded exe", Ducker.Keeps({System: false, Pid: 5, Exe: "Wispr Flow.exe", Package: ""}, ids, true, 1), true)
Check("keeps excluded package", Ducker.Keeps({System: false, Pid: 5, Exe: "ChatGPT.exe", Package: "OpenAI.ChatGPT-Desktop"}, ids, true, 1), true)
Check("keeps own process", Ducker.Keeps({System: false, Pid: 7, Exe: "x.exe", Package: ""}, ids, true, 7), true)
Check("lowers others", Ducker.Keeps({System: false, Pid: 5, Exe: "Spotify.exe", Package: ""}, ids, true, 1), false)
Check("lowers system sounds", Ducker.Keeps({System: true, Pid: 0, Exe: "", Package: ""}, ids, true, 1), false)
Check("keeps system sounds when off", Ducker.Keeps({System: true, Pid: 0, Exe: "", Package: ""}, ids, false, 1), true)
Check("name of system sounds", Ducker.NameOf({System: true, Exe: "", Package: ""}), "System sounds")
Check("name of a package", Ducker.NameOf({System: false, Exe: "ChatGPT.exe", Package: "OpenAI.ChatGPT-Desktop"}), "ChatGPT")
Check("name of a program", Ducker.NameOf({System: false, Exe: "Spotify.exe", Package: ""}), "Spotify")

; --- Down, held, wait, up ---
mx := MemMixer()
spotify := mx.Add("Spotify.exe", 0.6)
chrome := mx.Add("chrome.exe", 0.8)
wispr := mx.Add("Wispr Flow.exe", 1)
sys := mx.Add("", 1, , true)
state := StateFile()
d := Ducker(mx, state, Excluded)
d.Configure(Settings(), 0)
Check("idle before", d.Phase, "idle")
d.SetOnAir(true, , 1000)
Check("goes down", d.Phase, "down")
Check("nothing set at the start", mx.Vol(spotify), 0.6)
d.Refresh(1050)  ; the microphone changes as it goes on air: no jump to the target
Check("refresh while going down sets nothing", mx.Vol(spotify), 0.6)
d.Tick(1125)
Check("half way down", mx.Vol(spotify), 0.36)
d.Tick(1250)
Check("held", d.Phase, "held")
Check("spotify lowered", mx.Vol(spotify), 0.12)
Check("chrome lowered", mx.Vol(chrome), 0.16)
Check("system sounds lowered", mx.Vol(sys), 0.2)
Check("wispr keeps its sound", mx.Vol(wispr), 1)
Check("active", d.Active, true)
Check("names", Ducker._Join(d.Names()), "Spotify, Google Chrome, System sounds")
Check("state file written", FileExist(state) != "", true)
Check("state file lists three", StrSplit(IniRead(state), "`n").Length, 3)
d.SetOnAir(false, , 2000)
Check("waits", d.Phase, "wait")
d.Tick(2500)
Check("still lowered while waiting", mx.Vol(spotify), 0.12)
d.Tick(3000)
Check("comes up after the delay", d.Phase, "up")
d.Tick(3375)
Check("half way up", mx.Vol(spotify), 0.36)
d.Tick(3750)
Check("spotify back", mx.Vol(spotify), 0.6)
Check("chrome back", mx.Vol(chrome), 0.8)
Check("system sounds back", mx.Vol(sys), 1)
Check("idle after", d.Phase, "idle")
Check("state file removed", FileExist(state), "")

; --- On air again while waiting: stays lowered, nothing moves ---
d.SetOnAir(true, , 10000)
d.Tick(10250)
d.SetOnAir(false, , 11000)
d.Tick(11500)
d.SetOnAir(true, , 11600)
d.Tick(11700)
Check("back on air while waiting", mx.Vol(spotify), 0.12)

; --- On air again while coming up: down from where it is ---
d.SetOnAir(false, , 12000)
d.Tick(13000)
d.Tick(13375)
Check("half way up again", mx.Vol(spotify), 0.36)
d.SetOnAir(true, , 13375)
d.Tick(13500)
Check("going down from the middle", mx.Vol(spotify), 0.24)
d.Tick(13625)
Check("down again", mx.Vol(spotify), 0.12)
Check("original kept", d.Managed[spotify].Original, 0.6)

; --- New session while held: lowered straight away; a volume the user changes stays ---
vlc := mx.Add("vlc.exe", 1)
d.Tick(14200)
Check("new session lowered", mx.Vol(vlc), 0.2)
mx.SetVolume(chrome, 0.5)
d.SetOnAir(false, , 15000)
d.Tick(16000)
d.Tick(16750)
Check("user's volume left as is", mx.Vol(chrome), 0.5)
Check("others restored", mx.Vol(spotify) = 0.6 && mx.Vol(vlc) = 1, true)

; --- An app starts using the microphone while held: it gets its sound back at once ---
d.SetOnAir(true, , 20000)
d.Tick(20250)
excludedIds.Push("Spotify.exe")
d.Refresh(20300)
Check("microphone app restored", mx.Vol(spotify), 0.6)
Check("others still lowered", mx.Vol(vlc), 0.2)
excludedIds.Pop()
d.Tick(20800)
Check("lowered again once it stops", mx.Vol(spotify), 0.12)

; --- Pause: back at once, no delay, no fade ---
d.SetOnAir(false, true, 21000)
Check("pause restores at once", mx.Vol(spotify) = 0.6 && mx.Vol(vlc) = 1, true)
Check("pause leaves idle", d.Phase, "idle")

; --- A new level while held applies at once; turning it off restores at once ---
d.SetOnAir(true, , 22000)
d.Tick(22250)
d.Configure(Settings(true, 50), 22300)
Check("new level applied", mx.Vol(spotify), 0.3)
d.Configure(Settings(false, 50), 22400)
Check("turned off restores", mx.Vol(spotify), 0.6)
Check("turned off is idle", d.Phase, "idle")
d.SetOnAir(true, , 22500)
Check("off: on air lowers nothing", d.Phase, "idle")
d.SetOnAir(false, , 22600)

; --- Test: lowered for 3 s, then back without the delay ---
d.Configure(Settings(), 23000)
Check("test starts", d.Test(30000), true)
Check("testing", d.Testing, true)
d.Tick(30250)
Check("test lowers", mx.Vol(spotify), 0.12)
Check("no second test", d.Test(30300), false)
d.Tick(33000)
Check("test over", d.Testing, false)
d.Tick(33375)
Check("test comes back without the delay", mx.Vol(spotify), 0.36)
d.Tick(33750)
Check("test restored", mx.Vol(spotify), 0.6)
d.SetOnAir(true, , 34000)
Check("no test while on air", d.Test(34000), false)
d.Tick(34250)
d.SetOnAir(false, true, 34300)

; --- Level 0 silences ---
d.Configure(Settings(true, 0), 35000)
d.SetOnAir(true, , 35000)
d.Tick(35250)
Check("0% silences", mx.Vol(spotify), 0)
d.SetOnAir(false, true, 35300)
Check("0% restored", mx.Vol(spotify), 0.6)

; --- System sounds off: they keep their sound ---
d.Configure(Settings(true, 20, false), 36000)
d.SetOnAir(true, , 36000)
d.Tick(36250)
Check("system sounds kept", mx.Vol(sys), 1)
d.SetOnAir(false, true, 36300)

; --- Crash: the next start restores what the file lists ---
d.Configure(Settings(), 37000)
d.SetOnAir(true, , 37000)
d.Tick(37250)
d.Stop()
Check("lowered before the crash", mx.Vol(spotify), 0.12)
d2 := Ducker(mx, state, Excluded)
d2.Recover(40000)
Check("recovered spotify", mx.Vol(spotify), 0.6)
Check("recovered system sounds", mx.Vol(sys), 1)
Check("recovery removes the file", FileExist(state), "")

; --- An app closed while lowered: its volume comes back when it does ---
d2.Configure(Settings(), 41000)
d2.SetOnAir(true, , 41000)
d2.Tick(41250)
mx.S.Delete(chrome)
d2.Tick(41800)
Check("closed app waits", d2.Pending.Count, 1)
d2.SetOnAir(false, , 42000)
d2.Tick(43000)
d2.Tick(43750)
Check("file keeps the closed app", FileExist(state) != "", true)
chrome2 := mx.Add("chrome.exe", 0.1)  ; Windows remembers the lowered volume
d2.Tick(46000)
Check("closed app restored when back", mx.Vol(chrome2), 0.5)
Check("nothing left to restore", FileExist(state), "")

; --- Recovery when the app isn't running yet, and when the user has changed its volume ---
d2.SetOnAir(true, , 50000)
d2.Tick(50250)
d2.Stop()
mx.S.Delete(spotify)
mx.SetVolume(chrome2, 0.4)  ; changed by the user before the next start
d3 := Ducker(mx, state, Excluded)
d3.Recover(60000)
Check("user's change kept at recovery", mx.Vol(chrome2), 0.4)
Check("missing app waits", d3.Pending.Count, 1)
spotify2 := mx.Add("Spotify.exe", 0.12)
d3.Tick(62500)
Check("missing app restored later", mx.Vol(spotify2), 0.6)
Check("file gone at last", FileExist(state), "")
d3.Stop()

Finish()
