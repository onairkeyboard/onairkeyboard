# Changelog

All notable changes to OnAir keyboard are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [0.1.0] - unreleased

First version.

### Added
- Keyboard LED shows when Wispr Flow is recording, driven by a Lock key state (Scroll Lock by
  default, Num Lock or Caps Lock to choose).
- Tray icon turns red while recording, so OnAir keyboard works even without a keyboard LED.
  At rest it's black on a light taskbar and white on a dark one, following Windows live.
- Actions: Push to talk and Command Mode (hold), Hands-free (toggle), Cancel (reset).
- Settings window: How it works, Shortcuts, Indicator, General, Advanced and About tabs.
- Shortcut recording by pressing the keys, including F13–F24, Escape and modifier-only
  shortcuts such as Wispr's default Ctrl+Win; validation the way Wispr Flow accepts shortcuts.
- Polish and English, detected from Windows or chosen in settings.
- The version shows in the settings window title and in the name of the downloaded EXE
  (`OnAirKeyboard-0.1.0.exe`); installed, it is always `OnAirKeyboard.exe`.
- Start with Windows, pause / resume, LED test, diagnostic log.
- Reliability fixes from real use: the LED state is enforced on a timer (Wispr briefly blocks
  injected keys after dictation stops), refreshed after startup, keyboard replug and wake, and
  the keyboard hook is reinstalled after Wispr Flow starts.
- Support links (Buycoffee.to, GitHub Sponsors) and onairkeyboard.com.
- While Wispr Flow isn't running, shortcuts are ignored and the LED stays off (it turns off if
  Wispr Flow exits mid-recording); the tray tooltip and the settings header, in red, say so.
- Self-install on request: the first start asks to copy OnAir keyboard to
  `%LOCALAPPDATA%\Programs\OnAirKeyboard` with a Start menu shortcut (no administrator rights);
  a newer download offers to replace the installed copy; "No" runs it from where it is and is
  remembered (`Portable=1`).
- How it works scrolls, and tells how to keep the tray icon visible on the taskbar.
- Report a bug (settings header, tray menu, About): a window with the address hello@onairkeyboard.com,
  a subject and a ready e-mail text with technical details, and buttons to copy them into any
  mailbox (no mail app needed). It says clearly that the text is a template to complete and
  links the diagnostic log file to attach.
- Ready-made SayoDevice 2x2 setup (`presets/WisprFlow_2x2.sayobak`), linked from How it works
  and the README with restore steps.
