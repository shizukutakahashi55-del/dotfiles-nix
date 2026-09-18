-- ============================================================================
--  MODULE: env.lua
--  Contains: environment variables (cursor size, Nvidia vars, etc.)
--  Wiki: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
-- ============================================================================

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------------------------------------------------
---- Nvidia Variables -------------------------------------------
-----------------------------------------------------------------
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-----------------------------------------------------------------
---- Qt: Use Wayland if available, fall back to X11 if not. -----
-----------------------------------------------------------------
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

-----------------------------------------------------------------
---- Tells Qt based applications to pick your theme from qt6ct.--
-----------------------------------------------------------------
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-----------------------------------------------------------------
---- Native Wayland Support for Electron Apps -------------------
-----------------------------------------------------------------
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")