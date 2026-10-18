-- ============================================================================
--  MODULE: canvas.lua — Infinite Canvas (modo whiteboard para Hyprland)
--
--  Origen: infinite-canvas-hyprland (Asterrooid, MIT), adaptado a la
--  estructura de módulos de este dotfiles + compatibilidad OozeShell.
--
--  Decisiones de integración:
--  - Toggle en SUPER + ALT + D (SUPER + D es clipboard de OozeShell).
--  - Zoom con SUPER + CTRL + scroll (libre en keybinds.lua).
--  - Flechas/Z/X/shift/alt NO se tocan: ya los usa keybinds.lua y
--    OozeShell; ver README de este módulo para el mapa completo.
--  - La barra OozeShell es layer-shell: las ventanas flotantes del
--    canvas quedan debajo de ella, no la tapan.
-- ============================================================================

local SCRIPTS = os.getenv("HOME") .. "/.config/hypr/modules/canvas/scripts"
local mainMod = "SUPER"

-- ─── Daemon (pan por gestos + auto-capture por socket) ─────────────────────
-- Requiere: python3 + python-evdev + grupo `input` (ver README).
-- Si falta, el resto (toggle/zoom) sigue funcionando.
hl.on("hyprland.start", function()
    hl.exec_cmd("python3 " .. SCRIPTS .. "/infinite_desktop_core.py 1.6 > /tmp/infinite-desktop.log 2>&1")
end)

-- ─── Toggle Tiled <-> Canvas ────────────────────────────────────────────────
hl.bind(mainMod .. " + ALT + D",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/floating_tile_toggle.py"))

-- ─── Zoom focal (Figma/Miro; en ALT porque CTRL+scroll es zoom de apps) ─────
hl.bind(mainMod .. " + ALT + mouse_up",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/canvas_zoom.py in"))
hl.bind(mainMod .. " + ALT + mouse_down",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/canvas_zoom.py out"))
hl.bind(mainMod .. " + ALT + 0",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/canvas_zoom.py reset"))

-- ─── Navegación y centrado (SUPER + CTRL + flechas: libres en keybinds) ─────
hl.bind(mainMod .. " + CTRL + left",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/navigate_windows.py left"))
hl.bind(mainMod .. " + CTRL + right",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/navigate_windows.py right"))
hl.bind(mainMod .. " + CTRL + up",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/navigate_windows.py up"))
hl.bind(mainMod .. " + CTRL + down",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/navigate_windows.py down"))

-- ─── Arrastrar ventana (igual que keybinds.lua; con el daemon, ─────────────
-- al llegar al borde auto-panea el viewport) ────────────────────────────────
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ─── Mover flotante fino (SUPER + ALT + flechas: libres) ───────────────────
hl.bind(mainMod .. " + ALT + left",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/move_window.py left"),  { repeating = true })
hl.bind(mainMod .. " + ALT + right",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/move_window.py right"), { repeating = true })
hl.bind(mainMod .. " + ALT + up",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/move_window.py up"),    { repeating = true })
hl.bind(mainMod .. " + ALT + down",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/move_window.py down"),  { repeating = true })

-- ─── Resize (SUPER + CTRL + SHIFT + flechas: libres) ────────────────────────
hl.bind(mainMod .. " + CTRL + SHIFT + left",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/resize_window.py left"),  { repeating = true })
hl.bind(mainMod .. " + CTRL + SHIFT + right",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/resize_window.py right"), { repeating = true })
hl.bind(mainMod .. " + CTRL + SHIFT + up",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/resize_window.py up"),    { repeating = true })
hl.bind(mainMod .. " + CTRL + SHIFT + down",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/resize_window.py down"),  { repeating = true })

-- ─── Mover tiled (SUPER + ALT + SHIFT + flechas: libres) ───────────────────
hl.bind(mainMod .. " + ALT + SHIFT + left",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/move_window_tiled.py left"))
hl.bind(mainMod .. " + ALT + SHIFT + right",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/move_window_tiled.py right"))
hl.bind(mainMod .. " + ALT + SHIFT + up",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/move_window_tiled.py up"))
hl.bind(mainMod .. " + ALT + SHIFT + down",
    hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/move_window_tiled.py down"))
