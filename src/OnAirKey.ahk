#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

#Include %A_LineFile%\..\Log.ahk
#Include %A_LineFile%\..\Config.ahk
#Include %A_LineFile%\..\State.ahk
#Include %A_LineFile%\..\Indicator.ahk
#Include %A_LineFile%\..\WisprWatch.ahk
#Include %A_LineFile%\..\Shortcut.ahk
#Include %A_LineFile%\..\ModSession.ahk
#Include %A_LineFile%\..\Hotkeys.ahk

APP_NAME := "OnAirKey"
APP_VERSION := "0.1.0"

; A held key auto-repeats, which would trip the default hotkey rate limit
A_MaxHotkeysPerInterval := 500

; --config <path> overrides the settings file (used for testing)
configPath := Config.DefaultPath()
for i, arg in A_Args
    if arg = "--config" && i < A_Args.Length
        configPath := A_Args[i + 1]

cfg := Config.Load(configPath)
SplitPath(cfg.Path, , &dataDir)
Log.Init(dataDir "\onairkey.log", cfg.Debug)
Log.Write(APP_NAME " " APP_VERSION " started, config " cfg.Path (cfg.IsFirstRun ? " (created)" : ""))
for warning in cfg.Warnings
    Log.Write(warning)

state := RecState()
led := Indicator(cfg.Lock, () => state.IsRecording)
state.OnChange := OnRecordingChange
led.Start(cfg.SyncIntervalMs, cfg.ResyncDelayMs)

OnMessage(0x0219, (*) => led.ScheduleResync(1000))  ; WM_DEVICECHANGE
OnMessage(0x0218, (*) => led.ScheduleResync(1000))  ; WM_POWERBROADCAST

hotkeys := HotkeyEngine(state)
hotkeys.Register(Shortcut.ValidShortcuts(cfg.Shortcuts, cfg.Lock, &issues))
for issue in issues
    Log.Write(Format("shortcut {1} for {2}: {3} {4}", issue.Level, issue.Action, issue.Code, issue.Detail))

wispr := WisprWatch(cfg.WisprHelperProcess, cfg.HookReinstallDelaysMs)
wispr.Start()

OnExit(OnAppExit)

OnRecordingChange(recording) {
    Log.Write("recording " (recording ? "on" : "off"))
    led.Sync()
}

OnAppExit(*) {
    hotkeys.Unregister()
    wispr.Stop()
    led.Stop()
    Log.Write(APP_NAME " stopped")
}
