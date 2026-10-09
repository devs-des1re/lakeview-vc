; ---------------------------------------------------------------------------
; Staff.ahk - staff workflow: resolve a username, ask which VC (1-9) from the
; configured abbreviations, then send ":log vc {username} {selection}".
; ---------------------------------------------------------------------------

class Staff {
    ; Returns an array of { Key, Index, Abbr } for configured abbreviations.
    static Abbreviations() {
        out := []
        Loop 9 {
            abbr := Config.GetAbbr(A_Index)
            if (abbr != "")
                out.Push({ Key: String(A_Index), Index: A_Index, Abbr: abbr })
        }
        return out
    }

    static IsEnabled() {
        return Config.GetBool("Staff", "Enabled")
    }

    ; Runs the full staff flow using a resolved username.
    static RunWithUsername(username) {
        if (username = "") {
            App.Notify("LakeviewVC", "No Roblox username detected.")
            return
        }

        abbrs := this.Abbreviations()
        if (abbrs.Length = 0) {
            App.Notify("LakeviewVC", "No staff abbreviations configured. Set them in the Staff tab.")
            return
        }

        key := this.PromptForKey(abbrs)
        if (key = "") {
            Logger.Info("Staff VC selection cancelled.")
            return
        }

        selection := this.AbbrFor(key)
        command := ":log vc " username " " selection
        Logger.Action("Sending: " command)
        try {
            RobloxWindow.SendCommand(command)
            App.SetStatus("Sent: " command)
        } catch as e {
            Logger.Exception(e, "Staff send")
            App.Notify("LakeviewVC error", e.Message)
        }
    }

    static AbbrFor(key) {
        return Config.GetAbbr(key + 0)
    }

    ; Shows a small always-on-top prompt and waits for a single 1-9 keypress.
    ; Returns the pressed key as a string, or "" if cancelled/timed out.
    static PromptForKey(abbrs) {
        prompt := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "Select VC")
        prompt.SetFont("s10", "Segoe UI")
        prompt.MarginX := 16
        prompt.MarginY := 12

        lines := ""
        for a in abbrs
            lines .= a.Key ". " a.Abbr "`n"
        prompt.BackColor := 0x1E1E1E
        prompt.Add("Text", "cWhite", "Press a number to log the VC:`n`n" RTrim(lines, "`n"))
        prompt.Add("Text", "cGray", "Esc to cancel.")
        prompt.Show()
        WinActivate("Select VC")

        ; End on a digit or Escape; the pressed key is stored in EndKey.
        ih := InputHook("T10", "123456789{Esc}")
        ih.Start()
        ih.Wait()
        try prompt.Destroy()

        if (ih.EndKey ~= "^[1-9]$")
            return ih.EndKey
        return ""
    }
}
