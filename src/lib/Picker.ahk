; ---------------------------------------------------------------------------
; Picker.ahk - the "Select VC" popup shown by the staff hotkey.
;
; Uses the same WebView2 styling as the main window. AHK pushes the list of
; abbreviations to ui\vcpicker.html; JS calls back with the chosen number (or
; "cancel"). Show() blocks (while the message pump runs) until a choice is
; made or it times out.
; ---------------------------------------------------------------------------

class Picker {
    static Window := ""
    static Items := []
    static Result := ""
    static Done := false

    ; Shows the picker for `abbrs` (array of abbreviation strings). Returns the
    ; chosen key ("1"-"9") or "" if cancelled. Blocks until resolved.
    static Show(abbrs, timeoutMs := 15000) {
        this.Items := abbrs
        this.Result := ""
        this.Done := false

        settings := { DataDir: Paths.WebViewPickerDataDir }
        if (A_IsCompiled) {
            WebViewCtrl.CreateFileFromResource((A_PtrSize * 8) "bit\WebView2Loader.dll", WebViewCtrl.TempDir)
            settings.DllPath := WebViewCtrl.TempDir "\" (A_PtrSize * 8) "bit\WebView2Loader.dll"
        }

        g := WebViewGui("+AlwaysOnTop -Resize -Caption +ToolWindow", "Select VC",, settings)
        this.Window := g

        g.AddCallbackToScript("Choose", (wv, num) => this.Choose(num))
        g.AddCallbackToScript("Ready", (*) => this.PushItems())

        if (A_IsCompiled)
            g.Navigate("vcpicker.html")
        else {
            g.BrowseFolder(A_ScriptDir "\..\ui")
            g.Navigate("vcpicker.html")
        }

        height := 112 + (Min(abbrs.Length, 9) * 38)
        g.Show(Format("w280 h{}", height))
        this.CenterWindow(g.Hwnd)
        this.SetWindowIcon(g)
        try WinActivate("ahk_id " g.Hwnd)

        ; Wait for the choice. Sleep pumps the message queue, so WebView2
        ; callbacks (Choose/Ready) are still delivered meanwhile.
        start := A_TickCount
        while (!this.Done && A_TickCount - start < timeoutMs)
            Sleep 20

        try g.Destroy()
        this.Window := ""
        return this.Result
    }

    static Choose(num) {
        this.Result := (num = "cancel") ? "" : "" num
        this.Done := true
        if (this.Window != "")
            try this.Window.Hide()
        return ""
    }

    static PushItems() {
        if (this.Window = "")
            return
        payload := JSON.stringify({ type: "items", items: this.Items })
        try this.Window.PostWebMessageAsJson(payload)
    }

    static CenterWindow(hwnd) {
        hMon := DllCall("MonitorFromWindow", "ptr", hwnd, "uint", 0x2, "ptr")
        mi := Buffer(40, 0)
        NumPut("uint", 40, mi, 0)
        DllCall("GetMonitorInfo", "ptr", hMon, "ptr", mi)
        monW := NumGet(mi, 28, "int") - NumGet(mi, 20, "int")
        monH := NumGet(mi, 32, "int") - NumGet(mi, 24, "int")
        monX := NumGet(mi, 20, "int")
        monY := NumGet(mi, 24, "int")

        WinGetPos(&wX, &wY, &wW, &wH, "ahk_id " hwnd)
        x := monX + (monW - wW) // 2
        y := monY + (monH - wH) // 2
        try WinMove(x, y, , , "ahk_id " hwnd)
    }

    static SetWindowIcon(g) {
        if (Paths.IconFile = "" || !FileExist(Paths.IconFile))
            return
        hSmall := DllCall("LoadImage", "ptr", 0, "str", Paths.IconFile, "uint", 1, "int", 16, "int", 16, "uint", 0x10, "ptr")
        if hSmall
            SendMessage(0x80, 0, hSmall, , "ahk_id " g.Hwnd)
    }
}
