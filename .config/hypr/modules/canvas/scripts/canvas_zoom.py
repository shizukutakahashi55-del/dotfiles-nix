#!/usr/bin/env python3
"""
canvas_zoom.py - Infinite Canvas Zoom In / Out Engine
Scales floating windows relative to mouse cursor position (or monitor center)
for a true Figma/Miro-style infinite whiteboard zoom experience.

Usage: canvas_zoom.py <in|out|reset>
"""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hypr_ipc import (get_active_workspace_id, get_cursor_pos, get_floating_windows,
                      get_focused_monitor, get_monitor_bounds,
                      move_window_exact_lua, resize_window_exact_lua,
                      batch_async, save_canvas_positions)

ZOOM_FACTOR_IN = 1.15
ZOOM_FACTOR_OUT = 0.85

MIN_WIDTH = 280
MIN_HEIGHT = 200

# Tope duro histórico del módulo; se recorta además al monitor actual.
HARD_MAX_WIDTH = 1240
HARD_MAX_HEIGHT = 680

DEFAULT_CARD_WIDTH = 585
DEFAULT_CARD_HEIGHT = 520


def get_limits(mon):
    max_w = min(HARD_MAX_WIDTH, max(MIN_WIDTH, mon["width"] - 80))
    max_h = min(HARD_MAX_HEIGHT, max(MIN_HEIGHT, mon["height"] - 120))
    return max_w, max_h


def get_focal_point(mon):
    cur = get_cursor_pos()
    if cur:
        cx, cy = cur
        # El cursor puede quedar fuera de los monitores tras un paneo.
        if mon["left"] <= cx <= mon["right"] and mon["top"] <= cy <= mon["bottom"]:
            return float(cx), float(cy)

    return float(mon["left"] + mon["width"] // 2), float(mon["top"] + mon["height"] // 2)


def zoom_canvas(direction):
    workspace_id = get_active_workspace_id()
    if workspace_id is None:
        return

    floating = get_floating_windows(workspace_id)
    if not floating:
        return

    mon = get_monitor_bounds(get_focused_monitor())
    max_w, max_h = get_limits(mon)

    if direction == "reset":
        card_w = min(DEFAULT_CARD_WIDTH, max_w)
        card_h = min(DEFAULT_CARD_HEIGHT, max_h)

        exprs = []
        updates = {}
        for w in floating:
            exprs.append(resize_window_exact_lua(card_w, card_h, w["address"]))
            updates[w["address"]] = {
                "x": int(w["at"][0]), "y": int(w["at"][1]),
                "w": card_w, "h": card_h,
            }
        batch_async(exprs)
        save_canvas_positions(workspace_id, updates)
        return

    scale = ZOOM_FACTOR_IN if direction == "in" else ZOOM_FACTOR_OUT
    fx, fy = get_focal_point(mon)

    exprs = []
    updated_positions = {}

    for w in floating:
        curr_x, curr_y = w["at"][0], w["at"][1]
        curr_w, curr_h = w["size"][0], w["size"][1]

        new_w = max(MIN_WIDTH, min(max_w, int(curr_w * scale)))
        new_h = max(MIN_HEIGHT, min(max_h, int(curr_h * scale)))

        # Scale center position relative to the focal point.
        center_x = curr_x + curr_w / 2
        center_y = curr_y + curr_h / 2

        new_center_x = fx + (center_x - fx) * scale
        new_center_y = fy + (center_y - fy) * scale

        new_x = int(new_center_x - new_w / 2)
        new_y = int(new_center_y - new_h / 2)

        exprs.append(resize_window_exact_lua(new_w, new_h, w["address"]))
        exprs.append(move_window_exact_lua(new_x, new_y, w["address"]))

        updated_positions[w["address"]] = {
            "x": new_x,
            "y": new_y,
            "w": new_w,
            "h": new_h,
        }

    batch_async(exprs)
    save_canvas_positions(workspace_id, updated_positions)


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("in", "out", "reset"):
        print("Usage: canvas_zoom.py <in|out|reset>")
        sys.exit(1)

    zoom_canvas(sys.argv[1])


if __name__ == "__main__":
    main()
