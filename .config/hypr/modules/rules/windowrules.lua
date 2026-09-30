-- ============================================================================
--  MODULE: windowrules.lua
--  Contains: window rules and layer rules.
--  Wiki:
--    https://wiki.hypr.land/configuring/core/rules/window-rules/
--    https://wiki.hypr.land/configuring/core/rules/workspace-rules/
--    https://wiki.hypr.land/configuring/core/rules/layer-rules/
-- ============================================================================

-- ============================================================================
--  LAYER RULES
-- ============================================================================

-- Contextual menu blur Qt
hl.layer_rule({
    "blur, qt-menu",
    "ignorezero, qt-menu",
})

--Rofi transparent alpha blur
-- Enable blur and ignore_alpha for Rofi
hl.layer_rule({
  match        = { namespace = "rofi" },
  blur         = true,
  ignore_alpha = 0.3,
})

-- Animaciones en quickshell
hl.layer_rule({
  match        = { namespace = "oozeshell" },
  no_anim      = true,
  
})
-- ============================================================================
--WINDOW RULES -------------------------------------------------
-- ============================================================================

-------------------------------------------------------------
--  SMART GAPS ----------------------------------------------
-------------------------------------------------------------

-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.

-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })

-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

--------------------------------------------------
-- BROWSERS-RULES --------------------------------
--------------------------------------------------


--------------------------------------------------
-- STEAM RULES -----------------------------------
--------------------------------------------------
-- Steam NO float
hl.window_rule({
    name = "steam-tile",
    match = { class = "^(steam)$", title = "^(Steam)$" },
    float = false,
})

-- Force other Steam windows (Friends, Settings) to float
hl.window_rule({
    name = "steam-float",
    match = { class = "^(steam)$", title = "negative:^(Steam)$" },
    float = true,
    no_anim = true,
    no_blur = true,
    border_size = 0,
})

--------------------------------------------------
-- GAME-RULES ------------------------------------
--------------------------------------------------

-- Tohou Fuujinroku
hl.window_rule({
  match = { class = "^th10tr.exe$", title = ".*(“Œ•û•—_˜^@` Mountain of Faith. ver 0.02a).*" },
  float = true,
  no_anim = true,
  no_blur = true,
  border_size = 0,
  fullscreen = false,
})


--------------------------------------------------
-- GENERAL-RULES ---------------------------------
--------------------------------------------------

-- Ghostty rules
hl.window_rule({
  match = { class = "^com.mitchellh.ghostty$"},
  border_size = 0,
  
})

-- Codium rule
hl.window_rule({
  match = { class = "^codium$"},
  border_size = 0,
  
})

-- ============================================================================
--  WORKSPACE RULES ----------------------------------------------
-- ============================================================================

-- -- Coding Space
-- hl.workspace_rule({ 
--     workspace = "1", 
--     no_rounding = true,
--     no_border = true,
--     gaps_in = 1,
--     gaps_out = 1, 
--     monitor = "HDMI-A-1",
--     default_name = "Coding",
--     layout = "dwindle",
--   })

-- WORKSPACE BY MONITOR----------------------------------------
-- ── Monitor HDMI-A-1 (Workspaces 1 to 5) ────────────────────
for i = 1, 5 do
  hl.workspace_rule({
    workspace = tostring(i),
    monitor = "HDMI-A-1",
    default = (i == 1) -- Sets Workspace 1 as default
  })
end
-- ── Monitor DP-3 (Workspaces 6 al 10) ────────────────────────
for i = 6, 10 do
  hl.workspace_rule({
    workspace = tostring(i),
    monitor = "DP-3",
    default = (i == 6) -- Sets Workspace 6 as default
  })
end

------------------------------------------------------------
-- ── LAYOUTS ON WORKSPACES   ────────────────────────────────────────
------------------------------------------------------------

-- -- Workspaces Dwindle -----------------------------------
-- for i = 3, 6 do
--   hl.workspace_rule({
--     workspace = tostring(i),
--     layout = "dwindle"
--   })
-- end

-- -- Workspaces Master -------------------------------------
-- for i = 7, 10 do
--   hl.workspace_rule({
--     workspace = tostring(i),
--     layout = "dwindle"
--   })
-- end

-- Workspace individual layouts ------------------------------

-- hl.workspace_rule({ workspace = "2", layout = "scrolling" })
-- hl.workspace_rule({ workspace = "3", layout = "dwindle" })

-- ============================================================================
--  DEFAULT-RULES ----------------------------------------------
-- ============================================================================

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

-- Fix some dragging issues with XWayland
hl.window_rule({   
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

