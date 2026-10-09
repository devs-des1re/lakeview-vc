; ---------------------------------------------------------------------------
; Ocr.ahk - runs the bundled RapidOCR-json engine on an image and returns text.
;
; The engine prints a single JSON object. Recognised codes:
;   100 - text found (data is an array of {box, score, text})
;   101 - no text found
;   2xx - file/clipboard errors, 299/300 - internal errors
; ---------------------------------------------------------------------------

class Ocr {
    ; Runs OCR on `imagePath` using `modelKey`. Returns an array of result
    ; objects { Text, Score, Box } ordered by their vertical position.
    ; Throws on engine errors.
    static Recognize(imagePath, modelKey) {
        if (Paths.EngineExe = "" || !FileExist(Paths.EngineExe))
            throw Error("OCR engine not found. Expected under engines\RapidOCR-json.")
        if !FileExist(imagePath)
            throw Error("Image not found: " imagePath)

        if !Models.IsInstalled(modelKey)
            Models.Ensure(modelKey)

        a := Models.EngineArgs(modelKey)
        args := '--models="' a.Models '" --det=' a.Det ' --cls=' a.Cls ' --rec=' a.Rec
        args .= ' --keys=' a.Keys ' --image="' imagePath '"'

        out := this.RunEngine(args)
        json := this.ExtractJson(out)
        if (json = "")
            throw Error("OCR engine returned no result. Output: " this.Trim(out))

        try
            res := JSON.parse(json)
        catch as e
            throw Error("Failed to parse OCR output: " e.Message)

        code := res.Has("code") ? res["code"] : -1
        if (code = 101)
            return []

        if (code != 100) {
            msg := res.Has("data") ? res["data"] : "unknown error"
            throw Error("OCR engine error (code " code "): " msg)
        }

        items := []
        data := res.Has("data") ? res["data"] : []
        for item in data {
            text := item.Has("text") ? item["text"] : ""
            if (text = "")
                continue
            items.Push({
                Text: text,
                Score: item.Has("score") ? item["score"] : 0,
                Box: item.Has("box") ? item["box"] : [],
                Y: this.BoxTop(item)
            })
        }
        this.SortByY(items)
        return items
    }

    ; Convenience helper: returns the combined recognised text, top-to-bottom,
    ; joined by spaces (multi-line usernames and stray boxes are handled later
    ; by the resolver).
    static RecognizeText(imagePath, modelKey) {
        items := this.Recognize(imagePath, modelKey)
        parts := []
        for it in items
            parts.Push(it.Text)
        return this.Join(parts, " ")
    }

    static BoxTop(item) {
        box := item.Box
        if (Type(box) = "Array" && box.Length >= 1 && Type(box[1]) = "Array" && box[1].Length >= 2)
            return box[1][2]
        return 0
    }

    static SortByY(items) {
        n := items.Length
        Loop n - 1 {
            i := A_Index
            Loop n - i {
                j := A_Index
                if (items[j].Y > items[j + 1].Y) {
                    tmp := items[j]
                    items[j] := items[j + 1]
                    items[j + 1] := tmp
                }
            }
        }
    }

    static Join(parts, sep) {
        out := ""
        for i, p in parts {
            out .= (i > 1 ? sep : "") p
        }
        return out
    }

    ; The engine prints a banner line ("OCR init completed.") before the JSON.
    static ExtractJson(output) {
        if RegExMatch(output, "s)\{.*\}", &m)
            return m[0]
        return ""
    }

    ; Runs the engine with redirect of stdout to a temp file (RunWait's fourth
    ; parameter is the PID, not captured output) and returns the file contents.
    static RunEngine(args) {
        if !FileExist(Paths.EngineExe)
            throw Error("OCR engine not found: " Paths.EngineExe)

        tmp := A_Temp "\LakeviewVC_ocr_" A_TickCount "_" Random(1000, 9999) ".txt"
        ; Quote the whole command so paths with spaces still resolve.
        cmd := 'cmd /c ""' Paths.EngineExe '" ' args ' > "' tmp '" 2>&1"'
        try {
            RunWait(cmd, , "Hide")
            if !FileExist(tmp)
                throw Error("OCR engine produced no output (it may have crashed).")
            return FileRead(tmp, "UTF-8")
        } finally {
            try {
                if FileExist(tmp)
                    FileDelete(tmp)
            } catch {
                ; Temp cleanup is best-effort.
            }
        }
    }

    static Trim(s) {
        return Trim(StrReplace(StrReplace(s, "`r", " "), "`n", " "))
    }
}
