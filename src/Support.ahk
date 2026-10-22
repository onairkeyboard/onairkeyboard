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

    ; E-mail text in the current language: questions to answer, then technical details
    ; (diag, one per line) that OnAirKey fills in
    static BugBody(diag) => T("bug.body") "`n`n" T("bug.diag_title") "`n" diag
}
