; ---------------------------------------------------------------------------
; Resolver.ahk - turns OCR results into a real Roblox username.
;
; Every recognised text box is treated as a candidate username (plus each
; visual line, since a username can split across boxes). If any box carries an
; "@username" token it is used directly (it *is* the username). Otherwise all
; candidates are validated against the Roblox API and the one nearest the
; capture centre wins - so chat text sharing the capture does not mislead it.
; ---------------------------------------------------------------------------

class Resolver {
    ; An "@username" found anywhere in an OCR box (Roblox nametags show it below
    ; the display name). Not anchored so "Adam @Hayaante23" also matches.
    static AtPattern := "i)@([A-Za-z0-9_]{3,20})"
    static MaxNames := 100

    ; Resolves from the OCR item list. `items` elements have Text/Box/Y.
    ; Strategy: gather every candidate username from every box (and per line),
    ; then decide which is the real username - an "@username" wins outright,
    ; otherwise all candidates are validated against Roblox and the nearest
    ; real username is used. Returns { Name, DisplayName, Id, Method } or "".
    static ResolveItems(items) {
        if (items.Length = 0)
            return ""

        center := this.Center(items)

        candMap := Map()   ; lowercased name -> { Name, Dist, Box }
        atCands := []

        ; Per-box candidates.
        for it in items {
            box := this.BoxExtent(it.Box)
            if (box = "")
                continue
            d := this.DistToCenter(box, center)

            if RegExMatch(it.Text, this.AtPattern, &m)
                atCands.Push({ Name: m[1], Dist: d, Box: box })

            for cand in this.TextCandidates(it.Text)
                this.AddCandidate(candMap, cand, d, box)
        }

        ; Same-line joined candidates (a username can split across boxes).
        for line in this.LineGroups(items) {
            text := ""
            for it in line.Items
                text .= (text = "" ? "" : " ") it.Text
            d := this.DistToCenter(line.Box, center)
            for cand in this.TextCandidates(text)
                this.AddCandidate(candMap, cand, d, line.Box)
        }

        ; 1. An "@username" is the real username and is unique - use it.
        if (atCands.Length > 0) {
            best := atCands[1]
            for c in atCands
                if (c.Dist < best.Dist)
                    best := c
            return { Name: best.Name, DisplayName: "", Id: 0, Method: "nametag" }
        }

        ; 2. Validate every candidate; the nearest real username wins. This is
        ;    robust against chat text sharing the capture.
        valid := this.ValidateCandidates(candMap)
        if (valid != "")
            return valid

        ; 3. Nothing validated: search by the nearest candidate's text.
        nearest := ""
        for key, c in candMap
            if (nearest = "" || c.Dist < nearest.Dist)
                nearest := c
        if (nearest = "")
            return ""
        return this.Resolve(nearest.Name)
    }

    ; Candidate usernames from a piece of OCR text: the whole text, space ->
    ; underscore / no-space variants, and each token.
    static TextCandidates(text) {
        out := []
        clean := this.Clean(text)
        if (clean = "")
            return out
        this.AddTextCandidate(out, clean)
        this.AddTextCandidate(out, StrReplace(clean, " ", "_"))
        this.AddTextCandidate(out, StrReplace(clean, " ", ""))
        for tok in StrSplit(clean, " ")
            this.AddTextCandidate(out, tok)
        return out
    }

    static AddTextCandidate(list, value) {
        if this.IsValidUsername(value)
            this.PushUnique(list, value)
    }

    static IsValidUsername(value) {
        return (value != "" && RegExMatch(value, "i)^[A-Za-z0-9_]{3,20}$") > 0)
    }

    static AddCandidate(map, name, dist, box) {
        key := StrLower(name)
        if (!map.Has(key) || dist < map[key].Dist)
            map[key] := { Name: name, Dist: dist, Box: box }
    }

    static DistToCenter(box, center) {
        dx := Max(box.x0 - center.x, 0, center.x - box.x1)
        dy := Max(box.y0 - center.y, 0, center.y - box.y1)
        return Sqrt(dx * dx + dy * dy)
    }

    ; Groups OCR items into visual lines by vertical overlap, ordered left to
    ; right. Returns an array of { Items, Box }.
    static LineGroups(items) {
        lines := []
        for it in items {
            box := this.BoxExtent(it.Box)
            if (box = "")
                continue
            placed := false
            for line in lines {
                lb := line.Box
                overlap := Min(lb.y1, box.y1) - Max(lb.y0, box.y0)
                minH := Min(lb.y1 - lb.y0, box.y1 - box.y0)
                if (minH > 0 && overlap > 0.5 * minH) {
                    line.Items.Push(it)
                    line.Box := this.UnionBox(lb, box)
                    placed := true
                    break
                }
            }
            if !placed
                lines.Push({ Items: [it], Box: box })
        }
        ; Order items within each line left to right.
        for line in lines
            this.SortByX(line.Items)
        return lines
    }

    static UnionBox(a, b) {
        return { x0: Min(a.x0, b.x0), y0: Min(a.y0, b.y0)
               , x1: Max(a.x1, b.x1), y1: Max(a.y1, b.y1) }
    }

    static SortByX(items) {
        n := items.Length
        Loop n - 1 {
            i := A_Index
            Loop n - i {
                j := A_Index
                bj := this.BoxExtent(items[j].Box)
                bj1 := this.BoxExtent(items[j + 1].Box)
                if (bj != "" && bj1 != "" && bj.x0 > bj1.x0) {
                    tmp := items[j]
                    items[j] := items[j + 1]
                    items[j + 1] := tmp
                }
            }
        }
    }

    ; Validates all candidates with the Roblox API and returns the nearest one
    ; that is a real username, or "".
    static ValidateCandidates(candMap) {
        if (candMap.Count = 0)
            return ""

        names := []
        for key, c in candMap {
            names.Push(c.Name)
            if (names.Length >= this.MaxNames)
                break
        }

        try
            found := RobloxApi.ValidateUsernames(names)
        catch as e {
            Logger.Exception(e, "ValidateUsernames")
            return ""
        }
        if (found.Count = 0)
            return ""

        best := ""
        for key, c in candMap {
            if found.Has(key) {
                if (best = "" || c.Dist < best.Dist) {
                    f := found[key]
                    best := { Name: f.Name, DisplayName: f.DisplayName, Id: f.Id, Dist: c.Dist }
                }
            }
        }
        if (best = "")
            return ""
        return { Name: best.Name, DisplayName: best.DisplayName, Id: best.Id, Method: "validated" }
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
