; Donation links, chosen by language: Polish platforms (BLIK) in Polish,
; GitHub Sponsors in English (international cards).
; TODO before release: replace the placeholder homepages with the author's profile URLs.
class Support {
    static IsPlaceholder := true

    static Suppi := {Name: "Suppi.pl", Url: "https://suppi.pl"}
    static BuyCoffee := {Name: "Buycoffee.to", Url: "https://buycoffee.to"}
    static Sponsors := {Name: "GitHub Sponsors", Url: "https://github.com/sponsors"}

    static Links(language) {
        if language = "pl"
            return [Support.Suppi, Support.BuyCoffee]
        return [Support.Sponsors]
    }

    static Open(link) => Run(link.Url)
}
