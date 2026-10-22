; Donation links. Both platforms are shown in every language; the language only sets the order:
; Buycoffee.to (Polish, BLIK, amounts in PLN) first in Polish, GitHub Sponsors first in English.
class Support {
    static BuyCoffee := {Name: "Buycoffee.to", Url: "https://buycoffee.to/onairkey"}
    static Sponsors := {Name: "GitHub Sponsors", Url: "https://github.com/sponsors/onairkey"}

    static Links(language) {
        if language = "pl"
            return [Support.BuyCoffee, Support.Sponsors]
        return [Support.Sponsors, Support.BuyCoffee]
    }

    static Open(link) => Run(link.Url)

    ; Bug reports go by e-mail: friends testing OnAirKey rarely have a GitHub account.
    static BugEmail := "bug@onairkey.com"

    ; mailto: link with a subject and a template body; diag: technical details, one per line
    static BugMailto(version, diag) {
        body := T("bug.body") "`n`n" T("bug.diag_title") "`n" diag
        return Format("mailto:{1}?subject={2}&body={3}", Support.BugEmail
            , Support.UriEncode(T("bug.subject", version)), Support.UriEncode(StrReplace(body, "`n", "`r`n")))
    }

    ; Percent-encodes UTF-8 bytes; keeps only unreserved characters (RFC 3986)
    static UriEncode(text) {
        buf := Buffer(StrPut(text, "UTF-8"))
        size := StrPut(text, buf, "UTF-8") - 1
        out := ""
        loop size {
            b := NumGet(buf, A_Index - 1, "UChar")
            if (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
                || b = 0x2D || b = 0x2E || b = 0x5F || b = 0x7E
                out .= Chr(b)
            else
                out .= Format("%{:02X}", b)
        }
        return out
    }
}
