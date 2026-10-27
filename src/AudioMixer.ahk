; The audio sessions of other apps and their volume: the same per-app sliders as Windows' volume
; mixer (Core Audio: IAudioSessionManager2 -> ISimpleAudioVolume), on every active output
; device. A session is listed as
;   {Key, Ident, Pid, Exe, Package, System, Volume}
; Key: this session now (its instance identifier); Ident: the app on this device, the same after
; the app or Windows restarts (session identifier), used to restore volumes after a crash;
; Exe: process file name; Package: Store package name without the publisher suffix (as MicWatch
; names apps), "" for other programs; System: Windows' system sounds; Volume: 0.0-1.0.
class AudioMixer {
    static CLSID_Enumerator := "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
    static IID_Enumerator := "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
    static IID_SessionManager2 := "{77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F}"
    static IID_SessionControl2 := "{bfb7ff88-7239-4fc9-8fa2-07c950be9c6d}"
    static IID_SimpleVolume := "{87CE5498-68D6-44E5-9215-6DA47EF883D8}"

    __New() {
        this.Enum := ComObject(AudioMixer.CLSID_Enumerator, AudioMixer.IID_Enumerator)
        this.Vols := Map()     ; Key -> ISimpleAudioVolume of the sessions listed last
        this.Controls := Map() ; Key -> IAudioSessionControl (its state tells whether it ended)
        this.Procs := Map()    ; pid -> {Exe, Package}
        this._iid := Buffer(16)
        DllCall("Ole32\CLSIDFromString", "Str", AudioMixer.IID_SessionManager2, "Ptr", this._iid)
    }

    ; Every session that hasn't ended, active or not (a paused player keeps its session)
    Sessions() {
        list := [], vols := Map(), controls := Map(), seen := Map()
        ComCall(3, this.Enum, "Int", 0, "UInt", 1, "Ptr*", &pDevices := 0)  ; eRender, DEVICE_STATE_ACTIVE
        devices := ComValue(13, pDevices)
        ComCall(3, devices, "UInt*", &deviceCount := 0)
        loop deviceCount {
            try {
                ComCall(4, devices, "UInt", A_Index - 1, "Ptr*", &pDevice := 0)
                device := ComValue(13, pDevice)
                ComCall(3, device, "Ptr", this._iid, "UInt", 23, "Ptr", 0, "Ptr*", &pManager := 0)  ; Activate, CLSCTX_ALL
                manager := ComValue(13, pManager)
                ComCall(5, manager, "Ptr*", &pSessions := 0)  ; GetSessionEnumerator
                sessions := ComValue(13, pSessions)
                ComCall(3, sessions, "Int*", &count := 0)
            } catch {
                continue  ; a device that just went away
            }
            loop count {
                try {
                    ComCall(4, sessions, "Int", A_Index - 1, "Ptr*", &pControl := 0)
                    control := ComValue(13, pControl)
                    ComCall(3, control, "Int*", &state := 0)
                    if state = 2  ; AudioSessionStateExpired
                        continue
                    control2 := ComObjQuery(control, AudioMixer.IID_SessionControl2)
                    vol := ComObjQuery(control, AudioMixer.IID_SimpleVolume)
                    key := AudioMixer._String(control2, 13)    ; GetSessionInstanceIdentifier
                    ident := AudioMixer._String(control2, 12)  ; GetSessionIdentifier
                    ComCall(14, control2, "UInt*", &pid := 0)
                    system := ComCall(15, control2) = 0        ; IsSystemSoundsSession: S_OK
                    ComCall(4, vol, "Float*", &level := 0)
                } catch {
                    continue
                }
                proc := this._Process(pid)
                seen[pid] := true
                vols[key] := vol
                controls[key] := control
                list.Push({Key: key, Ident: ident, Pid: pid, Exe: proc.Exe, Package: proc.Package
                    , System: system, Volume: Round(level, 4)})
            }
        }
        this.Vols := vols
        this.Controls := controls
        for pid in this.Procs.Clone()
            if !seen.Has(pid)
                this.Procs.Delete(pid)
        return list
    }

    ; "" when the session has ended since it was listed
    GetVolume(key) {
        if !this.Vols.Has(key)
            return ""
        try {
            ComCall(3, this.Controls[key], "Int*", &state := 0)
            if state = 2
                return ""
            ComCall(4, this.Vols[key], "Float*", &level := 0)
            return Round(level, 4)
        }
        return ""
    }

    SetVolume(key, level) {
        if !this.Vols.Has(key)
            return false
        try {
            ComCall(3, this.Vols[key], "Float", Max(0, Min(1, level)), "Ptr", 0)  ; SetMasterVolume
            return true
        }
        return false
    }

    _Process(pid) {
        if this.Procs.Has(pid)
            return this.Procs[pid]
        exe := "", package := ""
        if pid {
            try exe := ProcessGetName(pid)
            package := AudioMixer.PackageOf(pid)
        }
        return this.Procs[pid] := {Exe: exe, Package: package}
    }

    ; "OpenAI.ChatGPT-Desktop" for a process of that Store package, "" for other programs
    static PackageOf(pid) {
        h := DllCall("OpenProcess", "UInt", 0x1000, "Int", 0, "UInt", pid, "Ptr")  ; QUERY_LIMITED_INFORMATION
        if !h
            return ""
        len := 256, buf := Buffer(len * 2)
        r := DllCall("GetPackageFamilyName", "Ptr", h, "UInt*", &len, "Ptr", buf, "UInt")
        DllCall("CloseHandle", "Ptr", h)
        return r = 0 ? MicWatch.AppId(StrGet(buf)) : ""
    }

    ; A string returned by a COM method (LPWSTR*), freed afterwards
    static _String(obj, index) {
        ComCall(index, obj, "Ptr*", &p := 0)
        text := StrGet(p)
        DllCall("Ole32\CoTaskMemFree", "Ptr", p)
        return text
    }
}

; A fake mixer for tests (--audio-file <ini>): every section is a session, with the keys Ident,
; Pid, Exe, Package, System and Volume. The program changes Volume there, the test reads it, so
; tests never touch the sound of the user's apps. A write replaces the whole file at once (a
; temporary file moved over it), so the test never reads half a file; the test may hold the file
; for a moment, so it is retried, and it never throws (an error dialog in a fade step would stop
; the program).
class FileMixer {
    __New(path) {
        this.Path := path
    }

    Sessions() {
        list := []
        sections := ""
        if FileExist(this.Path)
            try sections := IniRead(this.Path)
        for key in StrSplit(sections, "`n") {
            if key = ""
                continue
            list.Push({Key: key, Ident: this._Get(key, "Ident", key), Pid: Integer(this._Get(key, "Pid", 0))
                , Exe: this._Get(key, "Exe", ""), Package: this._Get(key, "Package", "")
                , System: this._Get(key, "System", 0) = 1, Volume: Number(this._Get(key, "Volume", 1))})
        }
        return list
    }

    GetVolume(key) {
        value := this._Get(key, "Volume", "")
        return value = "" ? "" : Number(value)
    }

    SetVolume(key, level) {
        if this._Get(key, "Volume", "") = ""
            return false
        tmp := this.Path ".tmp"
        loop 10 {
            try {
                FileCopy(this.Path, tmp, true)
                IniWrite(Format("{:.4f}", Max(0, Min(1, level))), tmp, key, "Volume")
                FileMove(tmp, this.Path, true)
                return true
            }
            Sleep(10)
        }
        try FileDelete(tmp)
        return false
    }

    _Get(key, name, default) {
        if !FileExist(this.Path)
            return default
        try return Trim(IniRead(this.Path, key, name, default))
        return default
    }
}
