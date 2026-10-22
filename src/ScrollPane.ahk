; A child window that scrolls its controls up and down. AutoHotkey has no scrollable
; container, so the pane moves its controls itself (ScrollWindowEx) and drives a standard
; vertical scroll bar. The mouse wheel scrolls the pane under the cursor.
class ScrollPane {
    static ByHwnd := Map()        ; pane window -> ScrollPane, for the message handlers
    static Hooked := false
    static WheelLines := 3
    static LinePx := 16

    ; parentHwnd: the window the pane fills; backColor: should match what's around it
    __New(parentHwnd, backColor) {
        g := Gui("-Caption +Parent" parentHwnd " +0x200000")  ; WS_VSCROLL
        this.ParentHwnd := parentHwnd
        g.BackColor := backColor
        g.MarginX := 0, g.MarginY := 0
        this.Gui := g
        this.Pos := 0
        this.ContentH := 0
        this.ViewH := 0
        ScrollPane.ByHwnd[g.Hwnd] := this
        if !ScrollPane.Hooked {
            OnMessage(0x115, ObjBindMethod(ScrollPane, "_OnVScroll"))  ; WM_VSCROLL
            OnMessage(0x20A, ObjBindMethod(ScrollPane, "_OnWheel"))    ; WM_MOUSEWHEEL
            ScrollPane.Hooked := true
        }
    }

    ; Fills the parent's client area, once the parent is shown and the controls are added.
    ; contentH: height of the content, in the same units as the control positions.
    Fill(contentH) {
        rect := Buffer(16)
        DllCall("GetClientRect", "Ptr", this.ParentHwnd, "Ptr", rect)
        w := NumGet(rect, 8, "Int"), h := NumGet(rect, 12, "Int")
        bar := DllCall("GetSystemMetrics", "Int", 2)  ; SM_CXVSCROLL: Show sizes the client area
        scale := A_ScreenDPI / 96
        this.Gui.Show(Format("x0 y0 w{} h{} NoActivate", (w - bar) / scale, h / scale))
        this._ToTop()
        this.ViewH := h
        this.ContentH := Round(contentH * scale)
        this._UpdateBar()
    }

    Visible {
        get => DllCall("IsWindowVisible", "Ptr", this.Gui.Hwnd)
        set {
            if value {
                this.Gui.Show("NoActivate")
                this._ToTop()
            } else
                this.Gui.Hide()
        }
    }

    ; Above its siblings, such as the page window a Tab3 control shows for the selected tab
    _ToTop() => DllCall("SetWindowPos", "Ptr", this.Gui.Hwnd, "Ptr", 0, "Int", 0, "Int", 0
        , "Int", 0, "Int", 0, "UInt", 0x13)  ; HWND_TOP; SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE

    ScrollTo(pos) {
        pos := Max(0, Min(pos, this.ContentH - this.ViewH))
        if pos = this.Pos
            return
        ; SW_SCROLLCHILDREN | SW_INVALIDATE | SW_ERASE
        DllCall("ScrollWindowEx", "Ptr", this.Gui.Hwnd, "Int", 0, "Int", this.Pos - pos
            , "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 0x7)
        this.Pos := pos
        this._UpdateBar()
    }

    Destroy() {
        ScrollPane.ByHwnd.Delete(this.Gui.Hwnd)
        this.Gui.Destroy()
    }

    _UpdateBar() {
        si := Buffer(28, 0)  ; SCROLLINFO
        NumPut("UInt", 28, "UInt", 0x7, "Int", 0, "Int", Max(this.ContentH - 1, 0)
            , "UInt", this.ViewH, "Int", this.Pos, si)  ; SIF_RANGE | SIF_PAGE | SIF_POS
        DllCall("SetScrollInfo", "Ptr", this.Gui.Hwnd, "Int", 1, "Ptr", si, "Int", true)  ; SB_VERT
    }

    _TrackPos() {
        si := Buffer(28, 0)
        NumPut("UInt", 28, "UInt", 0x10, si)  ; SIF_TRACKPOS
        DllCall("GetScrollInfo", "Ptr", this.Gui.Hwnd, "Int", 1, "Ptr", si)
        return NumGet(si, 24, "Int")
    }

    static _OnVScroll(wParam, lParam, msg, hwnd) {
        if !ScrollPane.ByHwnd.Has(hwnd)
            return
        pane := ScrollPane.ByHwnd[hwnd]
        line := Round(ScrollPane.LinePx * A_ScreenDPI / 96)
        switch wParam & 0xFFFF {
            case 0: pane.ScrollTo(pane.Pos - line)          ; SB_LINEUP
            case 1: pane.ScrollTo(pane.Pos + line)          ; SB_LINEDOWN
            case 2: pane.ScrollTo(pane.Pos - pane.ViewH)    ; SB_PAGEUP
            case 3: pane.ScrollTo(pane.Pos + pane.ViewH)    ; SB_PAGEDOWN
            case 4, 5: pane.ScrollTo(pane._TrackPos())      ; SB_THUMBPOSITION, SB_THUMBTRACK
            case 6: pane.ScrollTo(0)                        ; SB_TOP
            case 7: pane.ScrollTo(pane.ContentH)            ; SB_BOTTOM
        }
        return 0
    }

    ; The wheel message goes to the focused window, so the pane is found under the cursor
    static _OnWheel(wParam, lParam, msg, hwnd) {
        x := lParam & 0xFFFF, y := (lParam >> 16) & 0xFFFF  ; signed screen coordinates
        x := x > 0x7FFF ? x - 0x10000 : x, y := y > 0x7FFF ? y - 0x10000 : y
        point := (x & 0xFFFFFFFF) | ((y & 0xFFFFFFFF) << 32)  ; POINT passed as one Int64
        win := DllCall("WindowFromPoint", "Int64", point, "Ptr")
        while win && !ScrollPane.ByHwnd.Has(win)
            win := DllCall("GetParent", "Ptr", win, "Ptr")
        if !win
            return
        pane := ScrollPane.ByHwnd[win]
        if !pane.Visible
            return
        delta := (wParam >> 16) & 0xFFFF
        delta := delta > 0x7FFF ? delta - 0x10000 : delta
        pane.ScrollTo(pane.Pos - Round(delta / 120 * ScrollPane.WheelLines * ScrollPane.LinePx * A_ScreenDPI / 96))
        return 0
    }
}
