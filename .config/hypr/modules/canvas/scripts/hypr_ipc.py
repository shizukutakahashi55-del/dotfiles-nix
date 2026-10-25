#!/usr/bin/env python3

import subprocess
import json
import os


def get_state_file_path():
    """Prefers $XDG_RUNTIME_DIR/hypr_infinite_state.json, fallback to
    /tmp/floating_tile_state_<uid>.json, fallback to /tmp/floating_tile_state.json."""
    xdg = os.environ.get("XDG_RUNTIME_DIR")
    if xdg and os.path.isdir(xdg):
        return os.path.join(xdg, "hypr_infinite_state.json")
    try:
        uid = os.getuid()
        return f"/tmp/floating_tile_state_{uid}.json"
    except Exception:
        return "/tmp/floating_tile_state.json"


def _run(args, timeout=2):
    return subprocess.run(["hyprctl"] + args, capture_output=True, text=True, timeout=timeout)


def hyprctl_json(args, timeout=2):
    """Read-only queries (clients, activewindow, monitors, etc.) returning parsed JSON."""
    r = _run(args + ["-j"], timeout=timeout)
    return json.loads(r.stdout) if r.stdout.strip() else None


def dispatch(lua_expr, timeout=2):
    """Executes hyprctl dispatch '<lua_expr>' where lua_expr is an hl.dsp.*(...) call."""
    return _run(["dispatch", lua_expr], timeout=timeout)


def dispatch_async(lua_expr):
    subprocess.Popen(["hyprctl", "dispatch", lua_expr],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def batch(lua_exprs, timeout=5):
    """Executes multiple hyprctl dispatch expressions in batch.
    lua_exprs: list of complete calls to hl.dsp.*(...)"""
    cmd = " ; ".join(f"dispatch {e}" for e in lua_exprs)
    return subprocess.run(["hyprctl", "--batch", cmd], capture_output=True, timeout=timeout)


def batch_async(lua_exprs):
    if not lua_exprs:
        return
    cmd = " ; ".join(f"dispatch {e}" for e in lua_exprs)
    subprocess.Popen(["hyprctl", "--batch", cmd],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# official wiki

def toggle_floating_lua(address=None):
    w = f', window = "address:{address}"' if address else ""
    return f'hl.dsp.window.float({{ action = "toggle"{w} }})'

def toggle_floating(address=None):
    return dispatch(toggle_floating_lua(address))


def focus_window_lua(address):
    return f'hl.dsp.focus({{ window = "address:{address}" }})'

def focus_window(address):
    return dispatch(focus_window_lua(address))


def move_focus_lua(direction_lud):  # 'l' | 'r' | 'u' | 'd'
    return f'hl.dsp.focus({{ direction = "{direction_lud}" }})'

def move_focus(direction_lud):
    return dispatch(move_focus_lua(direction_lud))


def move_window_tiled_lua(direction_lud):
    return f'hl.dsp.window.move({{ direction = "{direction_lud}" }})'

def move_window_tiled(direction_lud):
    return dispatch(move_window_tiled_lua(direction_lud))


def exec_cmd_lua(cmd):
    escaped = cmd.replace('\\', '\\\\').replace('"', '\\"')
    return f'hl.dsp.exec_cmd("{escaped}")'



def move_window_exact_lua(x, y, address):
    return (f'hl.dsp.window.move({{ window = "address:{address}", '
            f'x = {int(x)}, y = {int(y)}, relative = false }})')

def move_window_exact(x, y, address, timeout=2):
    return dispatch(move_window_exact_lua(x, y, address), timeout=timeout)

def move_window_exact_async(x, y, address):
    dispatch_async(move_window_exact_lua(x, y, address))


def resize_window_exact_lua(w, h, address):
    return (f'hl.dsp.window.resize({{ window = "address:{address}", '
            f'x = {int(w)}, y = {int(h)}, relative = false }})')

def resize_window_exact(w, h, address, timeout=2):
    return dispatch(resize_window_exact_lua(w, h, address), timeout=timeout)


def set_floating_lua(address=None, enabled=True):
    action = "on" if enabled else "off"
    w = f', window = "address:{address}"' if address else ""
    return f'hl.dsp.window.float({{ action = "{action}"{w} }})'


def get_cursor_pos(timeout=0.2):
    """Returns (x, y) coordinates of the mouse cursor in logical screen space, or None."""
    try:
        cur = hyprctl_json(["cursorpos"], timeout=timeout)
        if cur and isinstance(cur, dict) and "x" in cur and "y" in cur:
            return int(cur["x"]), int(cur["y"])
    except Exception:
        pass
    return None


# ─── Layout helpers (canvas scripts) ───────────────────────────────────────

DEFAULT_MARGIN_X = 40
DEFAULT_MARGIN_TOP = 80
DEFAULT_MARGIN_BOTTOM = 40


def get_focused_monitor(timeout=0.3):
    monitors = hyprctl_json(["monitors"], timeout=timeout) or []
    for m in monitors:
        if m.get("focused"):
            return m
    return monitors[0] if monitors else None


def get_monitor_bounds(monitor=None, timeout=0.3):
    """Logical bounds of a monitor ({left,top,right,bottom,width,height,scale})."""
    m = monitor or get_focused_monitor(timeout=timeout)
    if not m:
        return {"left": 0, "top": 0, "right": 1280, "bottom": 720,
                "width": 1280, "height": 720, "scale": 1.0, "name": ""}

    scale = m.get("scale", 1.0) or 1.0
    w = int(m.get("width", 1920) / scale)
    h = int(m.get("height", 1080) / scale)
    x = int(m.get("x", 0))
    y = int(m.get("y", 0))
    return {
        "left": x, "top": y, "right": x + w, "bottom": y + h,
        "width": w, "height": h, "scale": scale,
        "name": m.get("name", ""),
    }


def get_active_workspace_id(timeout=0.3):
    ws = hyprctl_json(["activeworkspace"], timeout=timeout)
    return ws.get("id") if ws else None


def get_floating_windows(workspace_id=None, mapped_only=True, timeout=0.5):
    """Floating windows of a workspace (all workspaces if workspace_id is None)."""
    clients = hyprctl_json(["clients"], timeout=timeout) or []
    out = []
    for w in clients:
        if not w.get("floating"):
            continue
        if workspace_id is not None and w.get("workspace", {}).get("id") != workspace_id:
            continue
        if mapped_only and not w.get("mapped", True):
            continue
        out.append(w)
    return out


def window_bounds(w):
    x, y = int(w["at"][0]), int(w["at"][1])
    ww, wh = int(w["size"][0]), int(w["size"][1])
    return {"x": x, "y": y, "w": ww, "h": wh,
            "cx": x + ww // 2, "cy": y + wh // 2}


def save_canvas_positions(workspace_id, updates):
    """Persist positions in the canvas state file, only if the ws is in canvas mode.

    updates: {address: {"x": x, "y": y, "w": w, "h": h}}
    """
    if not updates:
        return
    try:
        path = get_state_file_path()
        if not os.path.exists(path):
            return
        with open(path, "r") as f:
            state = json.load(f)
        key = str(workspace_id)
        if key in state and state[key].get("mode") == "canvas":
            state[key].setdefault("positions", {}).update(updates)
            with open(path, "w") as f:
                json.dump(state, f, indent=2)
    except Exception:
        pass


