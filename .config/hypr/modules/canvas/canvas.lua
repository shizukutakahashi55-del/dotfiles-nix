-- ============================================================================
--  MODULE: canvas.lua — Infinite Canvas (modo whiteboard para Hyprland)
--
--  Origen: infinite-canvas-hyprland (Asterrooid, MIT), adaptado a la
--  estructura de módulos de este dotfiles + compatibilidad OozeShell.
--
--  Paneo y zoom con ALT + ratón, implementados en Lua puro:
--  - No usa evdev, ni python-evdev, ni el grupo `input`, ni root.
--  - El paneo sólo existe mientras arrastras: un hl.timer de 16 ms que se
--    activa con el botón y se apaga al soltarlo (0 CPU en reposo).
--  - El bind consume el botón (binds:pass_mouse_when_bound = false), así que
--    el clic no llega a las apps.
--
--  Binds (ver README.md del módulo):
--    ALT + botón medio (arrastrar)  pan del canvas
--    ALT + rueda                    zoom focal (centrado en el cursor)
--    ALT + 0                        reset de zoom
--    SUPER + ALT + D                toggle tiled <-> canvas
--    SUPER + ALT + F                fit (encuadrar todas las tarjetas)
--    SUPER + ALT + H                centrar la ventana activa
--    SUPER + ALT + G                ordenar tarjetas en grid por app
--
--  El único proceso persistente es canvas_daemon.py (socket2): auto-captura
--  de ventanas nuevas en modo canvas. No lee /dev/input.
-- ============================================================================

local SCRIPTS = os.getenv("HOME") .. "/.config/hypr/modules/canvas/scripts"
local mainMod = "SUPER"

-- ─── Ajustes de paneo ───────────────────────────────────────────────────────
-- mouse:272 = izquierdo, 274 = medio, 275 = atrás (side)
local PAN_BUTTON  = "mouse:274"
local PAN_SPEED   = 1.0    -- 1.0 = el lienzo sigue al cursor 1:1
local PAN_INVERT  = false  -- true = invertir la dirección del arrastre
local EDGE_WRAP   = false  -- true = saltar el cursor al borde opuesto
local EDGE_MARGIN = 8
local PAN_TICK_MS = 16
local PAN_MAX_MS  = 120000 -- red de seguridad si se pierde el release

local function run(script, ...)
    local args = table.concat({ ... }, " ")
    return hl.dsp.exec_cmd("python3 " .. SCRIPTS .. "/" .. script .. (args ~= "" and (" " .. args) or ""))
end

-- ─── Daemon (socket2: auto-captura; NO lee /dev/input) ─────────────────────
local function start_daemon()
    hl.exec_cmd("python3 " .. SCRIPTS .. "/canvas_daemon.py > /tmp/hypr-canvas.log 2>&1")
end

hl.on("hyprland.start", start_daemon)
-- config.reloaded se dispara también al recargar; el daemon tiene lock, así
-- que si ya está corriendo el nuevo proceso sale sin hacer nada.
hl.on("config.reloaded", start_daemon)

-- ─── Toggle Tiled <-> Canvas ────────────────────────────────────────────────
hl.bind(mainMod .. " + ALT + D", run("floating_tile_toggle.py"))

-- ─── Zoom focal (Figma/Miro) ────────────────────────────────────────────────
hl.bind("ALT + mouse_up",   run("canvas_zoom.py", "in"))
hl.bind("ALT + mouse_down", run("canvas_zoom.py", "out"))
hl.bind("ALT + 0",          run("canvas_zoom.py", "reset"))

-- ─── Encuadre y orden ───────────────────────────────────────────────────────
hl.bind(mainMod .. " + ALT + F", run("canvas_fit.py"))
hl.bind(mainMod .. " + ALT + H", run("canvas_center.py"))
hl.bind(mainMod .. " + ALT + G", run("canvas_tidy.py"))

-- ─── Navegación y centrado (SUPER + CTRL + flechas) ─────────────────────────
hl.bind(mainMod .. " + CTRL + left",  run("navigate_windows.py", "left"))
hl.bind(mainMod .. " + CTRL + right", run("navigate_windows.py", "right"))
hl.bind(mainMod .. " + CTRL + up",    run("navigate_windows.py", "up"))
hl.bind(mainMod .. " + CTRL + down",  run("navigate_windows.py", "down"))

-- ─── Mover flotante fino (SUPER + ALT + flechas) ───────────────────────────
hl.bind(mainMod .. " + ALT + left",  run("move_window.py", "left"),  { repeating = true })
hl.bind(mainMod .. " + ALT + right", run("move_window.py", "right"), { repeating = true })
hl.bind(mainMod .. " + ALT + up",    run("move_window.py", "up"),    { repeating = true })
hl.bind(mainMod .. " + ALT + down",  run("move_window.py", "down"),  { repeating = true })

-- ─── Resize (SUPER + CTRL + SHIFT + flechas) ────────────────────────────────
hl.bind(mainMod .. " + CTRL + SHIFT + left",  run("resize_window.py", "left"),  { repeating = true })
hl.bind(mainMod .. " + CTRL + SHIFT + right", run("resize_window.py", "right"), { repeating = true })
hl.bind(mainMod .. " + CTRL + SHIFT + up",    run("resize_window.py", "up"),    { repeating = true })
hl.bind(mainMod .. " + CTRL + SHIFT + down",  run("resize_window.py", "down"),  { repeating = true })

-- ─── Mover tiled (SUPER + ALT + SHIFT + flechas) ───────────────────────────
hl.bind(mainMod .. " + ALT + SHIFT + left",  run("move_window_tiled.py", "left"))
hl.bind(mainMod .. " + ALT + SHIFT + right", run("move_window_tiled.py", "right"))
hl.bind(mainMod .. " + ALT + SHIFT + up",    run("move_window_tiled.py", "up"))
hl.bind(mainMod .. " + ALT + SHIFT + down",  run("move_window_tiled.py", "down"))

-- ============================================================================
--  PAN DEL CANVAS (ALT + botón medio)
--
--  Funciona moviendo las ventanas flotantes del workspace activo en sentido
--  contrario al arrastre: el contenido sigue al cursor. Un solo timer
--  reutilizado se habilita/deshabilita para no acumular timers por arrastre.
-- ============================================================================
local pan_timer              = nil
local pan_last_x, pan_last_y = nil, nil
local pan_acc_x, pan_acc_y   = 0.0, 0.0
local pan_ws_id              = nil
local pan_started_ms         = 0

local function round_half(v)
    if v >= 0 then return math.floor(v + 0.5) end
    return -math.floor(-v + 0.5)
end

local function active_floating()
    local ws = hl.get_active_workspace()
    if not ws then return nil, {} end

    local out = {}
    local wins = ws:get_windows()
    for i = 1, #wins do
        local w = wins[i]
        if w.floating then
            out[#out + 1] = w
        end
    end
    return ws, out
end

local function pan_stop()
    if pan_timer then pan_timer:set_enabled(false) end
    pan_last_x, pan_last_y = nil, nil
    pan_ws_id              = nil
    pan_acc_x, pan_acc_y   = 0.0, 0.0
end

local function wrap_cursor(x, y, dx, dy)
    if not EDGE_WRAP then return x, y end

    local mon = hl.get_monitor_at_cursor()
    if not mon then return x, y end

    local scale = mon.scale or 1.0
    if scale <= 0 then scale = 1.0 end
    local sw = mon.width / scale
    local sh = mon.height / scale
    local mx, my = mon.x, mon.y

    local nx, ny = x, y
    if x <= mx + EDGE_MARGIN and dx < 0 then
        nx = mx + sw - EDGE_MARGIN * 3
    elseif x >= mx + sw - EDGE_MARGIN and dx > 0 then
        nx = mx + EDGE_MARGIN * 3
    end
    if y <= my + EDGE_MARGIN and dy < 0 then
        ny = my + sh - EDGE_MARGIN * 3
    elseif y >= my + sh - EDGE_MARGIN and dy > 0 then
        ny = my + EDGE_MARGIN * 3
    end

    if nx ~= x or ny ~= y then
        hl.dispatch(hl.dsp.cursor.move({ x = nx, y = ny }))
        -- Evita que el salto se interprete como un arrastre enorme.
        pan_last_x, pan_last_y = nx, ny
    end
end

local function pan_tick()
    -- Red de seguridad: si se perdiera el release, el pan no se queda activo.
    if os.time() * 1000 - pan_started_ms > PAN_MAX_MS then
        pan_stop()
        return
    end

    -- Si el usuario suelta ALT, parar aunque el release del ratón no llegue.
    if not (hl.is_key_down("Alt_L") or hl.is_key_down("Alt_R")) then
        pan_stop()
        return
    end

    local ws, wins = active_floating()
    if not ws or #wins == 0 or (pan_ws_id ~= nil and ws.id ~= pan_ws_id) then
        pan_stop()
        return
    end

    local pos = hl.get_cursor_pos()
    if not pos then
        pan_stop()
        return
    end

    if pan_last_x == nil then
        pan_last_x, pan_last_y = pos.x, pos.y
        return
    end

    local dx = pos.x - pan_last_x
    local dy = pos.y - pan_last_y
    if dx == 0 and dy == 0 then return end

    -- Saltos grandes (cambio de monitor, warp): descartar el delta.
    if math.abs(dx) > 400 or math.abs(dy) > 400 then
        pan_last_x, pan_last_y = pos.x, pos.y
        return
    end

    pan_last_x, pan_last_y = pos.x, pos.y

    local sign = PAN_INVERT and -1.0 or 1.0
    pan_acc_x = pan_acc_x + dx * PAN_SPEED * sign
    pan_acc_y = pan_acc_y + dy * PAN_SPEED * sign

    local mx = round_half(pan_acc_x)
    local my = round_half(pan_acc_y)
    if mx == 0 and my == 0 then return end

    pan_acc_x = pan_acc_x - mx
    pan_acc_y = pan_acc_y - my

    for i = 1, #wins do
        hl.dispatch(hl.dsp.window.move({
            window   = "address:" .. wins[i].address,
            x        = mx,
            y        = my,
            relative = true,
        }))
    end

    wrap_cursor(pos.x, pos.y, dx, dy)
end

pan_timer = hl.timer(pan_tick, { timeout = PAN_TICK_MS, type = "repeat" })
pan_timer:set_enabled(false)

hl.bind("ALT + " .. PAN_BUTTON, function()
    local ws, wins = active_floating()
    if not ws or #wins == 0 then return end

    local pos = hl.get_cursor_pos()
    if not pos then return end

    pan_ws_id      = ws.id
    pan_last_x     = pos.x
    pan_last_y     = pos.y
    pan_acc_x      = 0.0
    pan_acc_y      = 0.0
    pan_started_ms = os.time() * 1000
    pan_timer:set_enabled(true)
end, { description = "Canvas: pan" })

-- `transparent` es obligatorio aquí: Hyprland 0.56 marca los binds de release
-- como "shadowed" tras un press de ratón que consume el evento, y entonces el
-- release nunca se dispara (el pan se quedaría pegado). Con transparent el
-- bind de release no entra en ese cálculo.
hl.bind("ALT + " .. PAN_BUTTON, function()
    pan_stop()
end, { release = true, transparent = true, description = "Canvas: pan (release)" })
