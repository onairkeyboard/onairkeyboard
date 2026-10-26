# OnAir keyboard: instructions for Claude

Code, comments and commit messages are in English.

## What this is

Windows tray program (AutoHotkey v2) that lights a keyboard LED (via Scroll / Num / Caps Lock)
and turns the tray icon red while Wispr Flow is recording. Built for the author's SayoDevice 2x2
macro pad, shared as free, open-source software (onairkeyboard.com).

On the author's PC, first read the private notes in `C:\dev\2026\OnAirKeyboard-notes` (its
`CLAUDE.md`, then `PLAN.md`, `SPEC-v0.1.md`, `NEXT.md`). They hold the author's preferences,
roadmap and current to-do. Never copy their contents into this public repository.

## Name and brand

- In text the name is **OnAir keyboard** (lower-case "k", as in the logo); where a space doesn't
  fit: `OnAirKeyboard` (EXE, folders, script) and `onairkeyboard` (domain, GitHub, log, e-mail).
- Brand colours from the logo: red `#E63A3A`, dark text `#2A2A2A`, light text `#FBFBFB`.
- Icons and logos come from `assets\src` (keycap in several colours, logos for light and dark
  backgrounds). The app uses the colour logo for light backgrounds. The README shows
  `logo-banner.svg` (dark-mode logo on a dark plate): theme-dependent README images follow the
  OS, not GitHub's theme setting (`<picture>` and `#gh-*-mode-only` both failed).

## Commands

```powershell
powershell -ExecutionPolicy Bypass -File tests\run.ps1        # validation + all tests
powershell -ExecutionPolicy Bypass -File build.ps1            # dist\OnAirKeyboard-<version>.exe
powershell -ExecutionPolicy Bypass -File tests\run.ps1 -Exe   # tests incl. the compiled EXE
powershell -ExecutionPolicy Bypass -File tools\run-demo.ps1   # demo instance (temp config, Caps Lock)
powershell -ExecutionPolicy Bypass -File tools\screenshot-settings.ps1 -Language pl [-Showcase]  # + Report a bug window
python -I assets\build_icons.py                               # icons/logos from assets\src (Inkscape)
```

Run the tests after every change; commit after each finished step.

## Pitfalls learned the hard way

- **AutoHotkey names are case-insensitive.** A local called `menu`, `support`, `app`, `log`,
  `indicator`, `config`... silently hides the class of that name (`Menu`, `Support`, `App`...).
  Same in tests (`S` and `s` are one variable).
- **MSIX virtualization:** this session runs inside Claude Desktop (an MSIX app). Processes started
  from here see a virtual `%APPDATA%` (`%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming`).
  Never start the real OnAir keyboard for everyday use from the session (the user starts it); reading
  `%APPDATA%\OnAirKeyboard` from here may show the virtual copy instead of the real file.
- Tests must not disturb the user's setup: they use Caps Lock as the indicator and F20–F23
  shortcuts, temp configs via `--config`, and wait for log lines instead of fixed delays.
  Autostart is managed only by the EXE on the default config path.
- Ahk2Exe 1.1.37+ is required (1.1.33 from AutoHotkey v1 can't compile v2). `FileInstall` must
  start its own line or Ahk2Exe won't embed the file.
- Wispr Flow blocks injected keys right after dictation stops (hence the LED sync timer), and
  its helper process can install its keyboard hook after ours (hence the hook reinstall).
- **Integration tests fail at random** when the author types or dictates meanwhile (Wispr then
  blocks the simulated keys) or when a demo instance runs (it also drives Caps Lock). Check for
  stray `AutoHotkey64.exe` instances and rerun before hunting a bug.
- A static method passed as a callback (`OnMessage`, a stored function) needs
  `ObjBindMethod(Class, "Name")`; a plain `Class.Name` reference misses its hidden `this`.
- AutoHotkey limits the length of one declaration: the translation tables are one `Map` per
  language (`Lang.En`, `Lang.Pl`).
- Building a window takes longer than the 15 ms after which another thread may interrupt, so
  windows are created inside `Critical` (otherwise a queued command opened a second one).
- Tab3 shows its controls in a dialog window that paints over sibling windows: a child window
  on a tab page (`ScrollPane`) must live inside that dialog, shown / hidden with the tab.
- Link controls: `&` must be written `&&`, and emoji don't render (no font fallback); read-only
  edits are grey unless given `BackgroundWhite`.
- The self-install runs only in the EXE on the default settings file. Tests use
  `--install-dir <folder>` and `--install-answer yes|no` (see `tests\TestIntegration.ahk`), so
  the real installation, Start menu and Startup folder are never touched.
