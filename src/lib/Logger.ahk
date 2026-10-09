; ---------------------------------------------------------------------------
; Logger.ahk - timestamped session log plus a persistent errors.log.
;
; Session logs: %APPDATA%\LakeviewVC\logs\<yyyy-MM-dd>.log
; Errors:       %APPDATA%\LakeviewVC\logs\errors.log
; Logging can be disabled from settings; errors are always recorded.
; ---------------------------------------------------------------------------

class Logger {
    static Enabled := true

    static EnsureDirs() {
        if !DirExist(Paths.LogsDir)
            DirCreate(Paths.LogsDir)
    }

    static SessionFile() {
        return Paths.LogsDir "\" FormatTime(, "yyyy-MM-dd") ".log"
    }

    static ErrorFile() {
        return Paths.LogsDir "\errors.log"
    }

    static Info(message) {
        if !this.Enabled
            return
        this.EnsureDirs()
        this.Append(this.SessionFile(), "INFO ", message)
    }

    static Warn(message) {
        if !this.Enabled
            return
        this.EnsureDirs()
        this.Append(this.SessionFile(), "WARN ", message)
    }

    static Action(message) {
        if !this.Enabled
            return
        this.EnsureDirs()
        this.Append(this.SessionFile(), "SEND ", message)
    }

    ; Errors are always written, even when normal logging is off.
    static Err(message) {
        this.EnsureDirs()
        this.Append(this.ErrorFile(), "ERROR", message)
        if this.Enabled
            this.Append(this.SessionFile(), "ERROR", message)
    }

    static Exception(e, context := "") {
        text := (context != "" ? context ": " : "") e.Message
        if (e.HasProp("File") && e.File != "")
            text .= " (" e.File ":" e.Line ")"
        this.Err(text)
    }

    static Append(file, level, message) {
        stamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        line := stamp " [" level "] " message "`r`n"
        try
            FileAppend(line, file, "UTF-8")
        catch
            ; Never let logging failure cascade into a crash.
            return false
        return true
    }
}
