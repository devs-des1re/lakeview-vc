; ---------------------------------------------------------------------------
; Gui.ahk - the tabbed settings window.
;
; Tabs: General (VC hotkey, capture size), Staff (hotkey + 1-9 abbreviations),
; Settings (model, logging, data folder, reset), About. Closing the window
; hides it to the tray. All values persist to config.ini on Save.
; ---------------------------------------------------------------------------

class GuiApp {
    static Gui := ""
    static Ctl := Map()
    static StatusText := "Idle"

    static Open() {
        if (this.Gui != "") {
            try {
                this.Gui.Show()
                this.Refresh()
                return
            }
        }
        this.Build()
    }

    static Build() {
        g := Gui("+Resize -MaximizeBox", "LakeviewVC")
        g.SetFont("s9", "Segoe UI")
        g.BackColor := 0x1E1E1E
        g.MarginX := 14
        g.MarginY := 12
        this.Gui := g

        ; --- Tabs -----------------------------------------------------------
        tabs := g.Add("Tab3", "w460 h330 cFFFFFF", ["General", "Staff", "Settings", "About"])
        this.Ctl["Tabs"] := tabs

        this.BuildGeneral(tabs)
        tabs.UseTab(2)
        this.BuildStaff(tabs)
        tabs.UseTab(3)
        this.BuildSettings(tabs)
        tabs.UseTab(4)
        this.BuildAbout(tabs)
        tabs.UseTab(0)

        ; --- Footer ---------------------------------------------------------
        g.SetFont("s8", "Segoe UI")
        g.Add("Text", "xm w460 cGray", "LakeviewVC is an independent tool and is not affiliated with, endorsed by,")
        g.Add("Text", "xm w460 cGray", "or associated with Lakeview City RP or Roblox Corporation.")

        save := g.Add("Button", "xm w90", "Save")
        save.OnEvent("Click", (*) => this.Save())
        open := g.Add("Button", "x+m yp w130", "Open Data Folder")
        open.OnEvent("Click", (*) => Run(Paths.AppDataDir))

        this.Ctl["Status"] := g.Add("Text", "xm w460 cWhite", "Status: " this.StatusText)

        g.OnEvent("Close", (*) => this.Hide())
        g.OnEvent("Escape", (*) => this.Hide())
        this.Refresh()
        g.Show()
    }

    static BuildGeneral(tabs) {
        g := this.Gui
        g.SetFont("s9", "Segoe UI")

        g.Add("Text", "xm+18 y+22 cWhite", "VC Hotkey (sends  `;vc {username})")
        this.Ctl["VcHotkey"] := g.Add("Hotkey", "xm+18 w180", Config.Get("General", "VcHotkey"))

        g.Add("Text", "xm+18 y+18 cWhite", "Capture area (pixels, centred on the mouse)")
        this.Ctl["CaptureWidth"] := g.Add("Edit", "xm+18 y+22 w70 Number", Config.Get("General", "CaptureWidth"))
        g.Add("Text", "x+m yp cWhite", " x ")
        this.Ctl["CaptureHeight"] := g.Add("Edit", "x+m yp w70 Number", Config.Get("General", "CaptureHeight"))

        test := g.Add("Button", "xm+18 y+22 w120", "Test Capture")
        test.OnEvent("Click", (*) => this.TestCapture())

        g.Add("Text", "xm+18 y+18 cGray w400", "Hold the mouse over a username in Roblox and press the hotkey.")
    }

    static BuildStaff(tabs) {
        g := this.Gui
        g.SetFont("s9", "Segoe UI")

        g.Add("Text", "xm+18 y+22 cWhite", "Only useful for staff for Lakeview.")
        this.Ctl["StaffEnabled"] := g.Add("CheckBox", "xm+18 y+16 cWhite", "Enable staff hotkey")
        this.Ctl["StaffEnabled"].Value := Config.GetBool("Staff", "Enabled")

        g.Add("Text", "xm+18 y+16 cWhite", "Staff Hotkey (sends  :log vc {username} {selection})")
        this.Ctl["StaffHotkey"] := g.Add("Hotkey", "xm+18 w180", Config.Get("Staff", "StaffHotkey"))

        g.SetFont("s8", "Segoe UI")
        g.Add("Text", "xm+18 y+14 cGray", "Press 1-9 after the staff hotkey. Abbreviations:")
        Loop 9 {
            row := A_Index
            yy := (row = 1) ? "y+8" : "y+4"
            g.Add("Text", "xm+18 " yy " cWhite", row ":")
            this.Ctl["Abbr" row] := g.Add("Edit", "x+m w150", Config.GetAbbr(row))
        }
    }

    static BuildSettings(tabs) {
        g := this.Gui
        g.SetFont("s9", "Segoe UI")

        g.Add("Text", "xm+18 y+22 cWhite", "OCR model")
        this.Ctl["ModelAccurate"] := g.Add("Radio", "xm+18 y+18 cWhite vModel", "Accurate (recommended)")
        this.Ctl["ModelFast"] := g.Add("Radio", "xm+18 y+6 cWhite", "Fast")
        this.SetModelSelection(Config.Get("Settings", "Model"))
        g.Add("Text", "xm+18 y+10 cGray w400", "Accurate keeps underscores and capitalisation better. The selected model")
        g.Add("Text", "xm+18 cGray w400", "is downloaded to the data folder on first save if not already present.")

        this.Ctl["SaveCaptures"] := g.Add("CheckBox", "xm+18 y+18 cWhite", "Save captures to disk")
        this.Ctl["SaveCaptures"].Value := Config.GetBool("Settings", "SaveCaptures")
        this.Ctl["Logging"] := g.Add("CheckBox", "xm+18 y+6 cWhite", "Enable logging")
        this.Ctl["Logging"].Value := Config.GetBool("Settings", "Logging")

        reset := g.Add("Button", "xm+18 y+18 w120", "Reset Defaults")
        reset.OnEvent("Click", (*) => this.ResetDefaults())
    }

    static BuildAbout(tabs) {
        g := this.Gui
        g.SetFont("s9", "Segoe UI")
        g.Add("Text", "xm+18 y+22 cWhite", "LakeviewVC  v0.1")
        g.Add("Text", "xm+18 y+14 cGray w400", "Reads a Roblox username from the screen with offline OCR, resolves it to a")
        g.Add("Text", "xm+18 cGray w400", "real username and sends a chat command.")
        g.Add("Text", "xm+18 y+16 cGray w400", "OCR engine: RapidOCR-json (MIT).")
        g.Add("Text", "xm+18 cGray w400", "License: MIT.")
    }

    static SetModelSelection(key) {
        if (key = "fast")
            this.Ctl["ModelFast"].Value := 1
        else
            this.Ctl["ModelAccurate"].Value := 1
    }

    static SelectedModel() {
        return this.Ctl["ModelFast"].Value ? "fast" : "accurate"
    }

    static Refresh() {
        this.Ctl["VcHotkey"].Value := Config.Get("General", "VcHotkey")
        this.Ctl["StaffHotkey"].Value := Config.Get("Staff", "StaffHotkey")
        this.Ctl["CaptureWidth"].Value := Config.Get("General", "CaptureWidth")
        this.Ctl["CaptureHeight"].Value := Config.Get("General", "CaptureHeight")
        this.Ctl["StaffEnabled"].Value := Config.GetBool("Staff", "Enabled")
        this.Ctl["SaveCaptures"].Value := Config.GetBool("Settings", "SaveCaptures")
        this.Ctl["Logging"].Value := Config.GetBool("Settings", "Logging")
        this.SetModelSelection(Config.Get("Settings", "Model"))
        Loop 9
            this.Ctl["Abbr" A_Index].Value := Config.GetAbbr(A_Index)
        this.SetStatus(this.StatusText)
    }

    static Save() {
        Config.Set("General", "VcHotkey", this.NormalizeHotkey(this.Ctl["VcHotkey"].Value))
        Config.Set("General", "CaptureWidth", this.Positive(this.Ctl["CaptureWidth"].Value, 420))
        Config.Set("General", "CaptureHeight", this.Positive(this.Ctl["CaptureHeight"].Value, 110))

        Config.Set("Staff", "Enabled", this.Ctl["StaffEnabled"].Value ? 1 : 0)
        Config.Set("Staff", "StaffHotkey", this.NormalizeHotkey(this.Ctl["StaffHotkey"].Value))
        Loop 9
            Config.SetAbbr(A_Index, Trim(this.Ctl["Abbr" A_Index].Value))

        model := this.SelectedModel()
        Config.Set("Settings", "Model", model)
        Config.Set("Settings", "SaveCaptures", this.Ctl["SaveCaptures"].Value ? 1 : 0)
        Config.Set("Settings", "Logging", this.Ctl["Logging"].Value ? 1 : 0)
        Logger.Enabled := this.Ctl["Logging"].Value ? true : false

        Logger.Info("Settings saved. Model=" model ".")

        if !Models.IsInstalled(model) {
            this.SetStatus("Downloading " model " model...")
            try {
                Models.Ensure(model, (text, done, total) => this.SetStatus(text))
                Logger.Info("Model ready: " model)
            } catch as e {
                Logger.Exception(e, "Model download")
                MsgBox e.Message, "LakeviewVC - model download failed", "Icon!"
            }
        }

        Hotkeys.Register()
        this.SetStatus("Saved.")
        App.Notify("LakeviewVC", "Settings saved.")
    }

    static NormalizeHotkey(value) {
        value := Trim(value)
        return (value = "") ? "" : value
    }

    static Positive(value, fallback) {
        n := value + 0
        return (n > 0) ? n : fallback
    }

    static TestCapture() {
        this.Save()
        try {
            model := Config.Get("Settings", "Model")
            width := Config.GetInt("General", "CaptureWidth")
            height := Config.GetInt("General", "CaptureHeight")
            Paths.EnsureDataDirs()
            png := Paths.CapturesDir "\test_" FormatTime(, "yyyyMMdd_HHmmss") ".png"
            Capture.AtMouse(width, height, png)
            text := Ocr.RecognizeText(png, model)
            if !Config.GetBool("Settings", "SaveCaptures")
                try FileDelete(png)
            MsgBox (text = "" ? "No text detected." : "Detected:`n`n" text), "Test Capture", "Iconi"
        } catch as e {
            Logger.Exception(e, "TestCapture")
            MsgBox e.Message, "Test Capture failed", "Icon!"
        }
    }

    static ResetDefaults() {
        result := MsgBox("Reset all settings to their defaults?", "LakeviewVC", "YesNo Icon?")
        if (result != "Yes")
            return
        for section, keys in Config.Defaults
            for key, def in keys
                Config.Set(section, key, def)
        this.Refresh()
        Hotkeys.Register()
        this.SetStatus("Defaults restored.")
    }

    static SetStatus(text) {
        this.StatusText := text
        if (this.Ctl.Has("Status"))
            this.Ctl["Status"].Value := "Status: " text
    }

    static Hide() {
        this.Gui.Hide()
        TrayTip("LakeviewVC is still running. Left-click the tray icon to reopen.", "Minimized to tray", 0x1)
    }
}
