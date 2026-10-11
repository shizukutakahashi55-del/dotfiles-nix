-- ============================================================================
--  MODULE: monitors.lua
--  Contains: monitor outputs (mode, position, scale, mirroring).
-- ============================================================================

------------------
---- MONITORS ----
------------------
-- Before apply this you may look for your monitor name
-- Run this "hyprctl monitors show"
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "DP-3",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",

})

hl.monitor({
    output    = "HDMI-A-1",
    mode      = "preferred",
    position  = "auto",
    scale     = "auto",
})