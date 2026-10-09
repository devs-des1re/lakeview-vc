; ---------------------------------------------------------------------------
; RobloxApi.ahk - minimal client for the public Roblox user APIs.
;
;   POST /v1/usernames/users  -> validate a list of usernames, returns {name,...}
;   GET  /v1/users/search     -> keyword search, returns {name, displayName,...}
;
; Usernames are always preferred; display names are only used to find a
; candidate that is then reported by its real username (`name`).
; ---------------------------------------------------------------------------

class RobloxApi {
    static UserAgent := "LakeviewVC/0.1 (+https://github.com/)"

    ; Returns a Map keyed by the lower-cased requested username -> {id, name, displayName}
    ; for those that exist. Throws on network failure.
    static ValidateUsernames(usernames) {
        if (usernames.Length = 0)
            return Map()

        body := '{"usernames":[' this.ToJsonArray(usernames) '],"excludeBannedUsers":false}'
        res := this.Request("POST", "https://users.roblox.com/v1/usernames/users", body)

        out := Map()
        try {
            data := JSON.parse(res)
        } catch as e {
            throw Error("Failed to parse username response: " e.Message)
        }
        if Type(data) = "Map" && data.Has("data")
            data := data["data"]
        for item in data {
            name := item.Has("name") ? item["name"] : ""
            if (name = "")
                continue
            out[StrLower(name)] := {
                Id: item.Has("id") ? item["id"] : 0,
                Name: name,
                DisplayName: item.Has("displayName") ? item["displayName"] : name
            }
        }
        return out
    }

    ; Returns an array of {id, name, displayName} for a keyword search.
    static SearchUsers(keyword, limit := 10) {
        url := "https://users.roblox.com/v1/users/search?keyword=" this.UrlEncode(keyword) "&limit=" limit
        res := this.Request("GET", url)

        try {
            data := JSON.parse(res)
        } catch as e {
            throw Error("Failed to parse search response: " e.Message)
        }
        if !(Type(data) = "Map" && data.Has("data"))
            return []

        out := []
        for item in data["data"]
            out.Push({
                Id: item.Has("id") ? item["id"] : 0,
                Name: item.Has("name") ? item["name"] : "",
                DisplayName: item.Has("displayName") ? item["displayName"] : ""
            })
        return out
    }

    static Request(method, url, body := "") {
        try {
            req := ComObject("WinHttp.WinHttpRequest.5.1")
            req.Open(method, url, false)
            req.SetRequestHeader("User-Agent", this.UserAgent)
            req.SetRequestHeader("Accept", "application/json")
            if (method = "POST")
                req.SetRequestHeader("Content-Type", "application/json")
            req.Send(body)

            status := req.Status
            if (status < 200 || status >= 300)
                throw Error("HTTP " status " from " url)

            return req.ResponseText
        } catch as e {
            throw Error("Roblox API request failed: " e.Message)
        }
    }

    static ToJsonArray(items) {
        parts := []
        for item in items
            parts.Push('"' this.Escape(item) '"')
        return this.Join(parts, ",")
    }

    static Escape(s) {
        s := StrReplace(s, "\", "\\")
        s := StrReplace(s, '"', '\"')
        return s
    }

    static Join(parts, sep) {
        out := ""
        for i, p in parts
            out .= (i > 1 ? sep : "") p
        return out
    }

    static UrlEncode(text) {
        out := ""
        for code in StrSplit(text) {
            n := Ord(code)
            if (n >= 0x30 && n <= 0x39) || (n >= 0x41 && n <= 0x5A)
            || (n >= 0x61 && n <= 0x7A) || n = 0x2D || n = 0x2E || n = 0x5F || n = 0x7E
                out .= code
            else
                out .= Format("%{:02X}", n)
        }
        return out
    }
}
