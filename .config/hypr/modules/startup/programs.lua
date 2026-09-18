-- ============================================================================
--  MODULE: programs.lua
--  Contains: the apps you use (terminal, file manager, launcher).
--  Returns a table so keybinds.lua / autostart.lua can require() it and
--  reuse the same values instead of redefining them.
-- ============================================================================

---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local programs = {
    terminal    = "kitty",
    fileManager = "dolphin",
    menu        = "~/.config/rofi/Launcher/launcher.sh",
}

-- yazi = kitty --class yazi yazi
return programs
