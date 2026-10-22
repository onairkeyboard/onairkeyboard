; All user-facing text, in Polish and English. Code refers to keys only.
; {1}, {2}... are Format() placeholders.
class Lang {
    static Current := "en"

    static Strings := Map(
        "en", Map(
            "tray.settings", "Settings",
            "tray.support", "Support OnAirKey",
            "tray.test_led", "Test LED",
            "tray.pause", "Pause",
            "tray.resume", "Resume",
            "tray.open_log", "Open log",
            "tray.about", "About",
            "tray.exit", "Exit",
            "tip.idle", "OnAirKey: idle",
            "tip.recording", "OnAirKey: recording",
            "tip.paused", "OnAirKey: paused",
            "tip.no_shortcuts", "OnAirKey: set your shortcuts in Settings",
            "log.disabled", "The diagnostic log is turned off.`nTurn it on in Settings > General.",
            "about.text", "OnAirKey {1}`n`nShows when Wispr Flow is recording, using your keyboard LED and the tray icon.`n`nFree and open source (MIT)."
        ),
        "pl", Map(
            "tray.settings", "Ustawienia",
            "tray.support", "Wesprzyj OnAirKey",
            "tray.test_led", "Test diody",
            "tray.pause", "Wstrzymaj",
            "tray.resume", "Wznów",
            "tray.open_log", "Otwórz dziennik",
            "tray.about", "O programie",
            "tray.exit", "Wyjście",
            "tip.idle", "OnAirKey: spoczynek",
            "tip.recording", "OnAirKey: nagrywanie",
            "tip.paused", "OnAirKey: wstrzymano",
            "tip.no_shortcuts", "OnAirKey: ustaw skróty w ustawieniach",
            "log.disabled", "Dziennik diagnostyczny jest wyłączony.`nWłącz go w Ustawienia > Ogólne.",
            "about.text", "OnAirKey {1}`n`nPokazuje, kiedy Wispr Flow nagrywa: diodą klawiatury i ikoną w zasobniku.`n`nDarmowy i otwartoźródłowy (MIT)."
        )
    )

    static Set(language) => Lang.Current := Lang.Strings.Has(language) ? language : "en"

    ; Missing translations fall back to English, then to the key itself.
    static T(key, args*) {
        table := Lang.Strings[Lang.Current]
        if !table.Has(key) {
            Log.Write("missing translation " Lang.Current ":" key)
            table := Lang.Strings["en"]
        }
        text := table.Has(key) ? table[key] : key
        return args.Length ? Format(text, args*) : text
    }
}

T(key, args*) => Lang.T(key, args*)
