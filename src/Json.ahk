; Minimal JSON for the messages between the window's page and the program.
; Parse: objects -> Map, arrays -> Array, true / false -> 1 / 0, null -> "".
; Stringify: Map and plain objects -> objects, Array -> arrays, Integer / Float -> numbers,
; everything else -> strings (the page treats 1 / 0 as true / false).
class Json {
    static Parse(text) {
        pos := 1
        value := Json._Value(text, &pos)
        Json._Space(text, &pos)
        if pos <= StrLen(text)
            throw ValueError("JSON: unexpected text at " pos)
        return value
    }

    static Stringify(value) {
        if value is Map {
            out := ""
            for k, v in value
                out .= (out = "" ? "" : ",") Json._Quote(String(k)) ":" Json.Stringify(v)
            return "{" out "}"
        }
        if value is Array {
            out := ""
            for v in value
                out .= (A_Index = 1 ? "" : ",") Json.Stringify(IsSet(v) ? v : "")
            return "[" out "]"
        }
        if IsObject(value) {
            out := ""
            for k, v in value.OwnProps()
                out .= (out = "" ? "" : ",") Json._Quote(k) ":" Json.Stringify(v)
            return "{" out "}"
        }
        if value is Integer || value is Float
            return String(value)
        return Json._Quote(value)
    }

    static _Quote(s) {
        s := StrReplace(s, "\", "\\")
        s := StrReplace(s, '"', '\"')
        s := StrReplace(s, "`n", "\n")
        s := StrReplace(s, "`r", "\r")
        s := StrReplace(s, "`t", "\t")
        if RegExMatch(s, "[\x00-\x1F]") {
            out := ""
            loop parse s
                out .= Ord(A_LoopField) < 0x20 ? Format("\u{:04X}", Ord(A_LoopField)) : A_LoopField
            s := out
        }
        return '"' s '"'
    }

    static _Space(text, &pos) {
        while pos <= StrLen(text) && InStr(" `t`r`n", SubStr(text, pos, 1))
            pos++
    }

    static _Value(text, &pos) {
        Json._Space(text, &pos)
        ch := SubStr(text, pos, 1)
        switch ch {
            case "{":
                obj := Map()
                pos++
                Json._Space(text, &pos)
                if SubStr(text, pos, 1) = "}"
                    return (pos++, obj)
                loop {
                    Json._Space(text, &pos)
                    if SubStr(text, pos, 1) != '"'
                        throw ValueError("JSON: key expected at " pos)
                    key := Json._String(text, &pos)
                    Json._Space(text, &pos)
                    if SubStr(text, pos++, 1) != ":"
                        throw ValueError("JSON: colon expected at " pos - 1)
                    obj[key] := Json._Value(text, &pos)
                    Json._Space(text, &pos)
                    sep := SubStr(text, pos++, 1)
                    if sep = "}"
                        return obj
                    if sep != ","
                        throw ValueError("JSON: comma expected at " pos - 1)
                }
            case "[":
                arr := []
                pos++
                Json._Space(text, &pos)
                if SubStr(text, pos, 1) = "]"
                    return (pos++, arr)
                loop {
                    arr.Push(Json._Value(text, &pos))
                    Json._Space(text, &pos)
                    sep := SubStr(text, pos++, 1)
                    if sep = "]"
                        return arr
                    if sep != ","
                        throw ValueError("JSON: comma expected at " pos - 1)
                }
            case '"':
                return Json._String(text, &pos)
        }
        for word, value in Map("true", 1, "false", 0, "null", "") {
            if SubStr(text, pos, StrLen(word)) == word
                return (pos += StrLen(word), value)
        }
        if RegExMatch(text, "-?\d+(\.\d+)?([eE][-+]?\d+)?", &m, pos) && m.Pos = pos {
            pos += m.Len
            return m[1] = "" && m[2] = "" ? Integer(m[0]) : Float(m[0])
        }
        throw ValueError("JSON: unexpected character at " pos)
    }

    static _String(text, &pos) {
        static escapes := Map('"', '"', "\", "\", "/", "/", "b", "`b", "f", "`f", "n", "`n", "r", "`r", "t", "`t")
        pos++  ; opening quote
        out := ""
        loop {
            ch := SubStr(text, pos, 1)
            if ch = ""
                throw ValueError("JSON: unterminated string")
            pos++
            if ch = '"'
                return out
            if ch != "\" {
                out .= ch
                continue
            }
            esc := SubStr(text, pos++, 1)
            if esc = "u" {
                out .= Chr(Integer("0x" SubStr(text, pos, 4)))
                pos += 4
            } else if escapes.Has(esc) {
                out .= escapes[esc]
            } else {
                throw ValueError("JSON: bad escape at " pos - 1)
            }
        }
    }
}
