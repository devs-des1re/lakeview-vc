; ---------------------------------------------------------------------------
; Ui.ahk - the WebView2 (HTML) settings window.
;
; Hosts ui\index.html in a native window. JS calls back into AHK through
; callbacks registered with AddCallbackToScript; AHK pushes status/state to the
; page with PostWebMessageAsJson. Closing the window hides it to the tray.
; ---------------------------------------------------------------------------

class Ui {
    static Window := ""

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

        g := WebViewGui("+Resize -Caption", "LakeviewVC",, settings)
        this.Window := g

        g.AddCallbackToScript("GetState", (*) => this.GetStateJson())
        g.AddCallbackToScript("Save", (wv, payload) => this.OnSave(payload))
        g.AddCallbackToScript("OpenDataFolder", (*) => (Run(Paths.AppDataDir), "Opened."))
        g.AddCallbackToScript("ResetDefaults", (*) => this.OnReset())
        g.AddCallbackToScript("CloseWindow", (*) => (this.Hide(), ""))

        g.OnEvent("Close", (*) => this.Hide())

        if (A_IsCompiled) {
            g.Navigate("index.html")
        } else {
            g.BrowseFolder(A_ScriptDir "\..\ui")
            g.Navigate("index.html")
        }

        g.Show("w820 h560")
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
        Loop 9 {
            a := Config.GetAbbr(A_Index)
            if (a != "")
                abbrs.Push(a)
        }

        modelList := []
        for key in Models.Keys() {
            p := Models.Get(key)
            modelList.Push({ key: key, label: p.Label, desc: p.Description })
        }

        return {
            vcHotkey: Config.Get("General", "VcHotkey"),
            staffHotkey: Config.Get("Staff", "StaffHotkey"),
            staffEnabled: Config.GetBool("Staff", "Enabled"),
            saveCaptures: Config.GetBool("Settings", "SaveCaptures"),
            logging: Config.GetBool("Settings", "Logging"),
            model: Config.Get("Settings", "Model"),
            abbrs: abbrs,
            models: modelList,
            engineOk: Paths.EngineExe != "",
            debug: this.BuildDebug()
        }
    }

    static BuildDebug() {
        return {
            version: "v0.1",
            os: this.OsVersion(),
            ahk: A_AhkVersion,
            webview2: this.WebView2Version(),
            model: Config.Get("Settings", "Model"),
            engine: Paths.EngineExe != "" ? "found" : "missing",
            dataDir: Paths.AppDataDir
        }
    }

    static OsVersion() {
        try {
            v := RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "ProductName")
            build := RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "CurrentBuildNumber")
            return v " (build " build ")"
        } catch {
            return "Windows"
        }
    }

    static WebView2Version() {
        for key in ["HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
                  , "HKLM\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
                  , "HKCU\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"] {
            try {
                v := RegRead(key, "pv")
                if (v != "")
                    return v
            }
        }
        return "unknown"
    }

    static OnSave(jsonText) {
        try {
            ; Parse as objects (not Maps) so property access works.
            state := JSON.parse(jsonText, false, false)

            Config.Set("General", "VcHotkey", this.CleanHotkey(state.vcHotkey))
            Config.Set("Staff", "Enabled", state.staffEnabled ? 1 : 0)
            Config.Set("Staff", "StaffHotkey", this.CleanHotkey(state.staffHotkey))

            Loop 9
                Config.SetAbbr(A_Index, "")

            abbrs := state.abbrs
            if (Type(abbrs) = "Array") {
                Limit := Min(9, abbrs.Length)
                Loop Limit
                    Config.SetAbbr(A_Index, Trim(abbrs[A_Index]))
            }

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
}
