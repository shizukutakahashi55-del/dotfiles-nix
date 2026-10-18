-- ============================================================================
--  MODULE: autostart.lua
--
--  Contains: apps/daemons launched when Hyprland starts.
--
--  Wiki: https://wiki.hypr.land/Configuring/Basics/Autostart/
-- ============================================================================

local progs = require("modules.startup.functions.progs")

hl.on("hyprland.start", function()

    -- =========================================================================
    --  APPLICATIONS
    -- =========================================================================

    -- Terminal
    progs.start_terminal(3)


    -- =========================================================================
    --  DAEMONS
    -- =========================================================================

    -- Network applet
    hl.exec_cmd("nm-applet")

    -- Wallpaper daemon
    -- hl.exec_cmd("awww-daemon")

    -- Quickshell
    hl.exec_cmd(
        "bash ~/.config/quickshell/OozeShell/Tools/ooze-launch.sh"
    )

    -- Idle daemon
    hl.exec_cmd(
        "hypridle -c ~/.config/hypr/hypridle.conf"
    )

    -- Polkit authentication agent
    hl.exec_cmd(
        "systemctl --user start hyprpolkitagent"
    )

end)