
-- ============================================================================
--  MODULE: animations.lua
--  Contains: animations toggle, bezier curves and per-element animation config.
--
--  Hyprland 0.56+
--  Wiki: https://wiki.hypr.land/configuring/core/animations/
-- ============================================================================


-- ============================================================================
-- Global
-- ============================================================================

hl.config({
    animations = {
        enabled = true,
    },
})


-------------------------------------------------------------------------------
-- Curves
-------------------------------------------------------------------------------

hl.curve("easeOutQuint", {
    type = "bezier",
    points = {
        {0.23, 1},
        {0.32, 1}
    }
})

hl.curve("easeInOutCubic", {
    type = "bezier",
    points = {
        {0.65, 0.05},
        {0.36, 1}
    }
})

hl.curve("linear", {
    type = "bezier",
    points = {
        {0, 0},
        {1, 1}
    }
})

hl.curve("almostLinear", {
    type = "bezier",
    points = {
        {0.5, 0.5},
        {0.75, 1}
    }
})

hl.curve("quick", {
    type = "bezier",
    points = {
        {0.15, 0},
        {0.1, 1}
    }
})


-------------------------------------------------------------------------------
-- Global Animation
-------------------------------------------------------------------------------

hl.animation({
    leaf = "global",
    enabled = true,
    speed = 20,
    bezier = "default"
})


-------------------------------------------------------------------------------
-- WINDOWS
--
-- windows      → movimiento / transformación general
-- windowsIn    → apertura
-- windowsOut   → cierre
-------------------------------------------------------------------------------

hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 2.8,
    bezier = "quick",
    style = "popin 94%"
})

hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 1.5,
    bezier = "quick",
    style = "popin 94%"
})

hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 1.2,
    bezier = "quick",
    style = "popin 94%"
})


-------------------------------------------------------------------------------
-- WINDOW FADE
-------------------------------------------------------------------------------

hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 2.5,
    bezier = "quick",
})

hl.animation({
    leaf = "fadeIn",
    enabled = false,
})

hl.animation({
    leaf = "fadeOut",
    enabled = false,
})

-------------------------------------------------------------------------------
-- LAYERS
-------------------------------------------------------------------------------

hl.animation({
    leaf = "layers",
    enabled = true,
    speed = 5,
    bezier = "easeOutQuint",
    style = "popin 94%"
})

hl.animation({
    leaf = "layersIn",
    enabled = true,
    speed = 4,
    bezier = "easeOutQuint",
    style = "popin 94%"
})

hl.animation({
    leaf = "layersOut",
    enabled = true,
    speed = 3,
    bezier = "easeOutQuint",
    style = "popin 94%"
})


-------------------------------------------------------------------------------
-- LAYER FADE
-------------------------------------------------------------------------------
-- Disable to avoid ghosting / slow feeling on layer-shell surfaces.
-------------------------------------------------------------------------------

hl.animation({
    leaf = "fadeLayersIn",
    enabled = true,
    speed = 1.4,
    bezier = "linear",
})

hl.animation({
    leaf = "fadeLayersOut",
    enabled = true,
    speed = 2.3,
    bezier = "linear",
})


-------------------------------------------------------------------------------
-- WORKSPACES
-------------------------------------------------------------------------------

hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 4,
    bezier = "easeOutQuint",
    style = "slide"
})

hl.animation({
    leaf = "workspacesIn",
    enabled = true,
    speed = 4,
    bezier = "easeOutQuint",
    style = "slide"
})

hl.animation({
    leaf = "workspacesOut",
    enabled = true,
    speed = 6,
    bezier = "easeOutQuint",
    style = "slide"
})


-------------------------------------------------------------------------------
-- ZOOM
-------------------------------------------------------------------------------

hl.animation({
    leaf = "zoomFactor",
    enabled = true,
    speed = 14,
    bezier = "quick"
})
