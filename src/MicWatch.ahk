; Watches which apps use the microphone, through the registry Windows keeps for its microphone
; tray icon (CapabilityAccessManager ConsentStore). Every app has a key with LastUsedTimeStart /
; LastUsedTimeStop (FILETIME); LastUsedTimeStop = 0 means "using the microphone now".
; Store apps have one key per package, other programs one key per EXE path under NonPackaged.
;
; An app is identified by its EXE file name (every Wispr Flow version has its own key
; "...#app-1.6.1264#Wispr Flow.exe") or by its package name without the publisher suffix
; ("OpenAI.ChatGPT-Desktop_2p2nqsd0c76g0" -> "OpenAI.ChatGPT-Desktop").
; Apps open the microphone for 1-10 ms before the real session; only a state read as "in use"
; counts, so these flashes rarely light anything, and never for more than one poll.
;
; Reading all keys takes about 10 ms, too much ten times a second. Windows signals an event when
; anything under the key changes, so a poll only checks the event and reads when it fired; a full
; read every SafetyMs also notices a program that died while "using" the microphone.
class MicWatch {
    static DefaultKey := "Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"
    static HKCU := -2147483647  ; HKEY_CURRENT_USER (0x80000001), sign-extended as Windows expects

    ; Display names of known apps; "lang:" names come from the translations
    static Names := MicWatch._Caseless(Map(
        "Wispr Flow.exe", "Wispr Flow",
        "Aqua Voice.exe", "Aqua Voice",
        "Claude", "Claude",
        "claude.exe", "Claude",
        "OpenAI.ChatGPT-Desktop", "ChatGPT",
        "ChatGPT.exe", "ChatGPT",
        "chrome.exe", "Google Chrome",
        "msedge.exe", "Microsoft Edge",
        "firefox.exe", "Firefox",
        "TheBrowserCompany.Arc", "Arc",
        "Discord.exe", "Discord",
        "Zoom.exe", "Zoom",
        "slack.exe", "Slack",
        "ms-teams.exe", "Microsoft Teams",
        "MSTeams", "Microsoft Teams",
        "Teams.exe", "Microsoft Teams",
        "obs64.exe", "OBS Studio",
        "Microsoft.WindowsSoundRecorder", "lang:mic.app.recorder",
        "Microsoft.WindowsCamera", "lang:mic.app.camera",
        "windows.immersivecontrolpanel", "lang:mic.app.settings",
        "Microsoft.XboxGamingOverlay", "Xbox Game Bar",
        "Microsoft.MicrosoftOfficeHub", "Microsoft 365",
        "Microsoft.Office.OneNote", "OneNote",
        "Microsoft.WindowsFeedbackHub", "Feedback Hub",
        "voicemeeterpro.exe", "Voicemeeter"))

    ; Dictation apps and AI assistants: they light the LED unless the user unticks them.
    ; Messengers, browsers and the rest don't.
    static Dictation := ["Wispr Flow.exe", "Claude", "claude.exe", "OpenAI.ChatGPT-Desktop", "ChatGPT.exe", "Aqua Voice.exe"]

    ; keyPath: under HKEY_CURRENT_USER (tests use a fake key); apps: ids that light the LED;
    ; onChange(liveIds) runs when the set of ticked apps using the microphone changes
    __New(keyPath, apps, onChange := "") {
        this.KeyPath := keyPath
        this.OnChange := onChange
        this.Selected := MicWatch.IdSet(apps)
        this.Entries := Map()   ; id -> {Id, Start, Live}
        this.LiveIds := []      ; ticked apps using the microphone now, by id
        this._liveKey := ""
        this._timer := ObjBindMethod(this, "_Tick")
        this._hKey := 0
        this._event := 0
        this._lastRead := 0
        this.SafetyMs := 2000
        this.CheckProcess := true  ; a fake registry (tests, screenshots) has no real programs
        this.Reads := 0         ; full reads so far (diagnostics, tests)
    }

    OnAir => this.LiveIds.Length > 0

    Start(pollMs) {
        this._OpenNotify()
        this.Poll()
        SetTimer(this._timer, pollMs)
    }

    Stop() {
        SetTimer(this._timer, 0)
        if this._event
            DllCall("CloseHandle", "Ptr", this._event), this._event := 0
        if this._hKey
            DllCall("Advapi32\RegCloseKey", "Ptr", this._hKey), this._hKey := 0
    }

    ; Reads everything now (re-arming the change notification first, so a change made during
    ; the read signals again)
    Poll() {
        if this._event
            this._Arm()
        this.Entries := MicWatch.Read(this.KeyPath, this.CheckProcess)
        this.Reads++
        this._lastRead := A_TickCount
        this._Evaluate()
    }

    _Tick() {
        changed := !this._event || DllCall("WaitForSingleObject", "Ptr", this._event, "UInt", 0, "UInt") = 0
        if changed || A_TickCount - this._lastRead >= this.SafetyMs
            this.Poll()
    }

    ; Without the key (nothing used the microphone yet) every poll reads, which is cheap then
    _OpenNotify() {
        if this._event
            return
        if DllCall("Advapi32\RegOpenKeyExW", "Ptr", MicWatch.HKCU, "Str", this.KeyPath, "UInt", 0
            , "UInt", 0x0010, "Ptr*", &hKey := 0, "UInt") != 0  ; KEY_NOTIFY
            return
        this._hKey := hKey
        this._event := DllCall("CreateEventW", "Ptr", 0, "Int", 0, "Int", 0, "Ptr", 0, "Ptr")  ; auto-reset
    }

    _Arm() {
        ; subtree, REG_NOTIFY_CHANGE_NAME | REG_NOTIFY_CHANGE_LAST_SET, asynchronous
        if DllCall("Advapi32\RegNotifyChangeKeyValue", "Ptr", this._hKey, "Int", 1, "UInt", 0x5
            , "Ptr", this._event, "Int", 1, "UInt") != 0 {
            Log.Write("microphone change notification failed, reading on every poll")
            DllCall("CloseHandle", "Ptr", this._event), this._event := 0
        }
    }

    ; New ticked apps take effect at once (the window changes them)
    SetApps(apps) {
        this.Selected := MicWatch.IdSet(apps)
        this._Evaluate()
    }

    IsSelected(id) => this.Selected.Has(id)
    IsLive(id) => this.Entries.Has(id) && this.Entries[id].Live

    ; Display names of the ticked apps using the microphone now ("Wispr Flow, Claude")
    LiveNames() {
        text := ""
        for id in this.LiveIds
            text .= (text = "" ? "" : ", ") MicWatch.DisplayName(id)
        return text
    }

    ; Apps from the microphone history for the window: ticked first, then the most recently used.
    ; [{Id, Name, Live, Checked}]
    List() {
        list := []
        for id, e in this.Entries
            list.Push({Id: id, Name: MicWatch.DisplayName(id), Live: e.Live, Checked: this.Selected.Has(id), Start: e.Start})
        before(a, b) => a.Checked != b.Checked ? a.Checked : a.Start > b.Start
        ; insertion sort: the list is short
        loop list.Length - 1 {
            i := A_Index + 1, item := list[i], j := i - 1
            while j >= 1 && before(item, list[j]) {
                list[j + 1] := list[j]
                j--
            }
            list[j + 1] := item
        }
        return list
    }

    _Evaluate() {
        live := []
        for id, e in this.Entries
            if e.Live && this.Selected.Has(id)
                live.Push(id)
        key := ""
        for id in live
            key .= id "|"
        if key == this._liveKey
            return
        this._liveKey := key
        this.LiveIds := live
        if this.OnChange
            this.OnChange.Call(live)
    }

    ; Reads every app with a usage record: id -> {Id, Start, Live}. Versions of one app merge:
    ; the latest start counts, and it's live when any of them is.
    static Read(keyPath, checkProcess := true) {
        entries := MicWatch._Caseless(Map())
        add(sub, id, exe) {
            stop := MicWatch._Qword(sub, "LastUsedTimeStop")
            start := MicWatch._Qword(sub, "LastUsedTimeStart")
            if stop = "" || start = ""
                return
            ; A program that was killed may leave its key "in use" for good: it must still run
            live := stop = 0 && (exe = "" || !checkProcess || ProcessExist(exe) != 0)
            if entries.Has(id) {
                e := entries[id]
                e.Start := Max(e.Start, start)
                e.Live := e.Live || live
            } else {
                entries[id] := {Id: id, Start: start, Live: live}
            }
        }
        try {
            loop Reg, "HKCU\" keyPath, "K" {
                if A_LoopRegName != "NonPackaged"
                    add(keyPath "\" A_LoopRegName, MicWatch.AppId(A_LoopRegName), "")
            }
            loop Reg, "HKCU\" keyPath "\NonPackaged", "K" {
                id := MicWatch.AppId(A_LoopRegName)
                add(keyPath "\NonPackaged\" A_LoopRegName, id, id)
            }
        }
        return entries
    }

    ; "C:#Program Files#App#app.exe" -> "app.exe"; "Claude_pzs8sxrjxfjjc" -> "Claude"
    static AppId(keyName) {
        if InStr(keyName, "#")
            return RegExReplace(keyName, ".*#")
        return RegExReplace(keyName, "_[a-z0-9]{13}$")
    }

    static DisplayName(id) {
        if MicWatch.Names.Has(id) {
            name := MicWatch.Names[id]
            return SubStr(name, 1, 5) = "lang:" ? T(SubStr(name, 6)) : name
        }
        return RegExReplace(id, "i)\.exe$")
    }

    static IsDictation(id) {
        for known in MicWatch.Dictation
            if known = id
                return true
        return false
    }

    static DefaultApps() => MicWatch.Dictation.Clone()

    ; "a|b|c" <-> ["a", "b", "c"]; blanks and repeats are dropped
    static ParseApps(text) {
        list := [], seen := MicWatch._Caseless(Map())
        for part in StrSplit(text, "|") {
            part := Trim(part)
            if part != "" && !seen.Has(part)
                list.Push(part), seen[part] := true
        }
        return list
    }

    static JoinApps(list) {
        text := ""
        for id in list
            text .= (text = "" ? "" : "|") id
        return text
    }

    static IdSet(apps) {
        set := MicWatch._Caseless(Map())
        for id in apps
            set[id] := true
        return set
    }

    static _Qword(sub, value) {
        size := 8
        r := DllCall("Advapi32\RegGetValueW", "Ptr", MicWatch.HKCU, "Str", sub, "Str", value
            , "UInt", 0x40  ; RRF_RT_REG_QWORD
            , "Ptr", 0, "Int64*", &v := 0, "UInt*", &size, "UInt")
        return r = 0 ? v : ""
    }

    static _Caseless(m) {
        copy := Map()
        copy.CaseSense := "Off"
        for k, v in m
            copy[k] := v
        return copy
    }
}
