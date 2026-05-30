# Multi-Point Autoclicker

A tiny Windows desktop autoclicker. Capture multiple screen points with a hotkey, then have the app click them on a loop until you stop it. Each point can use a different mouse button (left / right / middle).

Runs as a small Tkinter window with global hotkeys, so you don't need to keep the app focused while it clicks.

> Prefer a no-install, double-click-to-run version? An AutoHotkey v2 build lives in [`ahk/`](ahk/) — see [`ahk/README.md`](ahk/README.md).

## Requirements

- Windows 10 or 11
- Python 3.10+ ([python.org](https://www.python.org/downloads/) — tick "Add Python to PATH" during install)
- One Python package: [`pynput`](https://pypi.org/project/pynput/) (installed in the step below)

## Install

Open PowerShell where you want the repo and run:

```powershell
git clone https://github.com/AlexandreTurgeon/Autoclicker.git
cd Autoclicker
py -m venv .venv
.venv\Scripts\pip install -r requirements.txt
```

That clones the repo, creates an isolated virtual environment (`.venv\`), and installs the one dependency listed in `requirements.txt` (`pynput`).

## Run

The simplest way: **double-click `start.bat`** in File Explorer. It launches the app using the virtual environment you created above.

Or from PowerShell, in the `Autoclicker` folder (the one containing `autoclicker.py`):

```powershell
.venv\Scripts\python autoclicker.py
```

To run from anywhere without `cd`, use absolute paths:

```powershell
C:\path\to\Autoclicker\.venv\Scripts\python C:\path\to\Autoclicker\autoclicker.py
```

A window appears with a big `IDLE` status and an empty point table.

Close the window to quit. Your points, interval, jitter, and hotkey bindings are saved to `autoclicker.ini` and restored on the next launch.

## How to use it

1. **Pick a mouse button** next to "Capture as:" (Left / Right / Middle). New points you capture will use this button. You can change it again before capturing the next point.
2. **Set the interval** (milliseconds between clicks). Default `50`. For testing, try `500` so you can actually see the cursor jumping around.
3. *(Optional)* **Set jitter ± (ms)** — randomizes the wait between clicks by up to ± that many milliseconds. Default `0` (uniform). Useful when a perfectly regular cadence is undesirable.
   *(Optional)* **Set position jitter ± (px)** — randomly offsets each click by up to ± that many pixels in both X and Y around the captured point. Default `0` (clicks land exactly on the point). Useful when clicking the exact same pixel every time is undesirable.
4. **Capture click points** — move your mouse to a target spot anywhere on screen (any window, any monitor) and press the capture hotkey (default **F6**). A row is added to the table with the X/Y coordinates. Repeat for as many spots as you want.
5. **Start clicking** — press the toggle hotkey (default **F8**). Status flips to `RUNNING`. The cursor will jump to each point and click it, looping forever.
6. **Stop** — press the toggle hotkey again. Status returns to `IDLE`. Stop is almost instant — it checks between every click.
7. **Quit** — close the window.

### Hotkeys (work even when the window is not focused)

| Default key | Action |
| --- | --- |
| **F6** | Capture cursor position as a new point |
| **F8** | Start / stop clicking |

Both can be rebound from the window — click **Rebind** next to either key, then press the key you want. Press **Esc** to cancel. The new binding is saved to `autoclicker.ini` and used on the next launch.

Only non-typing keys are bindable: **F1–F24**, arrow keys, **Insert / Delete / Home / End / Page Up / Page Down**, **Print Screen**, **Scroll Lock / Num Lock / Caps Lock**, and **Pause**. Letter and digit keys are rejected because the hotkey listener does not consume the key — binding to `q` would fire the action every time you type `q` in any window.

### Buttons in the window

| Button | What it does |
| --- | --- |
| Rebind (Capture) | Wait for the next key press and use it as the new capture hotkey |
| Rebind (Start/Stop) | Wait for the next key press and use it as the new toggle hotkey |
| Remove selected | Deletes the highlighted row from the table |
| Clear all | Empties the point list |
| Cycle button on selected | Changes the highlighted point's button (left → right → middle → left) |

## Config file

State is saved to `autoclicker.ini` next to the script. It is rewritten whenever you capture/remove/clear a point, change the interval, jitter, or position jitter, or rebind a hotkey.

```ini
[hotkeys]
capture = <f6>
toggle = <f8>

[timing]
interval_ms = 50
jitter_ms = 0
pos_jitter_px = 0

[identity]
window_title = Multi-Point Autoclicker

[points]
count = 2
1 = 100,200,left
2 = 300,400,right
```

- Delete the file to reset everything to defaults.
- `window_title` is INI-only (no UI control) — edit it to rename the app's window/taskbar entry.
- A missing, unreadable, or partially-corrupt INI is silently ignored; defaults are used and the file is rewritten on the next save.

## Troubleshooting

**Pressing F8 does nothing — status stays IDLE.**
Some other app is grabbing F8 (Discord push-to-talk, OBS, a game overlay). Same for F6 not adding rows. Close the conflicting app, or click **Rebind** next to the affected hotkey and press a different key (e.g. F9 or F10).

**Status says `IDLE — no points configured`.**
You haven't captured any points yet — press F6 over a target first.

**Status says RUNNING and the cursor jumps to the right spots, but the target app ignores the clicks.**
The target is running as Administrator (common for games and some installers). Windows blocks input from non-elevated processes to elevated ones. Re-launch the autoclicker from an elevated PowerShell:

1. Press Start, type "PowerShell", right-click → **Run as administrator**.
2. `cd C:\path\to\Autoclicker`
3. `.venv\Scripts\python autoclicker.py`

**Captured point clicks the wrong spot.**
You probably moved the mouse between hovering and pressing F6. Recapture — make sure the cursor is over the target *at the moment* you press F6.

**`py` is not recognized.**
Python isn't installed, or the Python launcher wasn't added to PATH. Reinstall from python.org with "Add Python to PATH" ticked, or substitute `python` for `py` in the commands above.

## Files

```
autoclicker.py     — the whole app (single file — this is the entry point)
start.bat          — double-click launcher (runs the app via .venv)
requirements.txt   — pip dependencies (just pynput)
autoclicker.ini    — persisted config (created on first save)
.gitignore         — excludes .venv/ and __pycache__/
ahk/               — alternative AutoHotkey v2 build (see ahk/README.md)
tests/             — anticheat test target (see tests/README.md)
```

## Notes

- The autoclicker moves your real cursor for each click. That's expected — it's the only way to click an arbitrary screen point on Windows without an injection driver.
- Clicks happen in **rapid sequence**, not simultaneously. Windows has one cursor, so two clicks can never truly land at the same instant. With a `0` ms interval the loop runs as fast as the OS will accept input — typically hundreds of cycles per second across a few points.

## AutoHotkey version

An alternative implementation written in AutoHotkey v2 lives under [`ahk/`](ahk/). It needs no Python, no virtual environment, and no command line — just install AutoHotkey v2 and double-click the script. See [`ahk/README.md`](ahk/README.md) for details.
