# OnAir keyboard: instructions for Claude

Code, comments and commit messages are in English.

## What this is

Windows tray program (AutoHotkey v2) that lights a keyboard LED (via Scroll / Num / Caps Lock)
and turns the tray icon red while you dictate: by default while a ticked app (Wispr Flow, Claude,
ChatGPT...) uses the microphone, optionally from the Wispr Flow shortcuts. Built for the author's
SayoDevice 2x2 macro pad, shared as free, open-source software (onairkeyboard.com). The window is
an HTML page (`ui\`) in WebView2 (`lib\`).

On the author's PC, first read the private notes in `C:\dev\2026\OnAirKeyboard-notes` (its
`CLAUDE.md`, then `PLAN.md`, `SPEC-v0.1.md`, `SPEC-v0.2.md`, `NEXT.md`). They hold the author's preferences,
roadmap and current to-do. Never copy their contents into this public repository.

## Name and brand

- In text the name is **OnAir keyboard** (lower-case "k", as in the logo); where a space doesn't
  fit: `OnAirKeyboard` (EXE, folders, script) and `onairkeyboard` (domain, GitHub, log, e-mail).
- Brand colours from the logo: red `#E63A3A`, dark text `#2A2A2A`, light text `#FBFBFB`.
- Icons and logos come from `assets\src` (keycap in several colours, logos for light and dark
  backgrounds); `build_icons.py` copies both logos to `ui\` for the window. The README picks
  the logo and the window screenshots (`docs\img\*-light.png` / `*-dark.png`, from
  `tools\screenshot-window.ahk`) with `<picture>` + `prefers-color-scheme`. In the author's
  test this follows the system theme (GitHub's default "Sync with system"), not a theme forced in
  GitHub's settings; GitHub's `themed-picture` only reacts when its `data-color-mode` is
  `light` / `dark`, never `auto`.

## Commands

```powershell
powershell -ExecutionPolicy Bypass -File tests\run.ps1        # validation + all tests
powershell -ExecutionPolicy Bypass -File build.ps1            # next patch, commit, dist\OnAirKeyboard-<version>.exe
powershell -ExecutionPolicy Bypass -File build.ps1 -Minor     # first build of a new minor (0.2.x -> 0.3.0)
powershell -ExecutionPolicy Bypass -File tests\run.ps1 -Exe   # tests incl. the compiled EXE
powershell -ExecutionPolicy Bypass -File tools\run-demo.ps1   # demo instance (temp config, Caps Lock)
AutoHotkey64.exe /ErrorStdOut tools\screenshot-window.ahk pl [folder]  # every view, light + dark
python -I assets\build_icons.py                               # icons/logos from assets\src (Inkscape)
```

Run the tests after every change; commit after each finished step.

**Versions:** every EXE gets its own number. The patch number counts builds (the author installs
and compares them), `build.ps1` raises it and commits "Build x.y.z" (it refuses uncommitted
changes); a new feature version starts with `-Minor`. Never hand over two different EXEs with one
number. A release publishes an existing build unchanged, so public versions may skip patches
(0.2.0 → 0.3.4).

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
  language (`Lang.En`, `Lang.Pl`), plus one per language for the window (`Lang.UiEn`, `Lang.UiPl`).
- Building a window takes longer than the 15 ms after which another thread may interrupt, so
  windows are created inside `Critical` (otherwise a queued command opened a second one).
- The window's WebView2 is created on open and closed with the window (about 126 MB only while
  open), always with its own data folder (`%LOCALAPPDATA%\OnAirKeyboard\WebView2`). Close it
  before the script exits (`App.Shutdown`): left to AutoHotkey's own clean-up it crashed
  (0xC000041D, 0.2-0.3.4) and Windows held the EXE ~6 s, so an update couldn't replace it. Page and
  program talk in JSON (`App.OnWindowCommand`, `ui\app.js`); changes apply at once, no Save.
  Texts reach the page from `Lang` (`ui.` keys override shared ones); TestCore checks that every
  text the page uses exists in both languages. Tests drive the page with JavaScript through a
  WM_COPYDATA command (`tests\WindowLib.ahk`), accepted only by instances on a custom config.
- The microphone source reads `HKCU\...\CapabilityAccessManager\ConsentStore\microphone` only when
  Windows signals a change (a full read costs about 10 ms). Tests use a fake key
  (`tests\FakeMic.ahk`, `--mic-key`), so the author's dictation never interferes.
- The self-install runs only in the EXE on the default settings file. Tests use
  `--install-dir <folder>` and `--install-answer yes|no` (see `tests\TestIntegration.ahk`), so
  the real installation, Start menu and Startup folder are never touched.
- Ducking (lowering other apps' sound) sets real per-app volumes. Tests and screenshots use a fake
  mixer (`--audio-file <ini>`, `FileMixer`) and must give one to every instance that turns ducking
  on, so the author's music is never touched; `tools\audio-probe.ahk` lists the real sessions
  read-only.
- `Ducker` entry points run Critical through `_Atomic`, which restores the caller's state: a fade
  step cut in half by another thread looks like a volume the user changed, and a start-up thread
  left Critical delays every timer (it moved the LED resync into a test's measurement).
