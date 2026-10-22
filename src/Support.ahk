; Donation links. Order depends on the language: Polish platforms (BLIK) first in Polish,
; GitHub Sponsors first in English.
; TODO before release: replace the placeholder homepages with the author's profile URLs.
class Support {
    static IsPlaceholder := true

    static Suppi := {Name: "Suppi.pl", Url: "https://suppi.pl"}
    static BuyCoffee := {Name: "Buycoffee.to", Url: "https://buycoffee.to"}
    static Sponsors := {Name: "GitHub Sponsors", Url: "https://github.com/sponsors"}

    static Links(language) {
        if language = "pl"
            return [Support.Suppi, Support.BuyCoffee, Support.Sponsors]
        return [Support.Sponsors, Support.Suppi, Support.BuyCoffee]
    }

    static Open(link) => Run(link.Url)
}
