#!/usr/bin/env python3
"""
canvas_center.py - Centra la ventana activa en el monitor actual.

Mueve todas las tarjetas flotantes del workspace para que el centro de la
ventana activa (o la más cercana al centro si la activa está tiled) coincida
con el centro visible del monitor. No cambia tamaños.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hypr_ipc import (batch_async, get_active_workspace_id, get_floating_windows,
                      get_focused_monitor, get_monitor_bounds, hyprctl_json,
                      move_window_exact_lua, save_canvas_positions, window_bounds)


def pick_target(windows, active, mon):
    active_addr = (active or {}).get("address")
    if active_addr:
        for w in windows:
            if w["address"] == active_addr:
                return w

    mon_cx = mon["left"] + mon["width"] / 2
    mon_cy = mon["top"] + mon["height"] / 2
    return min(
        windows,
        key=lambda w: (window_bounds(w)["cx"] - mon_cx) ** 2 +
                      (window_bounds(w)["cy"] - mon_cy) ** 2,
    )


def center():
    workspace_id = get_active_workspace_id()
    if workspace_id is None:
        return

    windows = get_floating_windows(workspace_id)
    if not windows:
        return

    mon = get_monitor_bounds(get_focused_monitor())
    active = hyprctl_json(["activewindow"])
    target = pick_target(windows, active, mon)

    tb = window_bounds(target)
    mon_cx = mon["left"] + mon["width"] // 2
    mon_cy = mon["top"] + mon["height"] // 2

    dx = int(mon_cx - tb["cx"])
    dy = int(mon_cy - tb["cy"])
    if abs(dx) < 2 and abs(dy) < 2:
        return

    exprs = []
    updates = {}
    for w in windows:
        b = window_bounds(w)
        nx = b["x"] + dx
        ny = b["y"] + dy
        exprs.append(move_window_exact_lua(nx, ny, w["address"]))
        updates[w["address"]] = {
            "x": nx, "y": ny, "w": b["w"], "h": b["h"],
        }

    batch_async(exprs)
    save_canvas_positions(workspace_id, updates)


def main():
    center()


if __name__ == "__main__":
    main()
