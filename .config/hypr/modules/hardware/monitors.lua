-- ============================================================================
--  MODULE: monitors.lua
--  Contains: monitor outputs (mode, position, scale, mirroring).
--  Wiki: https://wiki.hypr.land/Configuring/Basics/Monitors/
-- ============================================================================

------------------
---- MONITORS ----
------------------

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
    transform = 0, -- 1 = 90° (Vertical), 3 = 270° (Vertical invertido)
})