; ---------------------------------------------------------------------------
; Paths.ahk - central path resolution for LakeviewVC
; Resolves the bundled OCR engine and the per-user data directory under %APPDATA%.
; ---------------------------------------------------------------------------

class Paths {
    static AppDataDir := EnvGet("APPDATA") "\LakeviewVC"
    static ModelsRoot := Paths.AppDataDir "\models"
    static LogsDir    := Paths.AppDataDir "\logs"
    static CapturesDir := Paths.AppDataDir "\captures"
    static ConfigFile := Paths.AppDataDir "\config.ini"

    static EngineDir  := Paths.FindEngineDir()
    static EngineExe  := Paths.EngineDir != "" ? Paths.EngineDir "\RapidOCR-json.exe" : ""
    static DictsDir   := Paths.EngineDir != "" ? Paths.EngineDir "\dicts" : ""

    ; Hugging Face mirror of the PaddleOCR/RapidOCR model files. SHA-256 of the
    ; det/v4-rec/cls files was verified to match the official RapidOCR-json release.
    static ModelsBaseUrl := "https://huggingface.co/SWHL/RapidOCR/resolve/main"

    ; Locate engines\RapidOCR-json whether running from source (src/lib) or a
    ; compiled exe at the repository/install root.
    static FindEngineDir() {
        rels := ["\..\..\engines\RapidOCR-json", "\..\engines\RapidOCR-json", "\engines\RapidOCR-json"]
        for rel in rels {
            dir := A_ScriptDir rel
            if FileExist(dir "\RapidOCR-json.exe")
                return dir
        }
        return ""
    }

    static EnsureDataDirs() {
        for dir in [this.AppDataDir, this.ModelsRoot, this.LogsDir, this.CapturesDir] {
            if !DirExist(dir)
                DirCreate(dir)
        }
    }
}
