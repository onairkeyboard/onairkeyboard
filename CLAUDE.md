# OnAirKey: instructions for Claude

Always answer the user in Polish. Code, comments and commit messages stay in English.

## What this is

Windows tray program (AutoHotkey v2) that lights a keyboard LED (via Scroll / Num / Caps Lock)
and turns the tray icon red while Wispr Flow is recording. Built for the author's SayoDevice 2x2
macro pad, to be shared with friends and later promoted (TikTok, onairkey.com).

Read before working: [PLAN.md](PLAN.md) (roadmap, brand, business decisions),
[docs/SPEC-v0.1.md](docs/SPEC-v0.1.md) (approved spec), [docs/NEXT.md](docs/NEXT.md) (current to-do).

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

## Environment (author's PC)

- AutoHotkey v2.0.30 only, Ahk2Exe 1.1.37.02a2 in `C:\Program Files\AutoHotkey\Compiler`.
- Installed EXE: `%LOCALAPPDATA%\Programs\OnAirKey\OnAirKey.exe`; settings `%APPDATA%\OnAirKey`.
- Legacy script `C:\AutoHotkey\wispr-sayo-led.ahk` is retired (its startup shortcut is in
  `C:\AutoHotkey\_wylaczone`); old v1 scripts archived in `C:\AutoHotkey\_archiwum-v1`.
- Sayo keys: ID0 `Ctrl+Shift+F16` Cancel, ID1 `F15` Paste last, ID2 `F13` Push to talk,
  ID3 `F14` Hands-free; LEDs: Indicator → Scroll Lock, red.
