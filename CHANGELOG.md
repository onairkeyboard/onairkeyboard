# Changelog

All notable changes to OnAir keyboard are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions: the middle number changes with new features; the last one counts builds, so a release
may skip numbers (0.2.0, then 0.3.4).

## [0.2.0] - 2026-10-27

Install it and it works: the LED follows the microphone, no shortcuts to set up.

### Added
- **Microphone as the signal source (the default).** The LED is on while a ticked app uses the
  microphone, read from the registry Windows keeps for its microphone icon. Works with any app;
  dictation apps and AI assistants (Wispr Flow, Claude, ChatGPT, Aqua Voice) are ticked by
  default, messengers and browsers aren't. The LED turns on when the app really listens (about
  0.5 s after the start) and off 0.1–0.25 s after the end.
- **Signal sources in the advanced settings:** Microphone, Keyboard shortcuts (as in 0.1) and Both
  (a shortcut turns the LED on; when Wispr Flow's microphone stays closed for 6 s, it goes off).
- **Self-protection while setting up Wispr Flow:** with the shortcut sources, an active Wispr Flow
  window puts OnAir keyboard's shortcuts on hold and leaves the Lock alone, so Wispr Flow can
  record its shortcuts.
- **New window**, built in WebView2: a simple main view (on air / off air card, keyboard LED with a
  test, apps from the microphone history as checkboxes, start with Windows) and advanced settings
  with a sidebar (signal source, Wispr Flow shortcuts, indicator, general, diagnostics, about).
  Every change applies at once, there is no Save button.
- **Light and dark ("Grafit") theme**, following the Windows app mode, also while the window is
  open.
- How it works as three step cards: SayoDevice → Wispr Flow → OnAir keyboard, and why that order.
- The tray tooltip says who is on air ("on air (Wispr Flow)").

### Changed
- **The LED no longer changes while a shortcut is held.** Pressing the Lock in the middle of
  Wispr Flow's Push to talk delayed its start from about 0.6 s to 1–5 s, or ended the recording.
  So with Push to talk only the tray icon turns red; with Hands-free the LED turns on as you
  release the key.
- Shortcut taps from a macro pad are no longer lost when OnAir keyboard is busy (for example with
  its window open): the modifiers count as they were at the key press.
- Settings from 0.1 move over by themselves: the source becomes Microphone with the default apps;
  your shortcuts are kept for the shortcut sources.
- "Record" is now "Assign"; an assigned shortcut is saved at once, or refused with the reason when
  Wispr Flow wouldn't accept it.
- Tray menu: "Open OnAir keyboard" (also a double click), Support, Test the LED, Pause, Show log,
  Website, Report a bug, About, Exit.
- Report a bug opens in the window, with the signal source among the technical details.
- README in both languages: shorter, with the setup order and a Privacy section.

### Removed
- The native settings window with tabs.

### Known limitations
- A browser is one app for Windows: a ticked browser lights the LED for any tab using the
  microphone.
- Without the Microsoft Edge WebView2 Runtime (rare on Windows 10) the window can't open;
  OnAir keyboard keeps working from the tray and links the runtime installer.

## [0.1.0] - 2026-10-26

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
