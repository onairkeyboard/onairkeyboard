; The OnAir keyboard window: an HTML page (ui\) shown in WebView2.
;
; WebView2 is created when the window opens and closed with it: about 126 MB while the window is
; open, nothing afterwards, so the tray program stays as light as in v0.1. It always gets its own
; data folder (the library would otherwise use Edge's profile). The page only shows local files,
; mapped to https://app.onairkeyboard.local; links to the internet open in the default browser.
;
; Page <-> program: JSON messages. The program sends "init" (texts, settings, state, apps) when
; the page is ready, then "state", "apps", "settings" and "assign" updates; the page sends
; commands ({cmd: ...}), handled by App.OnWindowCommand.
; Remember: AutoHotkey names are case-insensitive, so locals must not shadow classes.
class AppWindow {
    static Instance := ""
    static Host := "app.onairkeyboard.local"
    static RuntimeUrl := "https://go.microsoft.com/fwlink/p/?LinkId=2124703"  ; WebView2 Runtime installer
    static Views := ["main", "advanced", "howto", "bug", "support", "about"]
    ; Client sizes (DPI-scaled): the simple view is narrow, the advanced one has a sidebar
    static Sizes := Map("main", [660, 640], "wide", [960, 720])
    static ForcedScheme := 0   ; 0 follows Windows, 1 light, 2 dark (screenshots)

    ; view: "" opens the main view (or keeps the current one when the window is open)
    static Open(owner, view := "") {
        if AppWindow.Instance {
            AppWindow.Instance.Show(view)
            return AppWindow.Instance
        }
        if !AppWindow.HasRuntime(owner) {
            RuntimeMissingWindow.Show()
            return ""
        }
        ; Building the window takes longer than the 15 ms after which another thread may
        ; interrupt; without Critical a queued command would open a second window.
        Critical
        win := AppWindow.Instance := AppWindow(owner, view)
        Critical "Off"
        win._CreateWebView()
        return win
    }

    ; The WebView2 Runtime comes with Windows 11 and almost every Windows 10; the loader says
    ; whether it's there
    static HasRuntime(owner) {
        if owner.NoWebView2  ; test option: behave as if the runtime were missing
            return false
        try {
            hr := DllCall(AppWindow._Files().Loader "\GetAvailableCoreWebView2BrowserVersionString"
                , "Ptr", 0, "Ptr*", &version := 0, "UInt")
            if hr = 0 && version {
                Log.Write("WebView2 Runtime " StrGet(version))
                DllCall("ole32\CoTaskMemFree", "Ptr", version)
                return true
            }
            Log.Write(Format("WebView2 Runtime missing (0x{:08X})", hr))
        } catch as e {
            Log.Write("WebView2 Runtime check failed: " e.Message)
        }
        return false
    }

    static DataDir() => EnvGet("LOCALAPPDATA") "\OnAirKeyboard"

    static IsDark() {
        if AppWindow.ForcedScheme
            return AppWindow.ForcedScheme = 2
        return RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 1) = 0
    }

    __New(owner, view) {
        this.Owner := owner
        this.View := view != "" ? view : "main"
        this.PageReady := false
        this.Ctrl := ""
        this.Wv := ""
        this.Regs := []
        this.Closed := false
        this.LastApps := ""
        this._appsTimer := ObjBindMethod(this, "SendApps")
        this.Opened := A_TickCount

        win := Gui("-MaximizeBox", T("ui.window_title", App.Version))
        win.OnEvent("Close", (*) => this.Close())
        win.OnEvent("Size", (*) => this.Ctrl && this.Ctrl.Fill())
        this.Win := win
        AppWindow._SetIcon(win.Hwnd)
        this.ApplyTheme()
        size := this._Size(this.View)
        win.Show(Format("w{} h{}", size[1], size[2]))
        Log.Write("window opened (" this.View ")")
    }

    Show(view := "") {
        if view != "" && view != this.View {
            this.View := view
            this._Resize()
            if this.PageReady
                this.Send(Map("type", "view", "view", view))
        }
        this.Win.Show()
    }

    Close() {
        if this.Closed
            return
        this.Closed := true
        SetTimer(this._appsTimer, 0)
        this.Owner.OnWindowClosing()
        this.Regs := []
        if this.Ctrl
            try this.Ctrl.Close()
        this.Wv := ""
        this.Ctrl := ""
        this.Win.Destroy()
        if AppWindow.Instance = this
            AppWindow.Instance := ""
        Log.Write("window closed")
    }

    ; --- WebView2 ---

    _CreateWebView() {
        try {
            files := AppWindow._Files()
            this.UiDir := files.Ui
            WebView2.CreateControllerAsync(this.Win.Hwnd, 0, AppWindow.DataDir() "\WebView2", "", files.Loader)
                .then(ObjBindMethod(this, "_OnController"), ObjBindMethod(this, "_OnFailed"))
        } catch as e {
            this._OnFailed(e)
        }
    }

    _OnController(ctrl) {
        if this.Closed {  ; the window was closed while WebView2 was starting
            try ctrl.Close()
            return
        }
        this.Ctrl := ctrl
        wv := ctrl.CoreWebView2
        s := wv.Settings
        s.AreDevToolsEnabled := false
        s.AreDefaultContextMenusEnabled := false
        s.IsStatusBarEnabled := false
        s.IsZoomControlEnabled := false
        try s.AreBrowserAcceleratorKeysEnabled := false  ; no Ctrl+F, F5, Ctrl+P...
        try s.IsPinchZoomEnabled := false
        this.ApplyTheme()
        wv.SetVirtualHostNameToFolderMapping(AppWindow.Host, this.UiDir, 0)  ; DENY: no other origin
        this.Regs.Push(wv.WebMessageReceived(ObjBindMethod(this, "_OnMessage")))
        this.Regs.Push(wv.NavigationStarting(ObjBindMethod(this, "_OnNavigating")))
        this.Regs.Push(wv.NewWindowRequested(ObjBindMethod(this, "_OnNewWindow")))
        this.Wv := wv
        ctrl.Fill()
        wv.Navigate("https://" AppWindow.Host "/index.html")
        Log.Write("WebView2 ready after " A_TickCount - this.Opened " ms")
    }

    ; No WebView2 Runtime (rare, older Windows 10): OnAir keyboard keeps working from the tray,
    ; and a small native window explains how to get the runtime
    _OnFailed(e) {
        Log.Write("WebView2 failed: " (e is Error ? e.Message : String(e)))
        if this.Closed
            return
        this.Closed := true
        this.Win.Destroy()
        AppWindow.Instance := ""
        this.Owner.OnWindowClosing()
        RuntimeMissingWindow.Show()
    }

    ; Only the page itself may load; links elsewhere open in the browser
    _OnNavigating(sender, args) {
        uri := args.Uri
        if InStr(uri, "https://" AppWindow.Host "/") = 1
            return
        args.Cancel := true
        AppWindow.OpenExternal(uri)
    }

    _OnNewWindow(sender, args) {
        args.Handled := true
        AppWindow.OpenExternal(args.Uri)
    }

    static OpenExternal(uri) {
        if RegExMatch(uri, "i)^(https|mailto):") {
            Log.Write("open " uri)
            Run(uri)
        } else {
            Log.Write("blocked " uri)
        }
    }

    _OnMessage(sender, args) {
        try {
            if InStr(args.Source, "https://" AppWindow.Host "/") != 1
                return
            msg := Json.Parse(args.WebMessageAsJson)
            if !(msg is Map) || !msg.Has("cmd")
                return
            if msg["cmd"] = "ready" {
                this.PageReady := true
                this.SendInit()
                SetTimer(this._appsTimer, 500)
                Log.Write("window ready after " A_TickCount - this.Opened " ms")
                return
            }
            ; Commands may open dialogs or record keys: run them outside the WebView2 callback
            SetTimer(ObjBindMethod(this.Owner, "OnWindowCommand", msg), -1)
        } catch as e {
            Log.Write("ERROR window message: " e.Message)
        }
    }

    Send(obj) {
        if this.Wv && this.PageReady
            this.Wv.PostWebMessageAsJson(Json.Stringify(obj))
    }

    SendInit() {
        owner := this.Owner
        this.LastApps := ""
        this.Send(Map("type", "init", "view", this.View, "texts", AppWindow.Texts(), "lang", Lang.Current
            , "version", App.Version, "settings", owner.SettingsPayload(), "state", owner.StatePayload()
            , "apps", owner.AppsPayload(), "links", owner.LinksPayload(), "bug", owner.BugPayload()))
    }

    SendState() => this.Send(Map("type", "state", "state", this.Owner.StatePayload()))
    SendSettings() => this.Send(Map("type", "settings", "settings", this.Owner.SettingsPayload()))

    ; The app list changes with the microphone history; sent only when it changed
    SendApps(force := false) {
        apps := Json.Stringify(this.Owner.AppsPayload())
        if apps == this.LastApps && force != true
            return
        this.LastApps := apps
        if this.Wv && this.PageReady
            this.Wv.PostWebMessageAsJson('{"type":"apps","apps":' apps '}')
    }

    ; Texts for the page in the current language: every key, where "ui.<key>" (written for the
    ; window) replaces "<key>" (shared with the tray and messages)
    static Texts() {
        texts := Map()
        for key in Lang.Strings["en"]
            if SubStr(key, 1, 3) != "ui."
                texts[key] := T(key)
        for key in Lang.Strings["en"]
            if SubStr(key, 1, 3) = "ui."
                texts[SubStr(key, 4)] := T(key)
        return texts
    }

    ; The page asks for the wide window (sidebar) or the narrow one
    SetLayout(layout) {
        if !AppWindow.Sizes.Has(layout) || this.HasOwnProp("Layout") && this.Layout = layout
            return
        this.Layout := layout
        this._Resize()
    }

    _Size(view) => AppWindow.Sizes[this.HasOwnProp("Layout") ? this.Layout : (view = "main" ? "main" : "wide")]

    ; Keeps the window centred on where it was
    _Resize() {
        size := this._Size(this.View)
        scale := A_ScreenDPI / 96
        this.Win.GetPos(&x, &y, &w, &h)
        this.Win.GetClientPos(, , &cw, &ch)
        nw := Round(size[1] * scale) + (w - cw), nh := Round(size[2] * scale) + (h - ch)
        if nw = w && nh = h
            return
        this.Win.Move(x + (w - nw) // 2, y + (h - nh) // 2, nw, nh)
    }

    ; Light or "Grafit": title bar (DWM), the window behind the page, and the page's colour scheme
    ApplyTheme() {
        dark := AppWindow.IsDark()
        this.Win.BackColor := dark ? "2A2A2A" : "FFFFFF"
        ; DWMWA_USE_IMMERSIVE_DARK_MODE: 20 since Windows 10 20H1, 19 before
        if DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Win.Hwnd, "Int", 20, "Int*", dark, "Int", 4) != 0
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Win.Hwnd, "Int", 19, "Int*", dark, "Int", 4)
        DllCall("SetWindowPos", "Ptr", this.Win.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x37)  ; frame changed
        if this.Ctrl {
            try this.Ctrl.DefaultBackgroundColor := dark ? 0x2A2A2AFF : 0xFFFFFFFF  ; bytes A, R, G, B
            try this.Ctrl.CoreWebView2.Profile.PreferredColorScheme := AppWindow.ForcedScheme
        }
    }

    ; --- Test commands (only instances with a custom settings file accept them) ---

    ; Runs JavaScript in the page and logs the result as "page eval: <JSON>"
    Eval(script) {
        if !this.Wv || !this.PageReady {
            Log.Write("page eval: not ready")
            return
        }
        this.Wv.ExecuteScriptAsync(script).then((r) => Log.Write("page eval: " r), (e) => Log.Write("page eval failed"))
    }

    ; Saves a PNG of the page (without the title bar)
    Capture(path) {
        if !this.Wv
            return
        stream := WebView2.CreateFileStream(path, "w")
        this.Wv.CapturePreviewAsync(0, stream).then((*) => (stream := 0, Log.Write("captured " path)))
    }

    ; --- Files ---

    ; The script uses ui\ and the loader DLL from the repository. The EXE carries them inside and
    ; unpacks them to %LOCALAPPDATA%\OnAirKeyboard when this build hasn't done it yet.
    static _Files() {
        if !A_IsCompiled
            return {Ui: TrayUI._FullPath(A_LineFile "\..\..\ui"), Loader: TrayUI._FullPath(A_LineFile "\..\..\lib\WebView2\64bit\WebView2Loader.dll")}
        dir := AppWindow.DataDir()
        ui := dir "\ui"
        stamp := App.Version " " FileGetTime(A_ScriptFullPath)
        current := ""
        try current := FileRead(ui "\build.txt")
        if current != stamp {
            DirCreate(ui)
            ; FileInstall needs a literal source and must start its own line (Ahk2Exe)
            FileInstall("..\ui\index.html", ui "\index.html", 1)
            FileInstall("..\ui\app.css", ui "\app.css", 1)
            FileInstall("..\ui\app.js", ui "\app.js", 1)
            FileInstall("..\ui\logo-bright.svg", ui "\logo-bright.svg", 1)
            FileInstall("..\ui\logo-dark.svg", ui "\logo-dark.svg", 1)
            ; Another running copy may hold the DLL; the one there is then used
            try FileInstall("..\lib\WebView2\64bit\WebView2Loader.dll", dir "\WebView2Loader.dll", 1)
            try FileDelete(ui "\build.txt")
            FileAppend(stamp, ui "\build.txt", "UTF-8-RAW")
            Log.Write("window files unpacked to " ui)
        }
        return {Ui: ui, Loader: dir "\WebView2Loader.dll"}
    }

    static _SetIcon(hwnd) {
        try {
            file := A_IsCompiled ? A_ScriptFullPath : TrayUI._FullPath(A_LineFile "\..\..\assets\app.ico")
            big := LoadPicture(file, "Icon1 w32 h32", &type)
            small := LoadPicture(file, "Icon1 w16 h16", &type)
            SendMessage(0x80, 1, big, hwnd)    ; WM_SETICON, ICON_BIG
            SendMessage(0x80, 0, small, hwnd)  ; ICON_SMALL
        }
    }
}

; Shown instead of the window when the WebView2 Runtime is missing
class RuntimeMissingWindow {
    static Show() {
        win := Gui("-MaximizeBox -MinimizeBox", App.Name)
        win.SetFont("s10", "Segoe UI")
        win.AddText("x20 y20 w420", T("window.no_runtime"))
        win.AddLink("x20 y+12 w420", Format('<a href="{1}">{2}</a>', AppWindow.RuntimeUrl, T("window.no_runtime_link")))
        win.AddButton("x340 y+20 w100 h28 Default", T("btn.close")).OnEvent("Click", (*) => win.Destroy())
        win.OnEvent("Escape", (*) => win.Destroy())
        win.Show()
    }
}
