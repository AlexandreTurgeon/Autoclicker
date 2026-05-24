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
CAPTURE_HOTKEY = "<f6>"
TOGGLE_HOTKEY = "<f8>"


class App:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("Multi-Point Autoclicker")
        self.root.geometry("520x420")

        self.points: list[dict] = []
        self.points_lock = threading.Lock()
        self.running = threading.Event()
        self.stop_app = threading.Event()
        self.mouse = mouse.Controller()
        self.default_button = tk.StringVar(value="left")
        self.interval_var = tk.StringVar(value=str(DEFAULT_INTERVAL_MS))
        self.status_var = tk.StringVar(value="IDLE")

        self._build_ui()

        self.clicker_thread = threading.Thread(target=self._clicker_loop, daemon=True)
        self.clicker_thread.start()

        self.hotkeys = keyboard.GlobalHotKeys({
            CAPTURE_HOTKEY: self._on_capture_hotkey,
            TOGGLE_HOTKEY: self._on_toggle_hotkey,
        })
        self.hotkeys.start()

        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

    def _build_ui(self):
        pad = {"padx": 8, "pady": 4}

        top = ttk.Frame(self.root)
        top.pack(fill="x", **pad)
        ttk.Label(top, textvariable=self.status_var, font=("Segoe UI", 14, "bold")).pack(side="left")
        ttk.Label(top, text="  F6 = capture point   F8 = start/stop").pack(side="left")

        cfg = ttk.Frame(self.root)
        cfg.pack(fill="x", **pad)
        ttk.Label(cfg, text="Interval (ms):").pack(side="left")
        ttk.Entry(cfg, textvariable=self.interval_var, width=8).pack(side="left", padx=(4, 16))
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

    def _clear_all(self):
        with self.points_lock:
            self.points.clear()
        self._refresh_tree()

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

    def _on_capture_hotkey(self):
        x, y = self.mouse.position
        btn = self.default_button.get()
        with self.points_lock:
            self.points.append({"x": int(x), "y": int(y), "button": btn})
        self.root.after(0, self._refresh_tree)

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

    def _read_interval_seconds(self) -> float:
        try:
            v = int(self.interval_var.get())
            if v < 0:
                v = 0
        except (ValueError, TypeError):
            v = DEFAULT_INTERVAL_MS
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
            delay = self._read_interval_seconds()
            for p in cycle:
                if not self.running.is_set() or self.stop_app.is_set():
                    break
                try:
                    self.mouse.position = (p["x"], p["y"])
                    self.mouse.click(BUTTON_OBJ[p["button"]], 1)
                except Exception:
                    pass
                if delay:
                    end = time.monotonic() + delay
                    while time.monotonic() < end:
                        if not self.running.is_set() or self.stop_app.is_set():
                            break
                        time.sleep(min(0.01, end - time.monotonic()))

    def _on_close(self):
        self.running.clear()
        self.stop_app.set()
        try:
            self.hotkeys.stop()
        except Exception:
            pass
        self.root.destroy()


def main():
    root = tk.Tk()
    App(root)
    root.mainloop()


if __name__ == "__main__":
    main()
