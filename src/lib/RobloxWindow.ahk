; ---------------------------------------------------------------------------
; RobloxWindow.ahk - locating the Roblox window and sending chat commands.
;
; Commands are placed on the clipboard and pasted. The clipboard's previous
; text content is restored afterwards. The chat box is opened with "/" (which
; Roblox auto-inserts), cleared, then filled and sent.
; ---------------------------------------------------------------------------

class RobloxWindow {
    static Process := "RobloxPlayerBeta.exe"

    static WinTitle() {
        return "ahk_exe " this.Process
    }

    static IsActive() {
        return WinActive(this.WinTitle()) != 0
    }

    static Exists() {
        return WinExist(this.WinTitle()) != 0
    }

    ; Activates the Roblox window. Returns true on success.
    static Activate() {
        if !this.Exists()
            return false
        try {
            WinActivate(this.WinTitle())
            return WinWaitActive(this.WinTitle(), , 2) != 0
        } catch {
            return false
        }
    }

    ; Sends a chat command line. Returns true on success.
    static SendCommand(text) {
        if !this.Activate()
            throw Error("Roblox window not found or could not be activated.")

        saved := this.SaveClipboard()
        sent := false
        try {
            ; Open chat and clear the auto-inserted "/".
            SendEvent "/"
            Sleep 60
            SendEvent "{Backspace}"
            Sleep 40

            A_Clipboard := text
            if !ClipWait(2) {
                throw Error("Clipboard did not receive the command text.")
            }
            SendEvent "^v"
            Sleep 80
            SendEvent "{Enter}"
            sent := true
        } finally {
            Sleep 60
            this.RestoreClipboard(saved)
        }
        return sent
    }

    ; Snapshots every clipboard format so images/files survive a command send.
    static SaveClipboard() {
        try
            return ClipboardAll()
        catch
            return ""
    }

    static RestoreClipboard(saved) {
        try {
            if (saved != "")
                A_Clipboard := saved
        } catch {
            ; Non-fatal: clipboard restore can fail if another app holds it.
        }
    }
}
