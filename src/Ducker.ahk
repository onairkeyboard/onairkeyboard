; Lowers other apps' sound while on air and brings it back afterwards ("wyciszanie" in the
; window, ducking here). Each app's own volume goes to Level % of what it was, with a fade:
;
;   idle --on air--> down (FadeDownMs) --> held --off air--> wait (RestoreDelayMs) --> up (FadeUpMs) --> idle
;
; Going on air again during wait or up fades back down from where the volume is. Not lowered:
; apps that use the microphone now (a voice chat), the apps Excluded() names (Wispr Flow),
; OnAir keyboard itself and, unless SystemSounds, Windows' system sounds. While held, new
; sessions (another video) are lowered too. A volume the user changed meanwhile is left as is.
;
; Before lowering anything the original volumes go to StatePath (ducking.ini), and the file is
; removed once they are back. After a crash Recover() restores what the file lists, also for an
; app that is started later (Windows remembers the lowered volume of a closed app).
;
; Every method takes the time (A_TickCount) as an argument, so tests can drive it step by step.
; The public methods run as Critical (_Atomic): a fade step interrupted halfway (between setting
; a volume and remembering it) would look like a volume the user changed.
class Ducker {
    static TickMs := 30          ; fade steps
    static RefreshMs := 500      ; looking for new sessions while held
    static PendingMs := 2000     ; looking for apps closed while lowered
    static TestMs := 3000        ; "Test": lowered this long
    static Tolerance := 0.01     ; volume difference that counts as a change
    static SilenceLevel := 0.001 ; -60 dB: where a fade from or to silence starts or ends

    ; mixer: AudioMixer or FileMixer; excluded(): ids (EXE or package names, as MicWatch names
    ; apps) not to lower; onChange(): the lowered set or the phase changed (the window shows it)
    __New(mixer, statePath := "", excluded := "", onChange := "") {
        this.Mixer := mixer
        this.StatePath := statePath
        this.Excluded := excluded
        this.OnChange := onChange
        this.Enabled := false
        this.Level := 20
        this.SystemSounds := true
        this.FadeDownMs := 250
        this.FadeUpMs := 750
        this.RestoreDelayMs := 1000
        this.Managed := Map()    ; Key -> {Key, Ident, Name, Original, Target, Last, From}
        this.Pending := Map()    ; Ident -> {Ident, Original, Target}: apps that are gone
        this.Phase := "idle"
        this.PhaseStart := 0
        this.WaitMs := 0
        this.Wanted := false     ; on air (and not paused)
        this.TestUntil := 0
        this._EndedTest := false
        this.LastRefresh := 0
        this.OwnPid := DllCall("GetCurrentProcessId", "UInt")
        this._timer := ObjBindMethod(this, "_OnTimer")
        this._timerMs := 0
    }

    ; cfg: Config (Duck* settings). Turning it off restores at once; a new level applies at once.
    Configure(cfg, now := A_TickCount) => this._Atomic(() => this._Configure(cfg, now))

    _Configure(cfg, now) {
        levelChanged := cfg.DuckLevel != this.Level || cfg.DuckSystemSounds != this.SystemSounds
        this.Level := cfg.DuckLevel
        this.SystemSounds := cfg.DuckSystemSounds
        this.FadeDownMs := cfg.DuckFadeDownMs
        this.FadeUpMs := cfg.DuckFadeUpMs
        this.RestoreDelayMs := cfg.DuckRestoreDelayMs
        if this.Enabled != cfg.DuckEnabled {
            this.Enabled := cfg.DuckEnabled
            Log.Write("ducking " (this.Enabled ? "on, level " this.Level "%" : "off"))
            if !this.Enabled
                this._RestoreNow("turned off", now)
        } else if levelChanged && this.Managed.Count {
            for key, m in this.Managed
                m.Target := Ducker.TargetOf(m.Original, this.Level)
            if this.Phase = "held"  ; while going down the fade heads for the new target
                this._Refresh(now, true)
        }
        this._Update(now)
    }

    ; immediate: restore without the delay and the fade (pause)
    SetOnAir(onAir, immediate := false, now := A_TickCount) => this._Atomic(() => this._SetOnAir(onAir, immediate, now))

    _SetOnAir(onAir, immediate, now) {
        this.Wanted := onAir ? true : false
        if !onAir && immediate && this.TestUntil = 0 {
            this._RestoreNow("paused", now)
            return
        }
        this._Update(now)
    }

    ; The window's "Test" button: lowered for TestMs, then back without the delay
    Test(now := A_TickCount) => this._Atomic(() => this._Test(now))

    _Test(now) {
        if !this.Enabled || this.Wanted || this.TestUntil
            return false
        Log.Write("ducking test")
        this.TestUntil := now + Ducker.TestMs
        this._Update(now)
        return true
    }

    Testing => this.TestUntil != 0
    ; The window shows "Teraz wyciszone" / the lowered apps while this is true
    Active => this.Phase = "down" || this.Phase = "held"

    ; Display names of the lowered apps ("Spotify, Google Chrome")
    Names() {
        names := [], seen := Map()
        seen.CaseSense := "Off"
        for key, m in this.Managed
            if !seen.Has(m.Name)
                seen[m.Name] := true, names.Push(m.Name)
        return names
    }

    ; The microphone changed: an app that now uses it gets its sound back, a new one may go down
    Refresh(now := A_TickCount) => this._Atomic(() => this._RefreshNow(now))

    _RefreshNow(now) {
        if this.Active
            this._Refresh(now, this.Phase = "held")  ; while going down the fade sets the volumes
    }

    ; Back to the original volumes at once (pause, turned off, sleep, exit)
    RestoreNow(reason, now := A_TickCount) => this._Atomic(() => this._RestoreNow(reason, now))

    _RestoreNow(reason, now) {
        this.TestUntil := 0
        if this.Managed.Count {
            restored := 0
            for key, m in this.Managed {
                switch this._StillOurs(m) {
                    case 1:
                        if this.Mixer.SetVolume(m.Key, m.Original)
                            restored++
                    case -1:  ; closed: restored when it comes back
                        this.Pending[m.Ident] := {Ident: m.Ident, Original: m.Original, Target: m.Target}
                }
            }
            Log.Write(Format("ducking: {1} restored ({2})", restored, reason))
            this.Managed := Map()
        }
        this.Phase := "idle"
        this._Save()
        this._Changed()
        this._Schedule()
    }

    ; At start: volumes a crash left lowered (StatePath) come back
    Recover(now := A_TickCount) => this._Atomic(() => this._Recover(now))

    _Recover(now) {
        if this.StatePath = "" || !FileExist(this.StatePath)
            return
        for section in StrSplit(IniRead(this.StatePath), "`n") {
            if section = ""
                continue
            ident := IniRead(this.StatePath, section, "Ident", "")
            original := IniRead(this.StatePath, section, "Original", "")
            target := IniRead(this.StatePath, section, "Target", "")
            if ident != "" && IsNumber(original) && IsNumber(target)
                this.Pending[ident] := {Ident: ident, Original: Number(original), Target: Number(target)}
        }
        Log.Write("ducking: " this.Pending.Count " volumes left lowered by the last run")
        this._CheckPending(this.Mixer.Sessions(), now)
        this._Save()
        this._Schedule()
    }

    Stop() {
        this._SetTimer(0)
    }

    ; --- Pure helpers (tests) ---

    static TargetOf(original, level) => Round(original * level / 100, 4)

    ; Fade from -> to, progress in ms of durationMs, in even steps to the ear (decibels): going
    ; down the volume drops fast at first and gently at the end. Silence counts as SilenceLevel.
    static FadeLevel(from, to, elapsed, durationMs) {
        if durationMs <= 0 || elapsed >= durationMs || from = to
            return to
        a := Max(from, Ducker.SilenceLevel), b := Max(to, Ducker.SilenceLevel)
        return Round(a * (b / a) ** (Max(0, elapsed) / durationMs), 4)
    }

    ; Whether a session must keep its sound. excluded: Map of ids (case-insensitive).
    static Keeps(session, excluded, systemSounds, ownPid) {
        if session.System
            return !systemSounds
        if session.Pid && session.Pid = ownPid
            return true
        return session.Exe != "" && excluded.Has(session.Exe) || session.Package != "" && excluded.Has(session.Package)
    }

    static NameOf(session) {
        if session.System
            return T("sound.system")
        if session.Package != ""
            return MicWatch.DisplayName(session.Package)
        return session.Exe != "" ? MicWatch.DisplayName(session.Exe) : "?"
    }

    ; --- Phases ---

    _On(now) => this.Enabled && (this.Wanted || this.TestUntil && now < this.TestUntil)

    _Update(now) {
        if this._On(now) {
            if this.Phase != "down" && this.Phase != "held" {
                this._Refresh(now, false)
                for key, m in this.Managed
                    m.From := m.Last
                this._Enter("down", now)
            }
        } else if this.Phase = "down" || this.Phase = "held" {
            this.WaitMs := this._EndedTest ? 0 : this.RestoreDelayMs  ; the test ends without the delay
            this._EndedTest := false
            this._Enter("wait", now)
        }
        this._Schedule()
    }

    _Enter(phase, now) {
        this.Phase := phase
        this.PhaseStart := now
        this._Changed()
    }

    _OnTimer() => this.Tick(A_TickCount)

    ; Runs fn as Critical and gives the caller back its own state (a start-up thread left
    ; Critical would delay every timer until it ends)
    _Atomic(fn) {
        was := A_IsCritical
        Critical
        try
            return fn()
        finally
            Critical(was ? was : "Off")
    }

    Tick(now := A_TickCount) => this._Atomic(() => this._Tick(now))

    _Tick(now) {
        if this.TestUntil && now >= this.TestUntil {
            this.TestUntil := 0
            this._EndedTest := true
            Log.Write("ducking test over")
            this._Update(now)
        }
        switch this.Phase {
            case "down":
                elapsed := now - this.PhaseStart
                for key, m in this.Managed.Clone()
                    this._Step(m, Ducker.FadeLevel(m.From, m.Target, elapsed, this.FadeDownMs))
                if elapsed >= this.FadeDownMs
                    this._Enter("held", now)
            case "held":
                if now - this.LastRefresh >= Ducker.RefreshMs
                    this._Refresh(now, true)
            case "wait":
                if now - this.PhaseStart >= this.WaitMs {
                    for key, m in this.Managed
                        m.From := m.Last
                    this._Enter("up", now)
                    this._Tick(now)
                    return
                }
            case "up":
                elapsed := now - this.PhaseStart
                for key, m in this.Managed.Clone()
                    this._Step(m, Ducker.FadeLevel(m.From, m.Original, elapsed, this.FadeUpMs))
                if elapsed >= this.FadeUpMs {
                    Log.Write("ducking: sound back")
                    this.Managed := Map()
                    this._Save()
                    this._Enter("idle", now)
                }
            default:
                if this.Pending.Count && now - this.LastRefresh >= Ducker.PendingMs {
                    this.LastRefresh := now
                    this._CheckPending(this.Mixer.Sessions(), now)
                }
        }
        this._Schedule()
    }

    ; Sets one session's volume, unless the user changed it or the app has gone
    _Step(m, level) {
        switch this._StillOurs(m) {
            case 1:
                if Abs(level - m.Last) >= 0.0001 && this.Mixer.SetVolume(m.Key, level)
                    m.Last := level
            case 0:
                Log.Write("ducking: " m.Name " volume changed by the user, left as is")
                this._Drop(m)
            default:  ; gone: restored when it comes back
                this.Pending[m.Ident] := {Ident: m.Ident, Original: m.Original, Target: m.Target}
                Log.Write("ducking: " m.Name " closed while lowered")
                this._Drop(m)
        }
    }

    ; 1: the volume is what we set, 0: the user changed it, -1: the session is gone
    _StillOurs(m) {
        current := this.Mixer.GetVolume(m.Key)
        if current = ""
            return -1
        return Abs(current - m.Last) <= Ducker.Tolerance ? 1 : 0
    }

    _Drop(m) {
        this.Managed.Delete(m.Key)
        this._Save()
        this._Changed()
    }

    ; Lowers new sessions; gives the sound back to sessions that must keep it now.
    ; set: true while held (straight to the target), false before a fade (the fade sets it)
    _Refresh(now, set) {
        this.LastRefresh := now
        sessions := this.Mixer.Sessions()
        excluded := this._ExcludedIds()
        live := Map()
        added := [], kept := []
        for s in sessions {
            live[s.Key] := true
            keeps := Ducker.Keeps(s, excluded, this.SystemSounds, this.OwnPid)
            if this.Managed.Has(s.Key) {
                m := this.Managed[s.Key]
                if keeps {
                    if this._StillOurs(m) = 1
                        this.Mixer.SetVolume(m.Key, m.Original)
                    kept.Push(m.Name)
                    this.Managed.Delete(s.Key)
                } else if set && Abs(m.Last - m.Target) > 0.0001 && this._StillOurs(m) = 1 {
                    this.Mixer.SetVolume(m.Key, m.Target)
                    m.Last := m.Target
                }
                continue
            }
            if keeps
                continue
            original := s.Volume
            if this.Pending.Has(s.Ident) {  ; came back while still lowered by us
                p := this.Pending[s.Ident]
                if Abs(s.Volume - p.Target) <= Ducker.Tolerance
                    original := p.Original
                this.Pending.Delete(s.Ident)
            }
            m := {Key: s.Key, Ident: s.Ident, Name: Ducker.NameOf(s), Original: original
                , Target: Ducker.TargetOf(original, this.Level), Last: s.Volume, From: s.Volume}
            this.Managed[s.Key] := m
            if set && this.Mixer.SetVolume(m.Key, m.Target)
                m.Last := m.Target
            added.Push(m.Name)
        }
        for key, m in this.Managed.Clone()
            if !live.Has(key)
                this._Step(m, m.Last)  ; logs and keeps it for later
        if added.Length || kept.Length {
            if added.Length
                Log.Write(Format("ducking: {1} lowered to {2}% ({3})", added.Length, this.Level, Ducker._Join(added)))
            if kept.Length
                Log.Write("ducking: sound back for " Ducker._Join(kept) " (uses the microphone)")
            this._Save()
            this._Changed()
        }
    }

    ; Apps closed while lowered, or left lowered by a crash: their volume comes back once they
    ; appear with the lowered volume (a changed volume means the user set it)
    _CheckPending(sessions, now) {
        if !this.Pending.Count
            return
        restored := 0
        for s in sessions {
            if !this.Pending.Has(s.Ident) || this.Managed.Has(s.Key)
                continue
            p := this.Pending[s.Ident]
            if Abs(s.Volume - p.Target) <= Ducker.Tolerance && this.Mixer.SetVolume(s.Key, p.Original)
                restored++
            this.Pending.Delete(s.Ident)
        }
        if restored
            Log.Write("ducking: " restored " volumes restored after the app came back")
        this._Save()
    }

    _ExcludedIds() {
        ids := Map()
        ids.CaseSense := "Off"
        if this.Excluded
            for id in this.Excluded.Call()
                ids[id] := true
        return ids
    }

    ; The state file lists what must come back: lowered sessions and pending apps
    _Save() {
        if this.StatePath = ""
            return
        entries := Map()
        for key, m in this.Managed
            entries[m.Ident] := m
        for ident, p in this.Pending
            if !entries.Has(ident)
                entries[ident] := p
        try FileDelete(this.StatePath)
        if !entries.Count
            return
        text := "; OnAir keyboard: volumes to restore (removed once they are back)`n"
        for ident, e in entries
            text .= Format("[{1}]`nIdent={2}`nOriginal={3:.4f}`nTarget={4:.4f}`n", A_Index, ident, e.Original, e.Target)
        try FileAppend(text, this.StatePath, "UTF-16")
    }

    _Changed() {
        if this.OnChange
            this.OnChange.Call()
    }

    ; The timer runs only when there is something to do
    _Schedule() {
        if this.Phase = "down" || this.Phase = "up" || this.Phase = "wait" || this.TestUntil
            this._SetTimer(Ducker.TickMs)
        else if this.Phase = "held"
            this._SetTimer(Ducker.RefreshMs)
        else if this.Pending.Count
            this._SetTimer(Ducker.PendingMs)
        else
            this._SetTimer(0)
    }

    _SetTimer(ms) {
        if ms = this._timerMs
            return
        this._timerMs := ms
        SetTimer(this._timer, ms)
    }

    static _Join(list) {
        text := ""
        for item in list
            text .= (A_Index > 1 ? ", " : "") item
        return text
    }
}
