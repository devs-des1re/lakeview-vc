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

        selection := this.PromptForKey(abbrs)
        if (selection = "") {
            Logger.Info("Staff VC selection cancelled.")
            return
        }

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

    ; Shows the picker and returns the chosen abbreviation, or "" if cancelled.
    static PromptForKey(abbrs) {
        keys := []
        for a in abbrs
            keys.Push(a.Abbr)
        try {
            pos := Picker.Show(keys)
        } catch as e {
            Logger.Exception(e, "Picker.Show")
            App.Notify("LakeviewVC", "Could not open the VC picker.")
            return ""
        }
        if (pos = "" || pos < 1 || pos > abbrs.Length)
            return ""
        return abbrs[pos].Abbr
    }
}
