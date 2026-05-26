import configparser
import pathlib
import random
import threading
import time
import tkinter as tk
from tkinter import ttk

from pynput import keyboard, mouse

BUTTONS = ("left", "right", "middle")
BUTTON_OBJ = {
    "left": mouse.Button.left,
    "right": mouse.Button.right,
    "middle": mouse.Button.middle,
}
DEFAULT_INTERVAL_MS = 50
DEFAULT_JITTER_MS = 0
DEFAULT_CAPTURE_HOTKEY = "<f6>"
DEFAULT_TOGGLE_HOTKEY = "<f8>"
DEFAULT_WINDOW_TITLE = "Multi-Point Autoclicker"

CONFIG_FILE = pathlib.Path(__file__).with_name("autoclicker.ini")

MODIFIER_KEYS = {
    keyboard.Key.ctrl, keyboard.Key.ctrl_l, keyboard.Key.ctrl_r,
    keyboard.Key.alt, keyboard.Key.alt_l, keyboard.Key.alt_r, keyboard.Key.alt_gr,
    keyboard.Key.shift, keyboard.Key.shift_l, keyboard.Key.shift_r,
    keyboard.Key.cmd, keyboard.Key.cmd_l, keyboard.Key.cmd_r,
}


def key_to_hotkey(key) -> str | None:
    """Convert a pynput key event to a GlobalHotKeys notation string, or None if unbindable."""
    if key in MODIFIER_KEYS:
        return None
    if isinstance(key, keyboard.Key):
        # Named special keys: pynput uses lowercased names matching GlobalHotKeys notation.
        return f"<{key.name}>"
    if isinstance(key, keyboard.KeyCode):
        char = key.char
        if not char:
            return None
        # GlobalHotKeys expects bare lowercase chars for printable keys.
        return char.lower()
    return None


class App:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.geometry("520x460")

        self.points: list[dict] = []
        self.points_lock = threading.Lock()
        self.running = threading.Event()
        self.stop_app = threading.Event()
        self.mouse = mouse.Controller()
        self.default_button = tk.StringVar(value="left")
        self.interval_var = tk.StringVar(value=str(DEFAULT_INTERVAL_MS))
        self.jitter_var = tk.StringVar(value=str(DEFAULT_JITTER_MS))
        self.status_var = tk.StringVar(value="IDLE")
        self.capture_hotkey = DEFAULT_CAPTURE_HOTKEY
        self.toggle_hotkey = DEFAULT_TOGGLE_HOTKEY
        self.capture_label_var = tk.StringVar(value=self.capture_hotkey)
        self.toggle_label_var = tk.StringVar(value=self.toggle_hotkey)
        self.window_title = DEFAULT_WINDOW_TITLE
        self.hotkeys: keyboard.GlobalHotKeys | None = None
        self._rebind_listener: keyboard.Listener | None = None
        self._loading_config = False

        self._build_ui()

        self._loading_config = True
        self._load_config()
        self._loading_config = False

        self.root.title(self.window_title)
        self._refresh_tree()
        self._update_hotkey_labels()

        # Wire change-tracking AFTER initial load so trace_add doesn't fire during load.
        self.interval_var.trace_add("write", lambda *_: self._on_timing_change())
        self.jitter_var.trace_add("write", lambda *_: self._on_timing_change())

        self.clicker_thread = threading.Thread(target=self._clicker_loop, daemon=True)
        self.clicker_thread.start()

        self._apply_hotkeys()

        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

    def _build_ui(self):
        pad = {"padx": 8, "pady": 4}

        top = ttk.Frame(self.root)
        top.pack(fill="x", **pad)
        ttk.Label(top, textvariable=self.status_var, font=("Segoe UI", 14, "bold")).pack(side="left")

        hk = ttk.Frame(self.root)
        hk.pack(fill="x", **pad)
        ttk.Label(hk, text="Capture:").pack(side="left")
        ttk.Label(hk, textvariable=self.capture_label_var, width=10, relief="solid", anchor="center").pack(side="left", padx=4)
        ttk.Button(hk, text="Rebind", width=8, command=lambda: self._rebind("capture")).pack(side="left", padx=(0, 12))
        ttk.Label(hk, text="Start/Stop:").pack(side="left")
        ttk.Label(hk, textvariable=self.toggle_label_var, width=10, relief="solid", anchor="center").pack(side="left", padx=4)
        ttk.Button(hk, text="Rebind", width=8, command=lambda: self._rebind("toggle")).pack(side="left")

        cfg = ttk.Frame(self.root)
        cfg.pack(fill="x", **pad)
        ttk.Label(cfg, text="Interval (ms):").pack(side="left")
        ttk.Entry(cfg, textvariable=self.interval_var, width=8).pack(side="left", padx=(4, 12))
        ttk.Label(cfg, text="Jitter ± (ms):").pack(side="left")
        ttk.Entry(cfg, textvariable=self.jitter_var, width=8).pack(side="left", padx=(4, 12))
        ttk.Label(cfg, text="Capture as:").pack(side="left")
        for b in BUTTONS:
            ttk.Radiobutton(cfg, text=b, value=b, variable=self.default_button).pack(side="left")

        cols = ("idx", "x", "y", "button")
        self.tree = ttk.Treeview(self.root, columns=cols, show="headings", height=10)
        for c, w in zip(cols, (40, 80, 80, 80)):
            self.tree.heading(c, text=c.upper())
            self.tree.column(c, width=w, anchor="center")
        self.tree.pack(fill="both", expand=True, **pad)

        btns = ttk.Frame(self.root)
        btns.pack(fill="x", **pad)
        ttk.Button(btns, text="Remove selected", command=self._remove_selected).pack(side="left")
        ttk.Button(btns, text="Clear all", command=self._clear_all).pack(side="left", padx=4)
        ttk.Button(btns, text="Cycle button on selected", command=self._cycle_button).pack(side="left", padx=4)

    def _refresh_tree(self):
        self.tree.delete(*self.tree.get_children())
        with self.points_lock:
            snapshot = list(self.points)
        for i, p in enumerate(snapshot, 1):
            self.tree.insert("", "end", iid=str(i - 1), values=(i, p["x"], p["y"], p["button"]))

    def _remove_selected(self):
        sel = self.tree.selection()
        if not sel:
            return
        idx = int(sel[0])
        with self.points_lock:
            if 0 <= idx < len(self.points):
                self.points.pop(idx)
        self._refresh_tree()
        self._save_config()

    def _clear_all(self):
        with self.points_lock:
            self.points.clear()
        self._refresh_tree()
        self._save_config()

    def _cycle_button(self):
        sel = self.tree.selection()
        if not sel:
            return
        idx = int(sel[0])
        with self.points_lock:
            if 0 <= idx < len(self.points):
                cur = self.points[idx]["button"]
                nxt = BUTTONS[(BUTTONS.index(cur) + 1) % len(BUTTONS)]
                self.points[idx]["button"] = nxt
        self._refresh_tree()
        self._save_config()

    def _on_capture_hotkey(self):
        x, y = self.mouse.position
        btn = self.default_button.get()
        with self.points_lock:
            self.points.append({"x": int(x), "y": int(y), "button": btn})
        self.root.after(0, self._refresh_tree)
        self._save_config()

    def _on_toggle_hotkey(self):
        if self.running.is_set():
            self.running.clear()
            self.root.after(0, lambda: self.status_var.set("IDLE"))
            return
        with self.points_lock:
            has_points = bool(self.points)
        if not has_points:
            self.root.after(0, lambda: self.status_var.set("IDLE — no points configured"))
            return
        self.running.set()
        self.root.after(0, lambda: self.status_var.set("RUNNING"))

    def _on_timing_change(self):
        if self._loading_config:
            return
        # Only persist when both values parse as non-negative ints.
        try:
            iv = int(self.interval_var.get())
            jv = int(self.jitter_var.get())
        except (ValueError, TypeError):
            return
        if iv < 0 or jv < 0:
            return
        self._save_config()

    def _read_interval_seconds(self) -> float:
        try:
            v = int(self.interval_var.get())
            if v < 0:
                v = 0
        except (ValueError, TypeError):
            v = DEFAULT_INTERVAL_MS
        return v / 1000.0

    def _read_jitter_seconds(self) -> float:
        try:
            v = int(self.jitter_var.get())
            if v < 0:
                v = 0
        except (ValueError, TypeError):
            v = DEFAULT_JITTER_MS
        return v / 1000.0

    def _clicker_loop(self):
        while not self.stop_app.is_set():
            if not self.running.wait(timeout=0.1):
                continue
            with self.points_lock:
                cycle = list(self.points)
            if not cycle:
                self.running.clear()
                continue
            base = self._read_interval_seconds()
            jitter = self._read_jitter_seconds()
            for p in cycle:
                if not self.running.is_set() or self.stop_app.is_set():
                    break
                try:
                    self.mouse.position = (p["x"], p["y"])
                    self.mouse.click(BUTTON_OBJ[p["button"]], 1)
                except Exception:
                    pass
                delay = base
                if jitter > 0:
                    delay = max(0.0, base + random.uniform(-jitter, jitter))
                if delay:
                    end = time.monotonic() + delay
                    while time.monotonic() < end:
                        if not self.running.is_set() or self.stop_app.is_set():
                            break
                        time.sleep(min(0.01, end - time.monotonic()))

    # --- Hotkey management ---------------------------------------------------

    def _apply_hotkeys(self):
        if self.hotkeys is not None:
            try:
                self.hotkeys.stop()
            except Exception:
                pass
            self.hotkeys = None
        try:
            self.hotkeys = keyboard.GlobalHotKeys({
                self.capture_hotkey: self._on_capture_hotkey,
                self.toggle_hotkey: self._on_toggle_hotkey,
            })
            self.hotkeys.start()
            return True
        except Exception as e:
            self.status_var.set(f"IDLE — hotkey registration failed: {e}")
            return False

    def _update_hotkey_labels(self):
        self.capture_label_var.set(self.capture_hotkey)
        self.toggle_label_var.set(self.toggle_hotkey)

    def _rebind(self, which: str):
        if self._rebind_listener is not None:
            return  # already waiting for a key
        if self.hotkeys is not None:
            try:
                self.hotkeys.stop()
            except Exception:
                pass
            self.hotkeys = None
        self.status_var.set(f"Press a key for {which}… (Esc to cancel)")

        def on_press(key):
            self.root.after(0, lambda: self._handle_rebind_key(which, key))
            return False  # stop the listener

        self._rebind_listener = keyboard.Listener(on_press=on_press)
        self._rebind_listener.start()

    def _handle_rebind_key(self, which: str, key):
        self._rebind_listener = None
        if key == keyboard.Key.esc:
            self.status_var.set("IDLE")
            self._apply_hotkeys()
            return
        notation = key_to_hotkey(key)
        if notation is None:
            self.status_var.set("IDLE — that key can't be bound, try another")
            self._apply_hotkeys()
            return
        other = self.toggle_hotkey if which == "capture" else self.capture_hotkey
        if notation == other:
            self.status_var.set(f"IDLE — {notation} already bound to other action")
            self._apply_hotkeys()
            return
        prev_capture, prev_toggle = self.capture_hotkey, self.toggle_hotkey
        if which == "capture":
            self.capture_hotkey = notation
        else:
            self.toggle_hotkey = notation
        if not self._apply_hotkeys():
            # Roll back on failure.
            self.capture_hotkey, self.toggle_hotkey = prev_capture, prev_toggle
            self._apply_hotkeys()
            self._update_hotkey_labels()
            return
        self._update_hotkey_labels()
        self.status_var.set("IDLE")
        self._save_config()

    # --- Config persistence --------------------------------------------------

    def _load_config(self):
        if not CONFIG_FILE.exists():
            return
        cp = configparser.ConfigParser(interpolation=None)
        try:
            cp.read(CONFIG_FILE, encoding="utf-8")
        except (configparser.Error, OSError):
            return

        cap = cp.get("hotkeys", "capture", fallback=DEFAULT_CAPTURE_HOTKEY).strip()
        tog = cp.get("hotkeys", "toggle", fallback=DEFAULT_TOGGLE_HOTKEY).strip()
        if cap:
            self.capture_hotkey = cap
        if tog:
            self.toggle_hotkey = tog

        iv = cp.get("timing", "interval_ms", fallback=str(DEFAULT_INTERVAL_MS)).strip()
        jv = cp.get("timing", "jitter_ms", fallback=str(DEFAULT_JITTER_MS)).strip()
        if iv.isdigit():
            self.interval_var.set(iv)
        if jv.isdigit():
            self.jitter_var.set(jv)

        title = cp.get("identity", "window_title", fallback=DEFAULT_WINDOW_TITLE).strip()
        if title:
            self.window_title = title

        count_raw = cp.get("points", "count", fallback="0").strip()
        try:
            count = int(count_raw)
        except ValueError:
            count = 0
        loaded: list[dict] = []
        for i in range(1, count + 1):
            raw = cp.get("points", str(i), fallback="").strip()
            if not raw:
                continue
            parts = [p.strip() for p in raw.split(",")]
            if len(parts) < 3:
                continue
            x_s, y_s, btn = parts[0], parts[1], parts[2].lower()
            try:
                x, y = int(x_s), int(y_s)
            except ValueError:
                continue
            if btn not in BUTTONS:
                btn = "left"
            loaded.append({"x": x, "y": y, "button": btn})
        with self.points_lock:
            self.points = loaded

    def _save_config(self):
        if self._loading_config:
            return
        cp = configparser.ConfigParser(interpolation=None)
        cp["hotkeys"] = {
            "capture": self.capture_hotkey,
            "toggle": self.toggle_hotkey,
        }
        # Persist whatever is in the entry fields; load-time validation handles bad values.
        cp["timing"] = {
            "interval_ms": self.interval_var.get().strip() or str(DEFAULT_INTERVAL_MS),
            "jitter_ms": self.jitter_var.get().strip() or str(DEFAULT_JITTER_MS),
        }
        cp["identity"] = {"window_title": self.window_title}
        with self.points_lock:
            snapshot = list(self.points)
        points_section = {"count": str(len(snapshot))}
        for i, p in enumerate(snapshot, 1):
            points_section[str(i)] = f"{p['x']},{p['y']},{p['button']}"
        cp["points"] = points_section
        try:
            with CONFIG_FILE.open("w", encoding="utf-8") as f:
                cp.write(f)
        except OSError:
            pass

    def _on_close(self):
        self.running.clear()
        self.stop_app.set()
        try:
            if self.hotkeys is not None:
                self.hotkeys.stop()
        except Exception:
            pass
        try:
            if self._rebind_listener is not None:
                self._rebind_listener.stop()
        except Exception:
            pass
        self.root.destroy()


def main():
    root = tk.Tk()
    App(root)
    root.mainloop()


if __name__ == "__main__":
    main()
