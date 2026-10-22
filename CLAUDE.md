# OnAirKey: instructions for Claude

Code, comments and commit messages are in English.

## What this is

Windows tray program (AutoHotkey v2) that lights a keyboard LED (via Scroll / Num / Caps Lock)
and turns the tray icon red while Wispr Flow is recording. Built for the author's SayoDevice 2x2
macro pad, shared as free, open-source software (onairkey.com).

On the author's PC, first read the private notes in `C:\dev\2026\OnAirKey-notes` (its
`CLAUDE.md`, then `PLAN.md`, `SPEC-v0.1.md`, `NEXT.md`). They hold the author's preferences,
roadmap and current to-do. Never copy their contents into this public repository.

## Commands

```powershell
powershell -ExecutionPolicy Bypass -File tests\run.ps1        # validation + all tests
powershell -ExecutionPolicy Bypass -File build.ps1            # dist\OnAirKey.exe
powershell -ExecutionPolicy Bypass -File tests\run.ps1 -Exe   # tests incl. the compiled EXE
powershell -ExecutionPolicy Bypass -File tools\run-demo.ps1   # demo instance (temp config, Caps Lock)
powershell -ExecutionPolicy Bypass -File tools\screenshot-settings.ps1 -Language pl [-Showcase]
python -I assets\build_icons.py                               # icons/logos from assets\src (Inkscape)
```

Run the tests after every change; commit after each finished step.

## Pitfalls learned the hard way

- **AutoHotkey names are case-insensitive.** A local called `menu`, `support`, `app`, `log`,
  `indicator`, `config`... silently hides the class of that name (`Menu`, `Support`, `App`...).
  Same in tests (`S` and `s` are one variable).
- **MSIX virtualization:** this session runs inside Claude Desktop (an MSIX app). Processes started
  from here see a virtual `%APPDATA%` (`%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming`).
  Never start the real OnAirKey for everyday use from the session (the user starts it); reading
  `%APPDATA%\OnAirKey` from here may show the virtual copy instead of the real file.
- Tests must not disturb the user's setup: they use Caps Lock as the indicator and F20–F23
  shortcuts, temp configs via `--config`, and wait for log lines instead of fixed delays.
  Autostart is managed only by the EXE on the default config path.
- Ahk2Exe 1.1.37+ is required (1.1.33 from AutoHotkey v1 can't compile v2). `FileInstall` must
  start its own line or Ahk2Exe won't embed the file.
- Wispr Flow blocks injected keys right after dictation stops (hence the LED sync timer), and
  its helper process can install its keyboard hook after ours (hence the hook reinstall).
