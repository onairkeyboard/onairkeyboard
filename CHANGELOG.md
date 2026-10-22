# Changelog

All notable changes to OnAirKey are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [0.1.0] - unreleased

First version.

### Added
- Keyboard LED shows when Wispr Flow is recording, driven by a Lock key state (Scroll Lock by
  default, Num Lock or Caps Lock to choose).
- Tray icon turns red while recording, so OnAirKey works even without a keyboard LED.
- Actions: Push to talk and Command Mode (hold), Hands-free (toggle), Cancel (reset).
- Settings window: How it works, Shortcuts, Indicator, General, Advanced and About tabs.
- Shortcut recording by pressing the keys, including F13–F24, Escape and modifier-only
  shortcuts such as Wispr's default Ctrl+Win; validation the way Wispr Flow accepts shortcuts.
- Polish and English, detected from Windows or chosen in settings.
- Start with Windows, pause / resume, LED test, diagnostic log.
- Reliability fixes from real use: the LED state is enforced on a timer (Wispr briefly blocks
  injected keys after dictation stops), refreshed after startup, keyboard replug and wake, and
  the keyboard hook is reinstalled after Wispr Flow starts.
- Support links (Buycoffee.to, GitHub Sponsors) and onairkey.com.
- Ready-made SayoDevice 2x2 setup (`presets/WisprFlow_2x2.sayobak`), linked from How it works
  and the README with restore steps.
