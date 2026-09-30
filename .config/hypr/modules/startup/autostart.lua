
-- -- ============================================================================
-- --  MODULE: autostart.lua
-- --
-- --  Contains: apps/daemons launched when Hyprland starts.
-- --
-- --  Wiki: https://wiki.hypr.land/Configuring/Basics/Autostart/
-- -- ============================================================================
--
local programs = require("modules.startup.programs")

hl.on("hyprland.start", function()

    if programs and type(programs.start_terminal) == "function" then
        programs.start_terminal(3)
    end
    
    -- Daemons (arrancan YA, sin esperar los 3s de la terminal)
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("awww-daemon")
    -- hl.exec_cmd("fcitx5 -d") -- Si usas los dotfiles de NixOS esto dejalo comentado.
    hl.exec_cmd("pkill quickshell; sleep 1; quickshell -p ~/.config/quickshell/OozeShell/shell.qml")
    hl.exec_cmd("hypridle -c ~/.config/hypr/hypridle.conf")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- Swaync
    -- hl.exec_cmd("swaync")

    --SwayOSD
    -- hl.exec_cmd("swayosd-server")

    --Waybar 
    -- hl.exec_cmd("waybar -c ~/.config/waybar/config.jsonc")


end)
