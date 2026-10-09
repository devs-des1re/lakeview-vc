; ---------------------------------------------------------------------------
; Ui.ahk - the WebView2 (HTML) settings window.
;
; Hosts ui\index.html in a native window. JS calls back into AHK through
; callbacks registered with AddCallbackToScript; AHK pushes status/state to the
; page with PostWebMessageAsJson. Closing the window hides it to the tray.
; ---------------------------------------------------------------------------

class Ui {
    static Window := ""
    static State := ""

    static Open() {
        if (this.Window != "") {
            try {
                this.Window.Show()
                this.PushState()
                return
            } catch {
                this.Window := ""
            }
        }
        this.Build()
    }

    static Build() {
        settings := {}
        if (A_IsCompiled) {
            WebViewCtrl.CreateFileFromResource((A_PtrSize * 8) "bit\WebView2Loader.dll", WebViewCtrl.TempDir)
            settings := { DllPath: WebViewCtrl.TempDir "\" (A_PtrSize * 8) "bit\WebView2Loader.dll" }
        }

        g := WebViewGui("+Resize -MaximizeBox", "LakeviewVC",, settings)
        this.Window := g

        g.AddCallbackToScript("GetState", (*) => this.GetStateJson())
        g.AddCallbackToScript("Save", (wv, json) => this.OnSave(json))
        g.AddCallbackToScript("TestCapture", (*) => this.OnTestCapture())
        g.AddCallbackToScript("OpenDataFolder", (*) => (Run(Paths.AppDataDir), "Opened."))
        g.AddCallbackToScript("ResetDefaults", (*) => this.OnReset())

        g.OnEvent("Close", (*) => this.Hide())

        if (A_IsCompiled) {
            g.Navigate("index.html")
        } else {
            g.BrowseFolder(A_ScriptDir "\..\ui")
            g.Navigate("index.html")
        }

        g.Show("w860 h620")
    }

    static Hide() {
        try
            this.Window.Hide()
        TrayTip("LakeviewVC is still running. Left-click the tray icon to reopen.", "Minimized to tray", 0x1)
    }

    static Exists() {
        return this.Window != ""
    }

    ; --- bridge -------------------------------------------------------------

    static GetStateJson() {
        return JSON.stringify(this.BuildState())
    }

    static BuildState() {
        abbrs := []
        Loop 9
            abbrs.Push(Config.GetAbbr(A_Index))

        models := []
        for key in Models.Keys() {
            p := Models.Get(key)
            models.Push({ key: key, label: p.Label, desc: p.Description })
        }

        return {
            vcHotkey: Config.Get("General", "VcHotkey"),
            staffHotkey: Config.Get("Staff", "StaffHotkey"),
            captureWidth: Config.GetInt("General", "CaptureWidth"),
            captureHeight: Config.GetInt("General", "CaptureHeight"),
            captureScale: Config.GetInt("General", "CaptureScale"),
            staffEnabled: Config.GetBool("Staff", "Enabled"),
            saveCaptures: Config.GetBool("Settings", "SaveCaptures"),
            logging: Config.GetBool("Settings", "Logging"),
            model: Config.Get("Settings", "Model"),
            abbrs: abbrs,
            models: models,
            engineOk: Paths.EngineExe != ""
        }
    }

    static OnSave(json) {
        try {
            state := JSON.parse(json)

            Config.Set("General", "VcHotkey", this.CleanHotkey(state.vcHotkey))
            Config.Set("General", "CaptureWidth", this.Positive(state.captureWidth, 420))
            Config.Set("General", "CaptureHeight", this.Positive(state.captureHeight, 110))
            Config.Set("General", "CaptureScale", Max(1, Min(4, this.Positive(state.captureScale, 2))))

            Config.Set("Staff", "Enabled", state.staffEnabled ? 1 : 0)
            Config.Set("Staff", "StaffHotkey", this.CleanHotkey(state.staffHotkey))
            Loop 9
                Config.SetAbbr(A_Index, Trim(state.abbrs[A_Index] != "" ? state.abbrs[A_Index] : ""))

            model := Models.Presets.Has(state.model) ? state.model : Models.DefaultKey
            Config.Set("Settings", "Model", model)
            Config.Set("Settings", "SaveCaptures", state.saveCaptures ? 1 : 0)
            Config.Set("Settings", "Logging", state.logging ? 1 : 0)
            Logger.Enabled := state.logging ? true : false

            Logger.Info("Settings saved. Model=" model ".")
            Hotkeys.Register()

            if !Models.IsInstalled(model) {
                this.PushStatus("Downloading " model " model...", "")
                try {
                    Models.Ensure(model, (text, done, total) => this.PushStatus(text, ""))
                } catch as e {
                    Logger.Exception(e, "Model download")
                    this.PushStatus("Model download failed: " e.Message, "err")
                    return "Model download failed."
                }
            }

            this.PushState()
            this.PushStatus("Saved.", "ok")
            return "Saved."
        } catch as e {
            Logger.Exception(e, "Ui.OnSave")
            this.PushStatus("Save failed: " e.Message, "err")
            return "Save failed."
        }
    }

    static OnTestCapture() {
        try {
            model := Config.Get("Settings", "Model")
            width := Config.GetInt("General", "CaptureWidth")
            height := Config.GetInt("General", "CaptureHeight")
            scale := Config.GetInt("General", "CaptureScale")
            Paths.EnsureDataDirs()
            png := Paths.CapturesDir "\test_" FormatTime(, "yyyyMMdd_HHmmss") ".png"
            Capture.AtMouse(width, height, png, scale)
            items := Ocr.Recognize(png, model)
            if !Config.GetBool("Settings", "SaveCaptures")
                try FileDelete(png)

            if (items.Length = 0) {
                this.PushStatus("Test capture: no text detected.", "err")
                return "No text detected."
            }

            raw := ""
            for it in items
                raw .= (raw = "" ? "" : ", ") "'" it.Text "'"

            target := Resolver.ResolveItems(items)
            if (target = "") {
                this.PushStatus("Test capture: detected " raw " but no username resolved.", "err")
                return "No username resolved."
            }
            this.PushStatus("Test capture: " raw " -> " target.Name, "ok")
            return "Resolved: " target.Name
        } catch as e {
            Logger.Exception(e, "Ui.OnTestCapture")
            this.PushStatus("Test capture failed: " e.Message, "err")
            return "Test failed."
        }
    }

    static OnReset() {
        for section, keys in Config.Defaults
            for key, def in keys
                Config.Set(section, key, def)
        Logger.Enabled := Config.GetBool("Settings", "Logging")
        Hotkeys.Register()
        this.PushState()
        this.PushStatus("Defaults restored.", "ok")
        return this.GetStateJson()
    }

    ; --- push helpers -------------------------------------------------------

    static PushState() {
        if !this.Exists()
            return
        payload := JSON.stringify({ type: "state", state: this.BuildState() })
        try this.Window.PostWebMessageAsJson(payload)
    }

    static PushStatus(message, kind) {
        if !this.Exists()
            return
        payload := JSON.stringify({ type: "status", message: message, kind: kind })
        try this.Window.PostWebMessageAsJson(payload)
    }

    static CleanHotkey(value) {
        return (value = "" || value = "Press keys…") ? "" : Trim(value)
    }

    static Positive(value, fallback) {
        n := value + 0
        return (n > 0) ? n : fallback
    }
}
