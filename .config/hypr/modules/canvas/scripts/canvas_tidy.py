#!/usr/bin/env python3
"""
canvas_tidy.py - Ordena las tarjetas del canvas en un grid, agrupadas por app.

Idea tomada del "tidy" de Phantomat / Infinity Land: mismo `class` queda junto,
en orden alfabético, y el grid se centra en el monitor. No cambia tamaños; usa
una celda del tamaño de la tarjeta más grande para que nada se solape.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hypr_ipc import (DEFAULT_MARGIN_BOTTOM, DEFAULT_MARGIN_TOP, DEFAULT_MARGIN_X,
                      batch_async, get_active_workspace_id, get_floating_windows,
                      get_focused_monitor, get_monitor_bounds, move_window_exact_lua,
                      save_canvas_positions, window_bounds)

GAP = 40


def tidy():
    workspace_id = get_active_workspace_id()
    if workspace_id is None:
        return

    windows = get_floating_windows(workspace_id)
    if not windows:
        return

    mon = get_monitor_bounds(get_focused_monitor())

    avail_w = max(200, mon["width"] - 2 * DEFAULT_MARGIN_X)
    avail_h = max(150, mon["height"] - DEFAULT_MARGIN_TOP - DEFAULT_MARGIN_BOTTOM)

    windows.sort(key=lambda w: (
        str(w.get("class", "")).lower(),
        str(w.get("title", "")).lower(),
        str(w.get("address", "")),
    ))

    bounds = {w["address"]: window_bounds(w) for w in windows}
    cell_w = max(b["w"] for b in bounds.values())
    cell_h = max(b["h"] for b in bounds.values())

    cols = max(1, (avail_w + GAP) // (cell_w + GAP))
    cols = min(cols, len(windows))
    rows = int(math.ceil(len(windows) / cols))

    grid_w = cols * cell_w + (cols - 1) * GAP
    grid_h = rows * cell_h + (rows - 1) * GAP

    origin_x = mon["left"] + mon["width"] / 2 - grid_w / 2
    origin_y = mon["top"] + mon["height"] / 2 - grid_h / 2

    exprs = []
    updates = {}

    for idx, w in enumerate(windows):
        b = bounds[w["address"]]
        col = idx % cols
        row = idx // cols

        cell_cx = origin_x + col * (cell_w + GAP) + cell_w / 2
        cell_cy = origin_y + row * (cell_h + GAP) + cell_h / 2

        nx = int(round(cell_cx - b["w"] / 2))
        ny = int(round(cell_cy - b["h"] / 2))

        exprs.append(move_window_exact_lua(nx, ny, w["address"]))
        updates[w["address"]] = {
            "x": nx, "y": ny, "w": b["w"], "h": b["h"],
        }

    batch_async(exprs)
    save_canvas_positions(workspace_id, updates)


def main():
    tidy()


if __name__ == "__main__":
    main()
