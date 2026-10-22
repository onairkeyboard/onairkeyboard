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
            "about.text", "OnAirKey {1}`n`nShows when Wispr Flow is recording, using your keyboard LED and the tray icon.`n`nFree and open source (MIT).",

            "settings.title", "OnAirKey settings",
            "tab.shortcuts", "Shortcuts",
            "tab.indicator", "Indicator",
            "tab.general", "General",
            "tab.advanced", "Advanced",
            "wispr.running", "Wispr Flow detected",
            "wispr.not_running", "Wispr Flow is not running",

            "shortcuts.hint", "Record the same shortcuts you use in Wispr Flow (Settings > Shortcuts): click Record, then press the key on your keyboard.",
            "shortcuts.escape_hint", "Avoid Escape: it also interrupts other programs. If Claude Code or ChatGPT is working, one press cancels dictation and stops the AI too. Use a dedicated key on your macro pad.",
            "action.PushToTalk", "Push to talk",
            "action.HandsFree", "Hands-free",
            "action.Cancel", "Cancel",
            "action.CommandMode", "Command Mode",
            "type.hold", "hold",
            "type.toggle", "toggle",
            "type.reset", "reset",
            "shortcut.none", "not set",
            "record.prompt", "Press a shortcut…",
            "btn.record", "Record",
            "btn.stop_record", "Cancel",

            "issue.empty_part", "Invalid format.",
            "issue.duplicate_modifier", "A modifier is repeated.",
            "issue.unknown_key", "Unknown key: {1}",
            "issue.multiple_keys", "Only one key besides Ctrl / Alt / Shift / Win is supported.",
            "issue.too_many_keys", "Wispr Flow accepts at most 3 keys.",
            "issue.duplicate", "Already used by {1}.",
            "issue.needs_modifier", "Add Ctrl, Alt, Shift or Win: Wispr Flow won't accept this key alone.",
            "issue.single_modifier", "A single modifier is not enough: add another key.",
            "issue.capslock_conflict", "Caps Lock is also the indicator. Choose another Lock on the Indicator tab.",
            "issue.escape_cancel", "Avoid Escape: it also stops other programs, such as Claude Code or ChatGPT at work.",
            "issue.ctrl_escape", "Ctrl+Escape opens the Start menu in Windows.",

            "indicator.lock_label", "Lock key that drives the keyboard LED:",
            "lock.ScrollLock", "Scroll Lock (recommended)",
            "lock.NumLock", "Num Lock",
            "lock.CapsLock", "Caps Lock",
            "indicator.caps_warning", "Caps Lock changes typing: while recording, letters come out in capitals.",
            "indicator.tray_state", "Tray icon colour shows the recording state",
            "btn.test_led", "Test LED",
            "indicator.keyboard_hint", "In your keyboard's software, set the LEDs to the same Lock (for example SayoDevice: Light > Indicator > Scroll Lock).",

            "general.language", "Language",
            "lang.auto", "Automatic ({1})",
            "lang.name.pl", "Polish",
            "lang.name.en", "English",
            "general.autostart", "Start with Windows",
            "general.autostart_dev", "Applies to the EXE version only.",
            "general.debug", "Write a diagnostic log",
            "btn.open_folder", "Open folder",

            "adv.sync", "LED sync interval (ms, 50-2000)",
            "adv.resync", "LED refresh after start (ms, 0-30000)",
            "adv.process", "Wispr Flow helper process",
            "adv.hook", "Keyboard hook reinstall delays (ms, comma-separated)",
            "adv.hint", "Change these only if something doesn't work.",
            "btn.restore", "Restore defaults",

            "support.cta", "OnAirKey is free. If it saves you time, buy me a coffee:",
            "btn.open_config", "Open config.ini",
            "btn.cancel", "Cancel",
            "btn.save", "Save",
            "save.errors", "Fix these before saving:",
            "save.invalid_number", "{1}: enter a number from {2} to {3}.",
            "save.invalid_list", "{1}: up to 5 numbers from 0 to 120000, separated by commas.",
            "save.invalid_process", "{1}: enter the process name."
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
            "about.text", "OnAirKey {1}`n`nPokazuje, kiedy Wispr Flow nagrywa: diodą klawiatury i ikoną w zasobniku.`n`nDarmowy i otwartoźródłowy (MIT).",

            "settings.title", "OnAirKey — ustawienia",
            "tab.shortcuts", "Skróty",
            "tab.indicator", "Wskaźnik",
            "tab.general", "Ogólne",
            "tab.advanced", "Zaawansowane",
            "wispr.running", "Wispr Flow wykryty",
            "wispr.not_running", "Wispr Flow nie działa",

            "shortcuts.hint", "Nagraj te same skróty, których używasz w Wispr Flow (Settings > Shortcuts): kliknij „Nagraj” i naciśnij klawisz na klawiaturze.",
            "shortcuts.escape_hint", "Unikaj Escape: przerywa też inne programy. Jeśli Claude Code czy ChatGPT właśnie pracuje, jednym naciśnięciem anulujesz nagrywanie i zatrzymasz pracę AI. Przypisz Cancel do osobnego klawisza na klawiaturze makro.",
            "action.PushToTalk", "Push to talk",
            "action.HandsFree", "Hands-free",
            "action.Cancel", "Cancel",
            "action.CommandMode", "Command Mode",
            "type.hold", "przytrzymanie",
            "type.toggle", "przełącznik",
            "type.reset", "reset",
            "shortcut.none", "nie ustawiono",
            "record.prompt", "Naciśnij skrót…",
            "btn.record", "Nagraj",
            "btn.stop_record", "Anuluj",

            "issue.empty_part", "Nieprawidłowy zapis.",
            "issue.duplicate_modifier", "Modyfikator się powtarza.",
            "issue.unknown_key", "Nieznany klawisz: {1}",
            "issue.multiple_keys", "Obsługiwany jest jeden klawisz oprócz Ctrl / Alt / Shift / Win.",
            "issue.too_many_keys", "Wispr Flow przyjmuje najwyżej 3 klawisze.",
            "issue.duplicate", "Już użyty w akcji {1}.",
            "issue.needs_modifier", "Dodaj Ctrl, Alt, Shift lub Win: Wispr Flow nie przyjmie samego klawisza.",
            "issue.single_modifier", "Sam jeden modyfikator nie wystarczy: dodaj kolejny klawisz.",
            "issue.capslock_conflict", "Caps Lock jest też wskaźnikiem. Wybierz inny Lock w zakładce Wskaźnik.",
            "issue.escape_cancel", "Unikaj Escape: przerywa też inne programy, np. pracujący Claude Code czy ChatGPT.",
            "issue.ctrl_escape", "Ctrl+Escape otwiera menu Start w Windows.",

            "indicator.lock_label", "Lock, który steruje diodą klawiatury:",
            "lock.ScrollLock", "Scroll Lock (zalecany)",
            "lock.NumLock", "Num Lock",
            "lock.CapsLock", "Caps Lock",
            "indicator.caps_warning", "Caps Lock zmienia pisanie: podczas nagrywania litery będą wielkie.",
            "indicator.tray_state", "Kolor ikony w zasobniku pokazuje stan nagrywania",
            "btn.test_led", "Test diody",
            "indicator.keyboard_hint", "W oprogramowaniu klawiatury ustaw diody na ten sam Lock (np. SayoDevice: Light > Indicator > Scroll Lock).",

            "general.language", "Język",
            "lang.auto", "Automatycznie ({1})",
            "lang.name.pl", "polski",
            "lang.name.en", "angielski",
            "general.autostart", "Uruchamiaj z Windows",
            "general.autostart_dev", "Dotyczy tylko wersji EXE.",
            "general.debug", "Zapisuj dziennik diagnostyczny",
            "btn.open_folder", "Otwórz folder",

            "adv.sync", "Synchronizacja diody (ms, 50–2000)",
            "adv.resync", "Odświeżenie diody po starcie (ms, 0–30000)",
            "adv.process", "Proces pomocniczy Wispr Flow",
            "adv.hook", "Opóźnienia ponownej instalacji hooka klawiatury (ms, po przecinku)",
            "adv.hint", "Zmieniaj tylko, jeśli coś nie działa.",
            "btn.restore", "Przywróć domyślne",

            "support.cta", "OnAirKey jest darmowy. Jeśli oszczędza Ci czas, postaw kawę:",
            "btn.open_config", "Otwórz config.ini",
            "btn.cancel", "Anuluj",
            "btn.save", "Zapisz",
            "save.errors", "Popraw przed zapisem:",
            "save.invalid_number", "{1}: wpisz liczbę od {2} do {3}.",
            "save.invalid_list", "{1}: do 5 liczb od 0 do 120000, oddzielonych przecinkami.",
            "save.invalid_process", "{1}: wpisz nazwę procesu."
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
