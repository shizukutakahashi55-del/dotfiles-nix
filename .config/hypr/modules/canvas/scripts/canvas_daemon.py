#!/usr/bin/env python3
"""
canvas_daemon.py - Auto-captura de ventanas nuevas para Infinite Canvas.

Escucha el socket2 de Hyprland (eventos openwindow/closewindow) y, si el
workspace está en modo canvas, coloca la ventana nueva como tarjeta flotante
en la posición del cursor (o al lado de las existentes).

No lee /dev/input: el paneo con ALT + botón medio vive en canvas.lua.
Requiere sólo python3 (sin evdev) y el grupo `input` NO es necesario.

Lock: una sola instancia por sesión (XDG_RUNTIME_DIR/hypr-canvas-daemon.lock).
"""

import fcntl
import json
import os
import socket
import subprocess
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hypr_ipc import (batch_async, get_cursor_pos, get_state_file_path,
                      move_window_exact_lua, resize_window_exact_lua,
                      set_floating_lua)


def lock_path():
    xdg = os.environ.get("XDG_RUNTIME_DIR")
    if xdg and os.path.isdir(xdg):
        return os.path.join(xdg, "hypr-canvas-daemon.lock")
    try:
        return f"/tmp/hypr-canvas-daemon_{os.getuid()}.lock"
    except Exception:
        return "/tmp/hypr-canvas-daemon.lock"


def hyprctl_json(args, timeout=0.3):
    try:
        r = subprocess.run(["hyprctl"] + args + ["-j"],
                           capture_output=True, text=True, timeout=timeout)
        return json.loads(r.stdout) if r.stdout.strip() else None
    except Exception:
        return None


def get_monitor_bounds():
    monitors = hyprctl_json(["monitors"]) or []
    for m in monitors:
        if m.get("focused"):
            scale = m.get("scale", 1.0) or 1.0
            w = int(m["width"] / scale)
            h = int(m["height"] / scale)
            return {"left": m["x"], "right": m["x"] + w,
                    "top": m["y"], "bottom": m["y"] + h,
                    "width": w, "height": h}
    return {"left": 0, "right": 1280, "top": 0, "bottom": 720,
            "width": 1280, "height": 720}


def get_monitor_for_cursor(cx, cy):
    monitors = hyprctl_json(["monitors"]) or []
    for m in monitors:
        scale = m.get("scale", 1.0) or 1.0
        mx, my = m.get("x", 0), m.get("y", 0)
        mw = int(m["width"] / scale)
        mh = int(m["height"] / scale)
        if mx <= cx <= mx + mw and my <= cy <= my + mh:
            return {"left": mx, "right": mx + mw,
                    "top": my, "bottom": my + mh,
                    "width": mw, "height": mh}
    return get_monitor_bounds()


def on_window_opened(new_addr, initial_cursor=None, win_ws=None):
    cursor_pos = initial_cursor or get_cursor_pos()
    time.sleep(0.08)
    if cursor_pos is None:
        cursor_pos = get_cursor_pos()

    try:
        state_file = get_state_file_path()
        if not os.path.exists(state_file):
            return
        with open(state_file, "r") as f:
            state = json.load(f)

        clients = hyprctl_json(["clients"], timeout=0.5) or []
        new_win = next((c for c in clients if c.get("address") == new_addr), None)
        if not new_win:
            time.sleep(0.06)
            clients = hyprctl_json(["clients"], timeout=0.5) or []
            new_win = next((c for c in clients if c.get("address") == new_addr), None)
            if not new_win:
                return

        if win_ws is None:
            raw_ws = new_win.get("workspace", {}).get("id")
            win_ws = str(raw_ws) if raw_ws is not None else None

        if win_ws is None:
            active_ws = hyprctl_json(["activeworkspace"], timeout=0.3) or {}
            win_ws = str(active_ws.get("id"))

        ws_key = str(win_ws)
        ws_state = state.get(ws_key, {})
        if ws_state.get("mode") != "canvas":
            return

        # Asegurar que la ventana es flotante.
        if not new_win.get("floating"):
            subprocess.run(["hyprctl", "dispatch", set_floating_lua(new_addr, enabled=True)],
                           capture_output=True, timeout=0.3)
            time.sleep(0.02)

        mon = get_monitor_for_cursor(cursor_pos[0], cursor_pos[1]) if cursor_pos else get_monitor_bounds()
        default_w = min(585, mon["width"] - 70)
        default_h = min(520, mon["height"] - 140)

        other_canvas = [c for c in clients
                        if str(c.get("workspace", {}).get("id")) == ws_key
                        and c.get("address") != new_addr]

        if other_canvas:
            sample = other_canvas[-1]
            sample_w = sample.get("size", [default_w, default_h])[0]
            sample_h = sample.get("size", [default_w, default_h])[1]
            if 200 <= sample_w <= mon["width"] and 150 <= sample_h <= mon["height"]:
                card_w, card_h = sample_w, sample_h
            else:
                card_w, card_h = default_w, default_h
        else:
            card_w, card_h = default_w, default_h

        if cursor_pos:
            cx, cy = cursor_pos
            target_x = int(cx - card_w // 2)
            target_y = int(cy - card_h // 2)

            margin = 15
            if mon["width"] > card_w + 2 * margin:
                next_x = max(mon["left"] + margin,
                             min(target_x, mon["right"] - card_w - margin))
            else:
                next_x = mon["left"]

            if mon["height"] > card_h + 2 * margin:
                next_y = max(mon["top"] + margin,
                             min(target_y, mon["bottom"] - card_h - margin))
            else:
                next_y = mon["top"]
        else:
            gap = 40
            margin_x = 35
            margin_y = mon["top"] + (mon["height"] - card_h) // 2
            if other_canvas:
                max_right = max(c["at"][0] + c["size"][0] for c in other_canvas)
                next_x = max_right + gap
                next_y = margin_y
            else:
                next_x = mon["left"] + margin_x
                next_y = margin_y

        resize_expr = resize_window_exact_lua(int(card_w), int(card_h), new_addr)
        move_expr = move_window_exact_lua(int(next_x), int(next_y), new_addr)
        cmd = f"dispatch {resize_expr} ; dispatch {move_expr}"
        subprocess.run(["hyprctl", "--batch", cmd], capture_output=True, timeout=1.0)
        time.sleep(0.04)
        subprocess.run(["hyprctl", "dispatch", move_expr], capture_output=True, timeout=0.5)

        ws_state.setdefault("positions", {})[new_addr] = {
            "x": int(next_x),
            "y": int(next_y),
            "w": int(card_w),
            "h": int(card_h),
            "class": new_win.get("class", ""),
            "title": new_win.get("title", ""),
        }
        with open(state_file, "w") as f:
            json.dump(state, f, indent=2)
        print(f"[hypr-canvas] auto-captured {new_addr} at ({next_x}, {next_y})", flush=True)
    except Exception as e:
        print(f"[hypr-canvas] error in on_window_opened: {e}", flush=True)


def on_window_closed(closed_addr):
    try:
        state_file = get_state_file_path()
        if not os.path.exists(state_file):
            return
        with open(state_file, "r") as f:
            state = json.load(f)

        modified = False
        for _, ws_state in state.items():
            if isinstance(ws_state, dict) and "positions" in ws_state:
                if closed_addr in ws_state["positions"]:
                    del ws_state["positions"][closed_addr]
                    modified = True

        if modified:
            with open(state_file, "w") as f:
                json.dump(state, f, indent=2)
    except Exception:
        pass


def socket2_listener():
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    xdg_runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not xdg_runtime:
        xdg_runtime = f"/run/user/{os.getuid()}"
    if not signature:
        print("[hypr-canvas] HYPRLAND_INSTANCE_SIGNATURE not set; waiting", flush=True)
        return

    sock_path = f"{xdg_runtime}/hypr/{signature}/.socket2.sock"
    print(f"[hypr-canvas] listening on {sock_path}", flush=True)

    while True:
        try:
            if not os.path.exists(sock_path):
                time.sleep(1)
                continue

            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock_path)
            buf = ""

            while True:
                data = s.recv(4096)
                if not data:
                    break
                buf += data.decode("utf-8", errors="ignore")
                while "\n" in buf:
                    line, buf = buf.split("\n", 1)
                    line = line.strip()
                    if line.startswith("openwindow>>"):
                        parts = line[len("openwindow>>"):].split(",", 3)
                        if parts:
                            raw_addr = parts[0].strip()
                            addr = raw_addr if raw_addr.startswith("0x") else f"0x{raw_addr}"
                            win_ws = parts[1].strip() if len(parts) > 1 else None
                            cur = get_cursor_pos()
                            threading.Thread(target=on_window_opened,
                                             args=(addr, cur, win_ws), daemon=True).start()
                    elif line.startswith("closewindow>>"):
                        raw_addr = line[len("closewindow>>"):].strip()
                        addr = raw_addr if raw_addr.startswith("0x") else f"0x{raw_addr}"
                        threading.Thread(target=on_window_closed,
                                         args=(addr,), daemon=True).start()
        except Exception:
            time.sleep(1)


def main():
    lock_fd = open(lock_path(), "w")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("[hypr-canvas] another daemon is already running; exiting", flush=True)
        return 0

    lock_fd.write(str(os.getpid()))
    lock_fd.flush()

    print(f"[hypr-canvas] daemon started (pid {os.getpid()})", flush=True)
    socket2_listener()
    return 0


if __name__ == "__main__":
    sys.exit(main())
