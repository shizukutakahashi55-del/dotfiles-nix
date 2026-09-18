-- ============================================================================
--  MODULE: permissions.lua
--  Contains: hl.permission() ecosystem rules (screencopy, plugins, etc.)
--  Currently empty (all commented) -- changes here need a full Hyprland
--  restart, they are NOT applied on reload, for security reasons.
--  Wiki: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- ============================================================================

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
