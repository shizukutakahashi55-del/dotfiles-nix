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

--Rofi transparent alpha blur
-- Enable blur and ignore_alpha for Rofi
hl.layer_rule({
  match        = { namespace = "rofi" },
  blur         = true,
  ignore_alpha = 0.3,
})

-- OozeShell Configs
hl.layer_rule({
  match     = { namespace = "quickshell-dock" },
  no_anim   = true,
  blur         = true,
  ignore_alpha = 0.3,
  xray         = false,
})

hl.layer_rule({
  match        = { namespace = "oozeshell-widget-.*" },
  no_anim      = true,
  blur         = true,
  ignore_alpha = 0.5,
})

-- 0ozeShell Experimental
local OozeCrystal = hl.layer_rule({
  name  = "OozeCrystal",
  match = { namespace = "oozeshell-.*" },
  no_anim  = true,
})
OozeCrystal:set_enabled(false)



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
hl.window_rule({
    name = "brave-window-float",
    match = { class = "^(brave-browser)$", title = "^(Untitled - Brave)$" },
    float = true,
    border_size = 1,
    size = {590, 800}
})

--------------------------------------------------
-- STEAM RULES -----------------------------------
--------------------------------------------------
-- Steam NO float.
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
-- Personal GameRule 
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

-- Personal Rules.
-- Ghostty rules
hl.window_rule({
  match = { class = "^com.mitchellh.ghostty$"},
  border_size = 0,
})

-- No Share for LibreWolf
hl.window_rule({
    match = {
        class = "^(?i:librewolf)$"},
    no_screen_share = true
})




-- ============================================================================
--  WORKSPACE RULES ----------------------------------------------
-- ============================================================================

-- WORKSPACE BY MONITOR----------------------------------------
-- ── Monitor HDMI-A-1 (Workspaces 1 to 5) ────────────────────
-- for i = 1, 5 do
--   hl.workspace_rule({
--     workspace = tostring(i),
--     monitor = "HDMI-A-1",
--     default = (i == 1) -- Sets Workspace 1 as default
--   })
-- end
-- -- ── Monitor DP-3 (Workspaces 6 al 10) ────────────────────────
-- for i = 6, 10 do
--   hl.workspace_rule({
--     workspace = tostring(i),
--     monitor = "DP-3",
--     default = (i == 6) -- Sets Workspace 6 as default
--   })
-- end

-- =================================
-- Workspace Coding Rename
-- =================================
hl.dispatch(hl.dsp.workspace.rename({
    workspace = "1",  
    name = "Coding", 
}))


------------------------------------------------------------
-- ── LAYOUTS ON WORKSPACES   ────────────────────────────────────────
------------------------------------------------------------

-- Examples for Layouts by Workspaces with tostring

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
--     layout = "Master"
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

