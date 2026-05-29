# Multi-Point Autoclicker

A tiny Windows autoclicker. Capture multiple screen points with a hotkey, then loop-click them until you stop. Each point can use a different mouse button (left / right / middle). Optional symmetric jitter (`interval ± jitter`) so the cadence isn't perfectly periodic.

Written in AutoHotkey v2. No Python, no venv, no command line.

> This is the **alternative** build. The default implementation is the Python/Tkinter version at the repo root — see [`../README.md`](../README.md). Use this AutoHotkey version if you'd rather not install Python.

## Requirements

- Windows 10 or 11
- [AutoHotkey v2](https://www.autohotkey.com/) (one-time install). It associates `.ahk` files with the AHK runtime, so double-clicking `autoclicker.ahk` just works.

## Run

**Double-click `autoclicker.ahk`** in File Explorer. A window appears with a big `IDLE` status and an empty point table.

That's it. No terminal, no install, no compile step.

If you want it on your Desktop or pinned to Start, right-click `autoclicker.ahk` → **Create shortcut** (or Send to → Desktop).

## How to use it

1. **Pick a mouse button** next to "Capture as:" (Left / Right / Middle). New points you capture will use this button.
2. **Set the interval** (milliseconds between clicks). Default `50`. For testing, try `500` so you can see the cursor jumping.
3. **(Optional) Set jitter** in milliseconds. `0` = perfectly periodic. `20` = each delay is `interval ± 0–20 ms`, picked fresh per click.
4. **Capture click points** — move your mouse to a target spot on any screen and press **F6**. A row is added with the X/Y and button. Repeat for as many points as you want.
5. **Start** — press **F8**. Status flips to `RUNNING`. Cursor visits each point in order, looping forever.
6. **Stop** — press **F8** again. Status returns to `IDLE`. Stops between clicks, so it's near-instant.
7. **Quit** — close the window.

### Hotkeys (work even when the window is not focused)

| Key    | Action                                 |
| ------ | -------------------------------------- |
| **F6** | Capture cursor position as a new point |
| **F8** | Start / stop clicking                  |

Both are rebindable in the GUI — click **Rebind** next to either label and press the new key.

### Buttons in the window

| Button                   | What it does                                                          |
| ------------------------ | --------------------------------------------------------------------- |
| Remove selected          | Deletes the highlighted row from the table                            |
| Clear all                | Empties the point list                                                |
| Cycle button on selected | Changes the highlighted point's button (Left → Right → Middle → Left) |
| Exit                     | Quits the app (closing the window only hides it to the tray)          |

## Tray icon and auto-start

Closing the window **hides the app to the system tray** rather than quitting. The tray icon's right-click menu has:

- **Show** — restore the window (single-click on the icon does the same)
- **Start/Stop clicking** — same as the F8 hotkey
- **Start with Windows** — toggle on to register the app under `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`. It will launch with `--minimized` on next sign-in (tray icon only, no window).
- **Exit** — actually quit the process

The **Start with Windows** checkbox in the main window stays in sync with the tray item. Per-user only — no admin elevation required, nothing written to HKLM.

## Hotkey cooperation

If another app (or another AutoHotkey script) is grabbing the same key, two knobs under the action buttons can help:

- **Input level** (0–100): hotkeys at a higher input level intercept synthetic input from hotkeys at lower levels. Bump this above the other script's level to win the race. Leave at `0` for ordinary use.
- **Use keyboard hook (`$`)**: prefixes the hotkey with `$`, forcing AHK to use the low-level keyboard hook. Necessary if the same key is also used as the Send-target from another script. On by default.

Changes apply immediately; both are persisted in `autoclicker.ini`.

## Window title and renaming the executable

The window title defaults to `Multi-Point Autoclicker` and is stored under `[identity] window_title=` in `autoclicker.ini`. Change it there to rename the window.

The interpreter process is `AutoHotkey64.exe` — that name is fixed by the AHK runtime. If you want a custom process name, compile the script to an `.exe` with **Ahk2Exe** (ships with AutoHotkey) and rename the result freely.

## Troubleshooting

**Pressing F8 does nothing — status stays IDLE.**
Some other app is grabbing F8 (Discord push-to-talk, OBS, a game overlay). Same for F6 not adding rows. Options: rebind to a different key with the **Rebind** button, raise **Input level**, or close the conflicting app.

**Status says `IDLE — no points configured`.**
You haven't captured any points yet — press F6 over a target first.

**Status says RUNNING and the cursor jumps to the right spots, but the target app ignores the clicks.**
The target is running as Administrator (common for games and some installers). Windows blocks input from non-elevated processes to elevated ones. Right-click `autoclicker.ahk` → **Run as administrator**.

**Captured point clicks the wrong spot.**
You probably moved the mouse between hovering and pressing F6. Recapture — make sure the cursor is over the target *at the moment* you press F6.

## Files

```
autoclicker.ahk    — the whole app (AutoHotkey v2 source — also the entry point)
autoclicker.ini    — auto-generated config (point list, hotkeys, settings)
../                — repo root: the default Python/Tkinter version
../tests/          — anticheat test target (see ../tests/README.md)
```

## Notes

- The autoclicker moves your real cursor for each click. That's expected — it's the only way to click an arbitrary screen point on Windows without a kernel input driver.
- Clicks happen in **rapid sequence**, not simultaneously. Windows has one cursor.
- Idle CPU is effectively 0% — the app sits in the OS message loop until F6 or F8 fires, and the click cadence is driven by a one-shot OS timer rather than a polling thread.
- All state (point list, hotkeys, interval, jitter, advanced settings) is persisted to `autoclicker.ini` next to the script and restored on launch.

## Python version (default)

The default implementation is the Python/Tkinter version at the repo root. See [`../README.md`](../README.md) for its install/run instructions.
