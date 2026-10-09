; ---------------------------------------------------------------------------
; Resolver.ahk - turns OCR results into a real Roblox username.
;
; Roblox nametags show the display name on top and "@username" below, so when
; an "@username" token is present it is used directly (it *is* the username).
; Otherwise the display name is looked up through the public Roblox API.
; ---------------------------------------------------------------------------

class Resolver {
    static UsernamePattern := "i)^@([A-Za-z0-9_]{3,20})$"
    static TokenPattern := "i)([A-Za-z0-9_]{3,20})"

    ; Resolves from the OCR item list. `items` elements have Text/Box/Y.
    ; Returns { Name, DisplayName, Id, Method } or "" when nothing is found.
    static ResolveItems(items) {
        if (items.Length = 0)
            return ""

        center := this.Center(items)
        cands := []

        for it in items {
            text := StrReplace(it.Text, " ")
            box := this.BoxExtent(it.Box)
            if (box = "")
                continue

            isAt := false
            name := ""
            if RegExMatch(text, this.UsernamePattern, &m) {
                name := m[1]
                isAt := true
            } else if RegExMatch(text, this.TokenPattern, &m) {
                name := m[1]
            } else {
                continue
            }

            dx := Max(box.x0 - center.x, 0, center.x - box.x1)
            dy := Max(box.y0 - center.y, 0, center.y - box.y1)
            cands.Push({ Name: name, IsAt: isAt, Dist: Sqrt(dx * dx + dy * dy), Box: box })
        }

        if (cands.Length = 0)
            return ""

        best := cands[1]
        for c in cands
            if (c.Dist < best.Dist)
                best := c

        ; An "@username" token is the real username - use it directly.
        if best.IsAt
            return { Name: best.Name, DisplayName: "", Id: 0, Method: "nametag" }

        ; Otherwise, prefer an @token on the same line (left/right of the label).
        h := best.Box.y1 - best.Box.y0
        for c in cands {
            if (c.IsAt
                && c.Box.x0 < best.Box.x1 && c.Box.x1 > best.Box.x0
                && Abs(c.Box.y0 - best.Box.y1) < 1.5 * h)
                return { Name: c.Name, DisplayName: best.Name, Id: 0, Method: "nametag-line" }
        }

        ; No @token: resolve the display name through the API.
        return this.Resolve(best.Name)
    }

    ; Returns { Name, DisplayName, Id, Method } or "" when nothing is found.
    static Resolve(ocrText) {
        clean := this.Clean(ocrText)
        if (clean = "")
            return ""

        candidates := this.Candidates(clean)
        if (candidates.Length > 0) {
            try {
                found := RobloxApi.ValidateUsernames(candidates)
            } catch as e {
                Logger.Exception(e, "ValidateUsernames")
                found := Map()
            }
            match := this.PickValidated(clean, candidates, found)
            if (match != "")
                return match
        }

        try {
            keyword := this.SearchKeyword(clean)
            results := RobloxApi.SearchUsers(keyword, 10)
        } catch as e {
            Logger.Exception(e, "SearchUsers")
            results := []
        }
        return this.PickFromSearch(clean, results)
    }

    static Center(items) {
        x0 := 1.0e9, y0 := 1.0e9, x1 := -1.0e9, y1 := -1.0e9
        for it in items {
            box := this.BoxExtent(it.Box)
            if (box = "")
                continue
            x0 := Min(x0, box.x0), y0 := Min(y0, box.y0)
            x1 := Max(x1, box.x1), y1 := Max(y1, box.y1)
        }
        if (x0 > x1)
            return { X: 0, Y: 0 }
        return { X: (x0 + x1) / 2, Y: (y0 + y1) / 2 }
    }

    ; Turns a box (array of [x,y] points) into {x0,y0,x1,y1} or "".
    static BoxExtent(box) {
        if !(Type(box) = "Array" && box.Length >= 1)
            return ""
        x0 := 1.0e9, y0 := 1.0e9, x1 := -1.0e9, y1 := -1.0e9
        for pt in box {
            if !(Type(pt) = "Array" && pt.Length >= 2)
                continue
            x := pt[1] + 0, y := pt[2] + 0
            x0 := Min(x0, x), y0 := Min(y0, y)
            x1 := Max(x1, x), y1 := Max(y1, y)
        }
        if (x0 > x1 || y0 > y1)
            return ""
        return { x0: x0, y0: y0, x1: x1, y1: y1 }
    }

    ; Removes characters OCR commonly adds, collapsing whitespace.
    static Clean(text) {
        s := Trim(text)
        s := StrReplace(s, "`r", " ")
        s := StrReplace(s, "`n", " ")
        s := RegExReplace(s, "[^\w ]+", " ")
        s := RegExReplace(s, " +", " ")
        return Trim(s)
    }

    static Candidates(clean) {
        list := []
        this.PushUnique(list, clean)
        this.PushUnique(list, StrReplace(clean, " ", "_"))
        this.PushUnique(list, StrReplace(clean, " ", ""))
        parts := StrSplit(clean, " ")
        if (parts.Length > 1)
            this.PushUnique(list, parts[1])
        return list
    }

    static PushUnique(list, value) {
        if (value = "")
            return
        for existing in list
            if (StrLower(existing) = StrLower(value))
                return
        list.Push(value)
    }

    static PickValidated(clean, candidates, found) {
        if (found.Count = 0)
            return ""

        for cand in candidates {
            key := StrLower(cand)
            if found.Has(key) {
                f := found[key]
                return { Name: f.Name, DisplayName: f.DisplayName, Id: f.Id, Method: "validated" }
            }
        }
        target := this.Normalize(clean)
        for key, f in found {
            if (this.Normalize(f.Name) = target)
                return { Name: f.Name, DisplayName: f.DisplayName, Id: f.Id, Method: "validated-normalised" }
        }
        return ""
    }

    static PickFromSearch(clean, results) {
        if (results.Length = 0)
            return ""

        target := this.Normalize(clean)

        for r in results
            if (this.Normalize(r.DisplayName) = target)
                return { Name: r.Name, DisplayName: r.DisplayName, Id: r.Id, Method: "search-display" }

        for r in results
            if (this.Normalize(r.Name) = target)
                return { Name: r.Name, DisplayName: r.DisplayName, Id: r.Id, Method: "search-name" }

        best := ""
        bestScore := 0
        for r in results {
            score := this.Similarity(target, this.Normalize(r.DisplayName))
            if (score > bestScore) {
                bestScore := score
                best := r
            }
        }
        if (best != "" && bestScore >= 0.75)
            return { Name: best.Name, DisplayName: best.DisplayName, Id: best.Id, Method: "search-fuzzy" }

        return ""
    }

    static Normalize(text) {
        return StrLower(StrReplace(StrReplace(text, " ", ""), "_", ""))
    }

    static Similarity(a, b) {
        if (a = "" || b = "")
            return 0
        if (a = b)
            return 1
        prefix := 0
        minLen := Min(StrLen(a), StrLen(b))
        Loop minLen {
            if (SubStr(a, A_Index, 1) != SubStr(b, A_Index, 1))
                break
            prefix++
        }
        lenRatio := Min(StrLen(a), StrLen(b)) / Max(StrLen(a), StrLen(b))
        return (prefix / Max(StrLen(a), StrLen(b))) * 0.5 + lenRatio * 0.5
    }

    static SearchKeyword(clean) {
        best := ""
        for token in StrSplit(clean, " ")
            if (StrLen(token) > StrLen(best))
                best := token
        return best != "" ? best : clean
    }
}
