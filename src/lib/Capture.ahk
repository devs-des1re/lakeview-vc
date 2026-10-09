; ---------------------------------------------------------------------------
; Capture.ahk - captures a rectangle of the screen anchored at the mouse.
;
; The region is centred on the current mouse position and clamped to the
; virtual desktop so multi-monitor setups and screen edges are handled. The
; result is written to a PNG file and its path returned.
; ---------------------------------------------------------------------------

class Capture {
    ; PNG encoder CLSID {557CF406-1A04-11D3-9A73-0000F81EF32E}
    static PngClsid := "{557CF406-1A04-11D3-9A73-0000F81EF32E}"

    ; Region is centred on the cursor. Returns the path of the saved PNG.
    static AtMouse(width, height, savePath, scale := 1) {
        CoordMode "Mouse", "Screen"
        MouseGetPos(&mx, &my)

        bounds := this.VirtualBounds()
        if (bounds.W <= 0 || bounds.H <= 0)
            throw Error("Could not determine the screen bounds.")

        ; Never exceed the virtual desktop, and never allow empty regions.
        width := Min(Round(width), bounds.W)
        height := Min(Round(height), bounds.H)
        width := Max(width, 1)
        height := Max(height, 1)

        x := mx - (width // 2)
        y := my - (height // 2)
        x := Max(bounds.X, Min(x, bounds.X + bounds.W - width))
        y := Max(bounds.Y, Min(y, bounds.Y + bounds.H - height))

        return this.Region(x, y, width, height, savePath, scale)
    }

    ; Captures an absolute screen rectangle to a PNG file. `scale` upscales the
    ; capture (Roblox nametag text is small; upscaling sharply improves OCR).
    ; Returns the path.
    static Region(x, y, width, height, savePath, scale := 1) {
        this.GdipStartup()

        scale := Max(1, Round(scale))
        dw := width * scale
        dh := height * scale

        hScreen := DllCall("GetDC", "ptr", 0, "ptr")
        hMem := DllCall("gdi32\CreateCompatibleDC", "ptr", hScreen, "ptr")
        hBmp := DllCall("gdi32\CreateCompatibleBitmap", "ptr", hScreen, "int", dw, "int", dh, "ptr")
        old := DllCall("gdi32\SelectObject", "ptr", hMem, "ptr", hBmp, "ptr")

        ; HALFTONE gives a smooth upscale (better for OCR than nearest-neighbour).
        DllCall("gdi32\SetStretchBltMode", "ptr", hMem, "int", 4)

        ; SRCCOPY | CAPTUREBLT captures layered windows (e.g. some overlays).
        DllCall("gdi32\StretchBlt", "ptr", hMem, "int", 0, "int", 0, "int", dw, "int", dh
            , "ptr", hScreen, "int", x, "int", y, "int", width, "int", height, "uint", 0x00CC0020 | 0x40000000)

        DllCall("gdi32\SelectObject", "ptr", hMem, "ptr", old)
        DllCall("gdi32\DeleteDC", "ptr", hMem)
        DllCall("ReleaseDC", "ptr", 0, "ptr", hScreen)

        try
            this.SaveHBitmapToPng(hBmp, savePath)
        finally
            DllCall("gdi32\DeleteObject", "ptr", hBmp)

        return savePath
    }

    static SaveHBitmapToPng(hBmp, path) {
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hBmp, "ptr", 0, "ptr*", &pBitmap := 0)
        if (pBitmap = 0)
            throw Error("Failed to create GDI+ bitmap from screen capture.")

        try {
            dir := SubStr(path, 1, InStr(path, "\", , -1) - 1)
            if (dir != "" && !DirExist(dir))
                DirCreate(dir)

            clsid := Buffer(16)
            DllCall("ole32\CLSIDFromString", "wstr", this.PngClsid, "ptr", clsid)
            status := DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", path, "ptr", clsid, "ptr", 0)
            if (status != 0)
                throw Error("Failed to save capture (GDI+ status " status ").")
        } finally {
            DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
        }
    }

    static VirtualBounds() {
        return {
            X: DllCall("GetSystemMetrics", "int", 76, "int"),
            Y: DllCall("GetSystemMetrics", "int", 77, "int"),
            W: DllCall("GetSystemMetrics", "int", 78, "int"),
            H: DllCall("GetSystemMetrics", "int", 79, "int")
        }
    }

    static GdipStartup() {
        static token := 0
        if token
            return
        ; GdiplusStartupInput layout differs by pointer size.
        size := (A_PtrSize = 8) ? 24 : 16
        input := Buffer(size, 0)
        NumPut("uint", 1, input, 0)
        DllCall("gdiplus\GdiplusStartup", "ptr*", &token := 0, "ptr", input, "ptr", 0)
        if !token
            throw Error("Failed to initialise GDI+.")
    }
}
