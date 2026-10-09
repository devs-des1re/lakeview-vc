; ---------------------------------------------------------------------------
; Config.ahk - persistent settings stored in %APPDATA%\LakeviewVC\config.ini.
; Missing keys are written back with their defaults on first load.
; ---------------------------------------------------------------------------

class Config {
    static Ini := Paths.ConfigFile

    static Defaults := Map(
        "General", Map(
            "VcHotkey", "F8",
            "CaptureWidth", 420,
            "CaptureHeight", 110,
            "CaptureScale", 2
        ),
        "Staff", Map(
            "Enabled", 1,
            "StaffHotkey", "F9",
            "Abbr1", "", "Abbr2", "", "Abbr3", "",
            "Abbr4", "", "Abbr5", "", "Abbr6", "",
            "Abbr7", "", "Abbr8", "", "Abbr9", ""
        ),
        "Settings", Map(
            "Model", "accurate",
            "SaveCaptures", 1,
            "Logging", 1
        )
    )

    ; Ensures every default key exists in the ini file.
    static Load() {
        sentinel := "`u{1F5FF}__missing__`u{1F5FF}"
        for section, keys in this.Defaults {
            for key, def in keys {
                if (IniRead(this.Ini, section, key, sentinel) = sentinel)
                    IniWrite(def, this.Ini, section, key)
            }
        }
    }

    static Get(section, key, defaultVal := "") {
        def := (this.Defaults.Has(section) && this.Defaults[section].Has(key))
            ? this.Defaults[section][key] : defaultVal
        return IniRead(this.Ini, section, key, def)
    }

    static Set(section, key, value) {
        IniWrite(value, this.Ini, section, key)
    }

    static GetInt(section, key) {
        return this.Get(section, key, "0") + 0
    }

    static GetBool(section, key) {
        v := this.Get(section, key, "0")
        return (v = "1" || v = "true" || v = "yes")
    }

    static GetAbbr(n) {
        return this.Get("Staff", "Abbr" n, "")
    }

    static SetAbbr(n, value) {
        this.Set("Staff", "Abbr" n, value)
    }
}
