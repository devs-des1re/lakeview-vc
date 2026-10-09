; ---------------------------------------------------------------------------
; Models.ahk - OCR model presets, on-demand download and integrity checks.
;
; Two presets are offered (Fast / Accurate). Each preset stores its .onnx files
; under %APPDATA%\LakeviewVC\models\<key>\ and uses a bundled rec dictionary
; copied into that folder (the engine resolves --keys relative to the models
; directory). Downloads come from the Hugging Face mirror of the PaddleOCR
; models; every file is verified against a pinned SHA-256.
; ---------------------------------------------------------------------------

class Models {
    class Preset {
        __New(key, label, description, det, cls, rec, keys, dictFile, files) {
            this.Key := key
            this.Label := label
            this.Description := description
            this.Det := det
            this.Cls := cls
            this.Rec := rec
            this.Keys := keys
            this.DictFile := dictFile
            this.Files := files
        }
    }

    static Presets := Models.InitPresets()

    static InitPresets() {
        clsName := "ch_ppocr_mobile_v2.0_cls_infer.onnx"
        cls := { Name: clsName, Sha: "e47acedf663230f8863ff1ab0e64dd2d82b838fceb5957146dab185a89d6215c",
                 Url: "/PP-OCRv1/ch_ppocr_mobile_v2.0_cls_infer.onnx" }

        fastDet := { Name: "ch_PP-OCRv3_det_infer.onnx", Sha: "3439588c030faea393a54515f51e983d8e155b19a2e8aba7891934c1cf0de526",
                     Url: "/PP-OCRv3/ch_PP-OCRv3_det_infer.onnx" }
        fastRec := { Name: "en_PP-OCRv3_rec_infer.onnx", Sha: "ef7abd8bd3629ae57ea2c28b425c1bd258a871b93fd2fe7c433946ade9b5d9ea",
                     Url: "/PP-OCRv3/en_PP-OCRv3_rec_infer.onnx" }

        accDet := { Name: "ch_PP-OCRv4_det_infer.onnx", Sha: "d2a7720d45a54257208b1e13e36a8479894cb74155a5efe29462512d42f49da9",
                    Url: "/PP-OCRv4/ch_PP-OCRv4_det_infer.onnx" }
        accRec := { Name: "ch_PP-OCRv4_rec_infer.onnx", Sha: "48fc40f24f6d2a207a2b1091d3437eb3cc3eb6b676dc3ef9c37384005483683b",
                    Url: "/PP-OCRv4/ch_PP-OCRv4_rec_infer.onnx" }

        return Map(
            "fast", Models.Preset("fast", "Fast", "Lower CPU use, English-tuned recognition.",
                fastDet, cls, fastRec, "dict_en.txt", "dict_en.txt",
                [fastDet, cls, fastRec]),
            "accurate", Models.Preset("accurate", "Accurate", "Best accuracy for usernames, Chinese PP-OCRv4 model.",
                accDet, cls, accRec, "ppocr_keys_v1.txt", "dict_chinese.txt",
                [accDet, cls, accRec])
        )
    }

    static DefaultKey := "accurate"

    static Get(key) {
        return this.Presets.Has(key) ? this.Presets[key] : this.Presets[this.DefaultKey]
    }

    static Keys() {
        out := []
        for k, _ in this.Presets
            out.Push(k)
        return out
    }

    static Dir(key) {
        return Paths.ModelsRoot "\" key
    }

    static IsInstalled(key) {
        if !this.Presets.Has(key)
            return false
        p := this.Presets[key]
        dir := this.Dir(key)
        for f in p.Files {
            file := dir "\" f.Name
            if !FileExist(file)
                return false
        }
        if !FileExist(dir "\" p.Keys)
            return false
        return true
    }

    ; Downloads and verifies a preset if needed. `progress` is called with a
    ; human-readable status string. Returns true on success, throws on failure.
    static Ensure(key, progress := "") {
        if !this.Presets.Has(key)
            throw ValueError("Unknown model preset: " key)
        p := this.Presets[key]
        dir := this.Dir(key)
        if !DirExist(dir)
            DirCreate(dir)

        total := p.Files.Length
        idx := 0
        for f in p.Files {
            idx++
            dest := dir "\" f.Name
            if (FileExist(dest) && this.Sha256(dest) = f.Sha) {
                this.Report(progress, "Verified " f.Name, idx - 1, total)
                continue
            }
            this.Report(progress, "Downloading " f.Name " (" idx "/" total ")", idx - 1, total)
            tmp := dest ".part"
            this.DownloadVerified(f, tmp, progress, f.Name, idx - 1, total)
            if FileExist(dest)
                FileDelete(dest)
            FileMove(tmp, dest)
            this.Report(progress, "Verified " f.Name, idx, total)
        }

        dictSrc := Paths.DictsDir "\" p.DictFile
        dictDest := dir "\" p.Keys
        if !FileExist(dictSrc)
            throw Error("Bundled dictionary missing: " dictSrc)
        if (p.DictFile != p.Keys || !FileExist(dictDest))
            FileCopy(dictSrc, dictDest, true)

        this.Report(progress, "Model ready.", total, total)
        return true
    }

    static Report(progress, text, done, total) {
        if (progress is Func)
            progress(text, done, total)
    }

    ; Downloads a single file into `tmp`, verifying its SHA-256. Retries a few
    ; times on network/checksum failure before giving up. Throws on final fail.
    static DownloadVerified(f, tmp, progress, name, base, total) {
        attempts := 3
        Loop attempts {
            attempt := A_Index
            try {
                if FileExist(tmp)
                    FileDelete(tmp)
                Download(Paths.ModelsBaseUrl f.Url, tmp)
                got := this.Sha256(tmp)
                if (got = f.Sha)
                    return true
                Logger.Warn("Checksum mismatch for " name " (attempt " attempt "/" attempts ").")
            } catch as e {
                Logger.Warn("Download of " name " failed (attempt " attempt "/" attempts "): " e.Message)
            }
            this.Report(progress, Format("Retrying {1} ({2}/{3})...", name, attempt, attempts), base, total)
            Sleep 750 * attempt
        }
        try {
            if FileExist(tmp)
                FileDelete(tmp)
        } catch {
        }
        throw Error("Could not download a verified copy of " name " from the model mirror.")
    }

    static Sha256(path) {
        tmp := A_Temp "\LakeviewVC_hash_" A_TickCount ".txt"
        try {
            RunWait('cmd /c certutil -hashfile "' path '" SHA256 > "' tmp '" 2>&1', , "Hide")
            out := FileExist(tmp) ? FileRead(tmp) : ""
            if RegExMatch(out, "i)\b([0-9a-f]{64})\b", &m)
                return StrLower(m[1])
        } finally {
            if FileExist(tmp)
                FileDelete(tmp)
        }
        return ""
    }

    ; Engine arguments for a preset. `--keys` is a filename relative to the
    ; preset's models directory.
    static EngineArgs(key) {
        p := this.Get(key)
        return { Models: this.Dir(p.Key), Det: p.Det.Name, Cls: p.Cls.Name, Rec: p.Rec.Name, Keys: p.Keys }
    }
}
