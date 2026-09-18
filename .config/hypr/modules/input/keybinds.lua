
-- ============================================================================
--  MODULE: keybinds.lua
--  Contains: every hl.bind() -- keyboard binds, workspace switching,
--  multimedia keys, and the mouse binds (move/resize windows with the mouse).
--  Wiki: https://wiki.hypr.land/Configuring/Basics/Binds/
-- ============================================================================

local programs = require("modules.startup.programs")
---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier


-------------------------------------------------------------------------------
-- APPLICATIONS
-------------------------------------------------------------------------------

-- Terminal
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(programs.terminal))

-- File Manager
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(programs.fileManager))

-- Application Menu / Launcher
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(programs.menu))


-------------------------------------------------------------------------------
-- WINDOW MANAGEMENT
-------------------------------------------------------------------------------

-- Close active window
local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close())

-- Toggle floating window
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))

-- Toggle pseudo mode
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())

-- Toggle split direction (dwindle only)
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

--Toogle full screen size 
hl.bind(
    "SUPER + F",
    hl.dsp.window.fullscreen("toggle")
)

-- Swap active window with the left one
hl.bind("SUPER + SHIFT + H", function()
    hl.dispatch(hl.dsp.window.swap({ direction = "left" }))
end)

-- Swap active window with the rigth one
hl.bind("SUPER + SHIFT + L", function()
    hl.dispatch(hl.dsp.window.swap({ direction = "right" }))
end)


-------------------------------------------------------------------------------
-- MASTER / COLUMN LAYOUT
-------------------------------------------------------------------------------
-- Move between columns
-- Resize current column using configured sizes
-------------------------------------------------------------------------------

-- Move active to next column
hl.bind(
    "SUPER + period",
    hl.dsp.layout("move +col")
)

-- Move active to previous column
hl.bind(
    "SUPER + comma",
    hl.dsp.layout("move -col")
)

-- Increase column width
hl.bind(
    "SUPER + bracketright",
    hl.dsp.layout("colresize +conf")
)

-- Decrease column width
hl.bind(
    "SUPER + bracketleft",
    hl.dsp.layout("colresize -conf")
)


-------------------------------------------------------------------------------
-- WINDOW FOCUS
-------------------------------------------------------------------------------

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-------------------------------------------------------------------------------
-- MOVE ACTIVE WINDOW
-------------------------------------------------------------------------------

-- Move active window with mainMod + SHIFT + arrow keys
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-------------------------------------------------------------------------------
-- WINDOW CYCLING -MONOCLE
-------------------------------------------------------------------------------
-- Cycle to next window
hl.bind(mainMod .. " + TAB", hl.dsp.layout("cyclenext"))

-- Cycle to previous window
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.layout("cycleprev"))


-------------------------------------------------------------------------------
-- WORKSPACES
-------------------------------------------------------------------------------

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
--
-- 1-9 = Workspaces 1-9
-- 0   = Workspace 10

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))


-------------------------------------------------------------------------------
-- SPECIAL WORKSPACE / SCRATCHPAD
-------------------------------------------------------------------------------

-- Toggle special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))

-- Move active window to special workspace
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))


-------------------------------------------------------------------------------
-- MINIMIZE WINDOWS
-------------------------------------------------------------------------------

-- Minimize windows using special workspace.
-- Note that one keybind can only handle one window.

hl.bind("SUPER + X", function ()
    if hl.get_workspace("special:minimized") then
        -- Restore minimized window
        hl.dispatch(hl.dsp.window.move({ workspace = hl.get_active_workspace(), window = "tag:minimized" }))
        hl.dispatch(hl.dsp.window.clear_tags({ window = "tag:minimized" }))
    else
        -- Move active window to minimized workspace
        hl.dispatch(hl.dsp.window.tag({ tag = "minimized", window = hl.get_active_window() }))
        hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", follow = false }))
    end
end)


-------------------------------------------------------------------------------
-- MOUSE WINDOW CONTROLS
-------------------------------------------------------------------------------

-- Move/resize windows with mainMod + LMB/RMB and dragging
--
-- mouse:272 = left click
-- Hold mainMod + left click and drag to MOVE the focused window.
--
-- mouse:273 = right click
-- Hold mainMod + right click and drag to RESIZE the focused window.

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-------------------------------------------------------------------------------
-- LAYOUTS
-------------------------------------------------------------------------------

-- Cycle layout for current workspace
--
-- SUPER + K
--
-- Order:
-- scrolling -> dwindle -> master -> monocle -> scrolling

hl.bind("SUPER + K", function ()
    local layouts = {
        scrolling = "󰕰",
        dwindle   = "󰕳",
        master    = "󰓦",
        monocle   = "󰖲",
    }

    local order = {
        "scrolling",
        "dwindle",
        "master",
        "monocle",
    }

    local workspace = hl.get_active_workspace()

    if hl.get_active_special_workspace() then
        workspace = hl.get_active_special_workspace()
    end

    if not workspace then
        return
    end

    local next_layout = "dwindle"

    for i = 1, #order do
        if order[i] == workspace.tiled_layout then
            local next_layout_idx = (i % #order) + 1
            next_layout = order[next_layout_idx]
            break
        end
    end

    if workspace.special then
        hl.workspace_rule({
            workspace = tostring(workspace.name),
            layout = next_layout
        })
    else
        hl.workspace_rule({
            workspace = tostring(workspace.id),
            layout = next_layout
        })
    end

    -- Show current layout through Quickshell notification
    hl.exec_cmd(
        "quickshell ipc -p ~/.config/hypr/OozeShell/shell.qml call -- notify show " ..
        "'Layout: " .. layouts[next_layout] .. "  " .. next_layout .. "'"
    )
end)


-------------------------------------------------------------------------------
-- QUICKSHELL
-------------------------------------------------------------------------------

-- Wallpaper selector
-- SUPER + W
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(
  "quickshell ipc -p ~/.config/quickshell/OozeShell/shell.qml call toggleWalls handle"
))

-- Monitor selector
-- Chooses which monitor displays the shell (Walls/Notify/Mpris)
-- SUPER + L
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(
  "quickshell ipc -p ~/.config/quickshell/OozeShell/shell.qml call -- monitor togglePicker"
))

-- Restart Quickshell
-- SUPER + SHIFT + P
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(
  "pkill quickshell & sleep 1 && quickshell -p ~/.config/quickshell/OozeShell/shell.qml"
))

-- Keybind Cheatsheet
-- SUPER + I
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd(
  "quickshell ipc -p ~/.config/quickshell/OozeShell/shell.qml call keybinds toggle"
))

-- Keybind Translate Shell
-- SUPER + G
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd(
  "quickshell ipc -p ~/.config/quickshell/OozeShell/shell.qml call -- lang togglePicker"
))

-------------------------------------------------------------------------------
-- SYSTEM / POWER
-------------------------------------------------------------------------------

-- Shutdown / exit
--hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

-- Custom power menu
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd(
  "~/.config/rofi/Powermenu/powermenu.sh"
))

-- Notification Center
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw" ))


-------------------------------------------------------------------------------
-- MULTIMEDIA / VOLUME
-------------------------------------------------------------------------------

-- Volume up
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })

-- Volume down
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })

-- Mute / unmute speakers
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })

-- Mute / unmute microphone
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })


-------------------------------------------------------------------------------
-- BRIGHTNESS
-------------------------------------------------------------------------------

-- Increase brightness
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })

-- Decrease brightness
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })


-------------------------------------------------------------------------------
-- MEDIA PLAYER
-------------------------------------------------------------------------------

-- Requires playerctl

-- Next track
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })

-- Pause
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

-- Play / pause
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

-- Previous track
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


-------------------------------------------------------------------------------
-- SCREENSHOTS
-- Grim + Slurp + Wl-Clipboard
-------------------------------------------------------------------------------

-- PRINT
-- Capture entire screen and copy it to the clipboard
hl.bind("PRINT", hl.dsp.exec_cmd("grim - | wl-copy"))

-- SUPER + PRINT
-- Select an area with the mouse and copy it to the clipboard
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))

-- SUPER + SHIFT + PRINT
-- Select an area, copy it to the clipboard and save it
-- to ~/Pictures/Screenshots
hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd(
    "bash -c 'mkdir -p ~/Pictures/Screenshots && file=~/Pictures/Screenshots/screenshot_$(date +%Y%m%d_%H%M%S).png && grim -g \"$(slurp)\" \"$file\" && wl-copy < \"$file\"'"
))


-------------------------------------------------------------------------------
-- CUSTOM / OPTIONAL BINDS
-------------------------------------------------------------------------------
--Nix-Search with Rofi Buscador de Apps con rofi
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("~/.local/bin/nix-rofi"))


-- local home = os.getenv("HOME")

-- Waybar theme switcher
-- hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(home .. "/.config/waybar/themes/waybar-theme-switcher.sh"))


-------------------------------------------------------------------------------
-- OPTIONAL: DISABLE BINDS
-------------------------------------------------------------------------------

-- Disable close window bind if needed
-- closeWindowBind:set_enabled(false)

-------------------------------------------------------------------------------
-- AUDIO CONTROL
-------------------------------------------------------------------------------
-- SwayOSD volume controls
-------------------------------------------------------------------------------

-- Volume up
hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("swayosd-client --output-volume raise"),
    { repeating = true }
)

-- Volume down
hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("swayosd-client --output-volume lower"),
    { repeating = true }
)

-- Toggle mute
hl.bind(
    "XF86AudioMute",
    hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle")
)




  