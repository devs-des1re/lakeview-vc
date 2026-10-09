; ---------------------------------------------------------------------------
; LakeviewVC - reads a Roblox username from screen via offline OCR and sends
; the appropriate chat command.
;
; LakeviewVC is an independent tool and is not affiliated with, endorsed by,
; or associated with Lakeview City RP or Roblox Corporation.
; ---------------------------------------------------------------------------

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

#Include %A_ScriptDir%\lib\Paths.ahk
#Include %A_ScriptDir%\..\vendor\JSON.ahk
#Include %A_ScriptDir%\lib\Logger.ahk
#Include %A_ScriptDir%\lib\Config.ahk
#Include %A_ScriptDir%\lib\Capture.ahk
#Include %A_ScriptDir%\lib\Models.ahk
#Include %A_ScriptDir%\lib\Ocr.ahk
#Include %A_ScriptDir%\lib\RobloxApi.ahk
#Include %A_ScriptDir%\lib\Resolver.ahk
#Include %A_ScriptDir%\lib\RobloxWindow.ahk

class Pipeline {
    ; Full normal flow: capture -> OCR -> resolve -> send ";vc {username}".
    static RunVc() {
        try {
            Logger.Info("VC hotkey triggered.")
            target := this.Detect("vc")
            if (target = "") {
                App.Notify("LakeviewVC", "No Roblox username detected.")
                return
            }

            command := ";vc " target
            Logger.Action("Sending: " command)
            RobloxWindow.SendCommand(command)
            App.SetStatus("Sent: " command)
        } catch as e {
            Logger.Exception(e, "RunVc")
            App.Notify("LakeviewVC error", e.Message)
        }
    }

    ; Capture + OCR + resolve. Returns the resolved username or "".
    static Detect(context) {
        Paths.EnsureDataDirs()

        width := Config.GetInt("General", "CaptureWidth")
        height := Config.GetInt("General", "CaptureHeight")
        model := Config.Get("Settings", "Model")

        stamp := FormatTime(, "yyyyMMdd_HHmmss")
        png := Paths.CapturesDir "\" stamp "_" context ".png"

        Logger.Info(Format("Capture {1}x{2} at mouse for '{3}'.", width, height, context))
        Capture.AtMouse(width, height, png)

        text := Ocr.RecognizeText(png, model)
        Logger.Info("OCR text: " (text != "" ? text : "<empty>"))

        if (text = "") {
            this.CleanupCapture(png)
            return ""
        }

        target := Resolver.Resolve(text)
        this.CleanupCapture(png)

        if (target = "") {
            Logger.Warn("Could not resolve OCR text: " text)
            return ""
        }

        Logger.Info(Format("Resolved '{1}' -> {2} ({3}).", text, target.Name, target.Method))
        return target.Name
    }

    static CleanupCapture(path) {
        if !Config.GetBool("Settings", "SaveCaptures") {
            try
                FileDelete(path)
        }
    }
}

class App {
    static StatusText := "Idle"

    static Notify(title, message) {
        TrayTip(message, title, 0x1)
    }

    static SetStatus(text) {
        App.StatusText := text
    }
}

; --- settings / logging init -------------------------------------------------
Paths.EnsureDataDirs()
Config.Load()
Logger.Enabled := Config.GetBool("Settings", "Logging")
Logger.Info("LakeviewVC started.")
Logger.Info("Engine: " (Paths.EngineExe != "" ? Paths.EngineExe : "<not found>"))

; --- hotkeys (only while Roblox is focused) ----------------------------------
#HotIf RobloxWindow.IsActive()
Hotkey Config.Get("General", "VcHotkey"), (*) => Pipeline.RunVc()
#HotIf

; --- tray --------------------------------------------------------------------
A_IconTip := "LakeviewVC"
Tray := A_TrayMenu
Tray.Delete()
Tray.Add("Open GUI", (*) => App.Notify("LakeviewVC", "GUI arrives in Phase 3."))
Tray.Add("Open Data Folder", (*) => Run(Paths.AppDataDir))
Tray.Add()
Tray.Add("Exit", (*) => ExitApp())
Tray.Default := "Open GUI"

if !Paths.EngineExe
    App.Notify("LakeviewVC", "OCR engine not found under engines\RapidOCR-json.")
