# Third-party libraries

WebView2 for AutoHotkey v2, used by the settings window (from v0.2).

- Source: [thqby/ahk2_lib](https://github.com/thqby/ahk2_lib), commit `06aed7a1c42f754dfcb67962d055311a480d0848`,
  MIT licence (`LICENSE-ahk2_lib.txt`).
- Files: `WebView2/WebView2.ahk`, `Promise.ahk`, `ComVar.ahk` (unchanged) and
  `WebView2/64bit/WebView2Loader.dll` 1.0.3595.46, Microsoft's redistributable loader
  (Authenticode signature: Microsoft Corporation, checked 2026-10-27).
- When updating: take all four files from one commit, check the DLL signature
  (`Get-AuthenticodeSignature`) and update the commit above.
