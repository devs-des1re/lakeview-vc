; ---------------------------------------------------------------------------
; Resolver.ahk - turns raw OCR text into a real Roblox username.
;
; Strategy (validate-then-search):
;   1. Clean the OCR text and build candidate usernames (space/underscore
;      variations, since OCR commonly reads "_" as a space or drops it).
;   2. Batch-validate the candidates with /v1/usernames/users.
;   3. If none match, keyword-search and match the closest display name,
;      returning that account's real username.
;
; Display names are never sent directly - only the resolved username is.
; ---------------------------------------------------------------------------

class Resolver {
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

        ; Fall back to search by display name.
        try {
            keyword := this.SearchKeyword(clean)
            results := RobloxApi.SearchUsers(keyword, 10)
        } catch as e {
            Logger.Exception(e, "SearchUsers")
            results := []
        }
        return this.PickFromSearch(clean, results)
    }

    ; Removes characters OCR commonly adds, collapsing whitespace.
    static Clean(text) {
        s := Trim(text)
        s := StrReplace(s, "`r", " ")
        s := StrReplace(s, "`n", " ")
        ; Drop anything that is not a letter, digit, underscore or space.
        s := RegExReplace(s, "[^\w ]+", " ")
        s := RegExReplace(s, " +", " ")
        return Trim(s)
    }

    ; Ordered list of username candidates to try validating.
    static Candidates(clean) {
        list := []
        this.PushUnique(list, clean)
        this.PushUnique(list, StrReplace(clean, " ", "_"))
        this.PushUnique(list, StrReplace(clean, " ", ""))
        ; Only the first word is often the username when a label is captured too.
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

        ; Prefer an exact (case-insensitive) candidate, in candidate order.
        for cand in candidates {
            key := StrLower(cand)
            if found.Has(key) {
                f := found[key]
                return { Name: f.Name, DisplayName: f.DisplayName, Id: f.Id, Method: "validated" }
            }
        }
        ; Otherwise accept a normalised match (spaces <-> underscores).
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

        ; 1. Exact display name match.
        for r in results
            if (this.Normalize(r.DisplayName) = target)
                return { Name: r.Name, DisplayName: r.DisplayName, Id: r.Id, Method: "search-display" }

        ; 2. Exact username match (search can surface these too).
        for r in results
            if (this.Normalize(r.Name) = target)
                return { Name: r.Name, DisplayName: r.DisplayName, Id: r.Id, Method: "search-name" }

        ; 3. Closest display name by prefix / containment.
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

    ; Lowercase and strip spaces/underscores for comparison.
    static Normalize(text) {
        return StrLower(StrReplace(StrReplace(text, " ", ""), "_", ""))
    }

    ; Cheap similarity: shared prefix ratio blended with length ratio.
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

    ; The search keyword: the longest alphanumeric token, fall back to full text.
    static SearchKeyword(clean) {
        best := ""
        for token in StrSplit(clean, " ")
            if (StrLen(token) > StrLen(best))
                best := token
        return best != "" ? best : clean
    }
}
