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

;@Ahk2Exe-SetMainIcon %A_ScriptDir%\..\icon.ico
;@Ahk2Exe-SetName LakeviewVC
;@Ahk2Exe-SetDescription LakeviewVC
;@Ahk2Exe-SetCompanyName LakeviewVC
;@Ahk2Exe-SetCopyright Copyright (c) 2026 Arjun Patel

; Embedded Web UI (served from exe resources when compiled). Resource names
; must match the uppercased request path: "/fonts/x.ttf" -> "FONTS\X.TTF".
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\index.html, INDEX.HTML
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\style.css, STYLE.CSS
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\app.js, APP.JS
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\vcpicker.html, VCPICKER.HTML
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\vcpicker.js, VCPICKER.JS
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\icon.png, ICON.PNG
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\fonts\Outfit-Light.ttf, FONTS\OUTFIT-LIGHT.TTF
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\fonts\Outfit-Regular.ttf, FONTS\OUTFIT-REGULAR.TTF
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\fonts\Outfit-Medium.ttf, FONTS\OUTFIT-MEDIUM.TTF
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\fonts\Outfit-SemiBold.ttf, FONTS\OUTFIT-SEMIBOLD.TTF
;@Ahk2Exe-AddResource %A_ScriptDir%\..\ui\fonts\Outfit-Bold.ttf, FONTS\OUTFIT-BOLD.TTF
;@Ahk2Exe-AddResource %A_ScriptDir%\..\vendor\webview\64bit\WebView2Loader.dll, 64bit\WebView2Loader.dll

#Include %A_ScriptDir%\version.ahk
#Include %A_ScriptDir%\lib\Paths.ahk
#Include %A_ScriptDir%\..\vendor\JSON.ahk
#Include %A_ScriptDir%\..\vendor\webview\WebViewToo.ahk
#Include %A_ScriptDir%\lib\Logger.ahk
#Include %A_ScriptDir%\lib\Config.ahk
#Include %A_ScriptDir%\lib\Capture.ahk
#Include %A_ScriptDir%\lib\Models.ahk
#Include %A_ScriptDir%\lib\Ocr.ahk
#Include %A_ScriptDir%\lib\RobloxApi.ahk
#Include %A_ScriptDir%\lib\Resolver.ahk
#Include %A_ScriptDir%\lib\RobloxWindow.ahk
#Include %A_ScriptDir%\lib\Picker.ahk
#Include %A_ScriptDir%\lib\Staff.ahk
#Include %A_ScriptDir%\lib\Ui.ahk

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
            App.SetStatus("Sent: " command)
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
        scale := Config.GetInt("General", "CaptureScale")
        model := Config.Get("Settings", "Model")

        if !Models.IsInstalled(model)
            throw Error("OCR model '" model "' is not installed. Open the GUI and press Save to download it.")

        stamp := FormatTime(, "yyyyMMdd_HHmmss")
        png := Paths.CapturesDir "\" stamp "_" context ".png"

        keep := Config.GetBool("Settings", "SaveCaptures")
        try {
            Logger.Info(Format("Capture {1}x{2} (x{3}) at mouse for '{4}'.", width, height, scale, context))
            Capture.AtMouse(width, height, png, scale)

            items := Ocr.Recognize(png, model)
            Logger.Info("OCR items: " this.DescribeItems(items))

            if (items.Length = 0)
                return ""

            target := Resolver.ResolveItems(items)
            if (target = "") {
                Logger.Warn("Could not resolve OCR items.")
                return ""
            }

            Logger.Info(Format("Resolved -> {1} (display '{2}', method {3}).", target.Name, target.DisplayName, target.Method))
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

    static DescribeItems(items) {
        parts := []
        for it in items
            parts.Push("'" it.Text "'")
        return parts.Length ? this.JoinStr(parts, ", ") : "<none>"
    }

    static JoinStr(parts, sep) {
        out := ""
        for i, p in parts
            out .= (i > 1 ? sep : "") p
        return out
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
        ; Option 4 = use the tray icon as the toast logo, so notifications show
        ; the app icon (with the AUMID providing the app name).
        TrayTip(message, title, 4)
    }

    static SetStatus(text) {
        if Ui.Exists()
            Ui.PushStatus(text, "")
    }

    static OpenGui() {
        Ui.Open()
    }

    static Quit() {
        Logger.Info("LakeviewVC exiting.")
        ExitApp()
    }
}

; --- shell identity ----------------------------------------------------------
; Windows shows the AppUserModelID's display name and icon on toast
; notifications. Without this they default to "AutoHotkey" and its icon.
class Shell {
    static AppId := "LakeviewVC"

    static RegisterIdentity() {
        key := "HKCU\SOFTWARE\Classes\AppUserModelId\" this.AppId
        try {
            RegWrite(this.AppId, "REG_SZ", key, "DisplayName")
            if (Paths.IconFile != "" && FileExist(Paths.IconFile))
                RegWrite(Paths.IconFile, "REG_SZ", key, "IconUri")
        } catch {
            ; Registry write is best-effort; notifications still work.
        }
        try DllCall("shell32\SetCurrentProcessExplicitAppUserModelID", "wstr", this.AppId)
    }
}

; --- startup -----------------------------------------------------------------
Paths.EnsureDataDirs()
Config.Load()
Shell.RegisterIdentity()
Logger.Enabled := Config.GetBool("Settings", "Logging")
Logger.Info("LakeviewVC started.")
Logger.Info("Engine: " (Paths.EngineExe != "" ? Paths.EngineExe : "<not found>"))

; Hotkeys are scoped to the Roblox window so typing elsewhere never triggers.
Hotkeys.Register()

; --- tray --------------------------------------------------------------------
A_IconTip := "LakeviewVC"
if (Paths.IconFile != "" && FileExist(Paths.IconFile))
    TraySetIcon(Paths.IconFile)
Tray := A_TrayMenu
Tray.Delete()
Tray.Add("Open GUI", (*) => App.OpenGui())
Tray.Add()
Tray.Add("Close App", (*) => App.Quit())
Tray.Default := "Open GUI"
Tray.ClickCount := 1  ; single left-click opens the GUI

if !Paths.EngineExe
    App.Notify("LakeviewVC", "OCR engine not found under engines\RapidOCR-json.")

; Show the UI on launch; the user can minimize it to the tray from there.
App.OpenGui()
