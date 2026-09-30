-- ============================================================================
--  MODULE: monitors.lua
--  Contains: monitor outputs (mode, position, scale, mirroring).
--  Wiki: https://wiki.hypr.land/Configuring/Basics/Monitors/
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
    -- mirror   = "HDMI-A-1"
})

hl.monitor({
    output    = "HDMI-A-1",
    mode      = "preferred",
    position  = "auto",
    scale     = "auto",
    transform = 0, -- 1 = 90° (Vertical), 3 = 270° (Vertical invertido)
})