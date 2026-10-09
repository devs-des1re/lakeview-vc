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
#Include %A_ScriptDir%\lib\Staff.ahk
#Include %A_ScriptDir%\lib\Gui.ahk

; --- pipeline ----------------------------------------------------------------
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
            if !RobloxWindow.SendCommand(command) {
                Logger.Err("Send did not complete: " command)
                App.Notify("LakeviewVC", "Could not send the chat command.")
                return
            }
            GuiApp.SetStatus("Sent: " command)
        } catch as e {
            Logger.Exception(e, "RunVc")
            App.Notify("LakeviewVC error", e.Message)
        }
    }

    ; Full staff flow: capture -> OCR -> resolve -> choose VC -> send log.
    static RunStaff() {
        try {
            Logger.Info("Staff hotkey triggered.")
            target := this.Detect("staff")
            Staff.RunWithUsername(target)
        } catch as e {
            Logger.Exception(e, "RunStaff")
            App.Notify("LakeviewVC error", e.Message)
        }
    }

    ; Capture + OCR + resolve. Returns the resolved username or "".
    static Detect(context) {
        Paths.EnsureDataDirs()

        width := Config.GetInt("General", "CaptureWidth")
        height := Config.GetInt("General", "CaptureHeight")
        model := Config.Get("Settings", "Model")

        if !Models.IsInstalled(model)
            throw Error("OCR model '" model "' is not installed. Open the GUI and press Save to download it.")

        stamp := FormatTime(, "yyyyMMdd_HHmmss")
        png := Paths.CapturesDir "\" stamp "_" context ".png"

        keep := Config.GetBool("Settings", "SaveCaptures")
        try {
            Logger.Info(Format("Capture {1}x{2} at mouse for '{3}'.", width, height, context))
            Capture.AtMouse(width, height, png)

            text := Ocr.RecognizeText(png, model)
            Logger.Info("OCR text: " (text != "" ? text : "<empty>"))

            if (text = "")
                return ""

            target := Resolver.Resolve(text)
            if (target = "") {
                Logger.Warn("Could not resolve OCR text: " text)
                return ""
            }

            Logger.Info(Format("Resolved '{1}' -> {2} ({3}).", text, target.Name, target.Method))
            return target.Name
        } finally {
            if (!keep) {
                try {
                    if FileExist(png)
                        FileDelete(png)
                } catch {
                    ; Best-effort cleanup.
                }
            }
        }
    }
}

; --- hotkey management -------------------------------------------------------
class Hotkeys {
    static Registered := []

    ; Context callback: hotkeys only fire while Roblox is focused.
    static RobloxActive(*) {
        return RobloxWindow.IsActive()
    }

    static Register() {
        ; Re-registering can happen from a GUI thread, so set context explicitly.
        HotIf(Hotkeys.RobloxActive)

        ; Clear previous registrations.
        for hk in this.Registered {
            try Hotkey hk, "Off"
        }
        this.Registered := []

        vc := Config.Get("General", "VcHotkey")
        if (vc != "") {
            try {
                Hotkey vc, (*) => Pipeline.RunVc(), "On"
                this.Registered.Push(vc)
                Logger.Info("Registered VC hotkey: " vc)
            } catch as e {
                Logger.Exception(e, "Register VC hotkey")
                App.Notify("LakeviewVC", "Could not register VC hotkey: " vc)
            }
        }

        if Staff.IsEnabled() {
            staffHk := Config.Get("Staff", "StaffHotkey")
            if (staffHk != "") {
                try {
                    Hotkey staffHk, (*) => Pipeline.RunStaff(), "On"
                    this.Registered.Push(staffHk)
                    Logger.Info("Registered staff hotkey: " staffHk)
                } catch as e {
                    Logger.Exception(e, "Register staff hotkey")
                    App.Notify("LakeviewVC", "Could not register staff hotkey: " staffHk)
                }
            }
        }

        HotIf()  ; restore global context
    }
}

; --- small app helpers -------------------------------------------------------
class App {
    static Notify(title, message) {
        TrayTip(message, title, 0x1)
    }

    static SetStatus(text) {
        GuiApp.SetStatus(text)
    }

    static OpenGui() {
        GuiApp.Open()
    }

    static Quit() {
        Logger.Info("LakeviewVC exiting.")
        ExitApp()
    }
}

; --- startup -----------------------------------------------------------------
Paths.EnsureDataDirs()
Config.Load()
Logger.Enabled := Config.GetBool("Settings", "Logging")
Logger.Info("LakeviewVC started.")
Logger.Info("Engine: " (Paths.EngineExe != "" ? Paths.EngineExe : "<not found>"))

; Hotkeys are scoped to the Roblox window so typing elsewhere never triggers.
Hotkeys.Register()

; --- tray --------------------------------------------------------------------
A_IconTip := "LakeviewVC"
Tray := A_TrayMenu
Tray.Delete()
Tray.Add("Open GUI", (*) => App.OpenGui())
Tray.Add()
Tray.Add("Close App", (*) => App.Quit())
Tray.Default := "Open GUI"
Tray.ClickCount := 1  ; single left-click opens the GUI

if !Paths.EngineExe
    App.Notify("LakeviewVC", "OCR engine not found under engines\RapidOCR-json.")
