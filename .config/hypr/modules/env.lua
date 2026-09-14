-- ============================================================================
--  MODULE: env.lua
--  Contains: environment variables (cursor size, Nvidia vars, etc.)
--  Wiki: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
-- ============================================================================

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Nvidia Variables
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
