#!/usr/bin/env python3
"""
canvas_fit.py - Encuadra todas las tarjetas del canvas en el monitor actual.

Calcula el bounding box de las ventanas flotantes del workspace activo, escala
(y recentra) el conjunto para que quepa en el área visible y guarda el layout.

Nota: el "zoom" de este canvas redimensiona ventanas (no es una cámara real),
así que fit también reajusta el tamaño de las tarjetas.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hypr_ipc import (DEFAULT_MARGIN_BOTTOM, DEFAULT_MARGIN_TOP, DEFAULT_MARGIN_X,
                      batch_async, get_active_workspace_id, get_floating_windows,
                      get_focused_monitor, get_monitor_bounds, move_window_exact_lua,
                      resize_window_exact_lua, save_canvas_positions, window_bounds)

MIN_WIDTH = 280
MIN_HEIGHT = 200
MIN_SCALE = 0.30


def fit():
    workspace_id = get_active_workspace_id()
    if workspace_id is None:
        return

    windows = get_floating_windows(workspace_id)
    if not windows:
        return

    mon = get_monitor_bounds(get_focused_monitor())

    avail_w = max(200, mon["width"] - 2 * DEFAULT_MARGIN_X)
    avail_h = max(150, mon["height"] - DEFAULT_MARGIN_TOP - DEFAULT_MARGIN_BOTTOM)

    bounds = [window_bounds(w) for w in windows]
    min_x = min(b["x"] for b in bounds)
    min_y = min(b["y"] for b in bounds)
    max_x = max(b["x"] + b["w"] for b in bounds)
    max_y = max(b["y"] + b["h"] for b in bounds)

    bbox_w = max(1, max_x - min_x)
    bbox_h = max(1, max_y - min_y)

    scale = min(1.0, avail_w / bbox_w, avail_h / bbox_h)
    scale = max(MIN_SCALE, scale)

    max_w = max(MIN_WIDTH, min(1240, mon["width"] - 2 * DEFAULT_MARGIN_X))
    max_h = max(MIN_HEIGHT, min(680, mon["height"] - DEFAULT_MARGIN_TOP - DEFAULT_MARGIN_BOTTOM))

    bbox_cx = min_x + bbox_w / 2
    bbox_cy = min_y + bbox_h / 2
    mon_cx = mon["left"] + mon["width"] / 2
    mon_cy = mon["top"] + mon["height"] / 2

    exprs = []
    updates = {}

    for w, b in zip(windows, bounds):
        new_w = max(MIN_WIDTH, min(max_w, int(round(b["w"] * scale))))
        new_h = max(MIN_HEIGHT, min(max_h, int(round(b["h"] * scale))))

        offset_x = (b["cx"] - bbox_cx) * scale
        offset_y = (b["cy"] - bbox_cy) * scale

        new_x = int(round(mon_cx + offset_x - new_w / 2))
        new_y = int(round(mon_cy + offset_y - new_h / 2))

        exprs.append(resize_window_exact_lua(new_w, new_h, w["address"]))
        exprs.append(move_window_exact_lua(new_x, new_y, w["address"]))

        updates[w["address"]] = {
            "x": new_x, "y": new_y, "w": new_w, "h": new_h,
        }

    batch_async(exprs)
    save_canvas_positions(workspace_id, updates)


def main():
    fit()


if __name__ == "__main__":
    main()
