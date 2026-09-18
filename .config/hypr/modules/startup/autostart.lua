-- ============================================================================
--  MODULE: autostart.lua
--  Contains: apps/daemons launched when Hyprland starts.
--  Currently empty (just the commented example) -- fill in as needed.
--  Wiki: https://wiki.hypr.land/Configuring/Basics/Autostart/
-- ============================================================================
-- local programs = require("modules.programs")
-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
-- local programs = require("modules.programs")
hl.on("hyprland.start", function()

    -- Core

    --hl.exec_cmd(kitty)
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("waybar")

    --hl.exec_cmd("swaync")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("swayosd-server")
    
    -- OozeShell
    hl.exec_cmd("sleep 1 && quickshell -p ~/.config/quickshell/OozeShell/shell.qml")

    -- Hypridle
    hl.exec_cmd("hypridle -c ~/.config/hypr/hypridle.conf")

    -- Applications
    --hl.exec_cmd("sleep 3 && steam")
    --hl.exec_cmd("sleep 6 && discord")

    -- Authentication
    hl.exec_cmd("systemctl --user start plasma-polkit-agent")

end)