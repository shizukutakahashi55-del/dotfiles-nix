-- ============================================================================
--  MODULE: animations.lua
--  Modifica animaciones bajo tu responsabilidad.
--  Contains: animations toggle, bezier curves and per-element animation config.
--  Hyprland 0.56+
--  Wiki: https://wiki.hypr.land/configuring/core/animations/
-- ============================================================================
-- appearance.lua y animations.lua

local loader = require("modules.appearance.loader")
local theme  = loader.load("theme", loader.defaults.theme)
local anim   = loader.load("animprofile", loader.defaults.animprofile)

-- ============================================================================
--  PERFILES DE ANIMACIÓN
--  Cambia solo esta línea para alternar el estilo global:
--
--    "smooth"       → deslizamiento elegante (slide + easeOutQuint)
--    "snappy"       → rápido y responsivo (popin + quick)
--    "playful"      → rebote tipo gnome (gnomed + almostLinear)
--    "minimal"      → casi sin animación, solo fades
--    "dramatic"     → lento y marcado
--    "dramatic_side"→ lento y marcado con slide fade
-- ============================================================================

local PERFIL = "anim.profile" -- Elige tu estilo

local perfiles = {
    smooth = {
        windows     = { style = "slide",      bezier = "easeOutQuint", speed = 4.0 },
        windowsIn   = { style = "slide",      bezier = "easeOutQuint", speed = 3.5 },
        windowsOut  = { style = "slide",      bezier = "easeOutQuint", speed = 3.0 },
        layers      = { style = "slide",      bezier = "easeOutQuint", speed = 5.0 },
        workspaces  = { style = "slide",      bezier = "easeOutQuint", speed = 4.0 },
        zoom        = 8,
    },
    snappy = {
        windows     = { style = "popin 94%",  bezier = "quick",         speed = 2.8 },
        windowsIn   = { style = "popin 94%",  bezier = "quick",         speed = 2.5 },
        windowsOut  = { style = "popin 94%",  bezier = "quick",         speed = 2.3 },
        layers      = { style = "popin 94%",  bezier = "quick",         speed = 4.0 },
        workspaces  = { style = "slide",      bezier = "quick",         speed = 3.0 },
        zoom        = 6,
    },
    playful = {
        windows     = { style = "gnomed",     bezier = "almostLinear",  speed = 3.5 },
        windowsIn   = { style = "gnomed",     bezier = "almostLinear",  speed = 3.0 },
        windowsOut  = { style = "gnomed",     bezier = "almostLinear",  speed = 2.5 },
        layers      = { style = "popin 94%",  bezier = "almostLinear",  speed = 4.0 },
        workspaces  = { style = "slidevert",  bezier = "almostLinear",  speed = 3.0 },
        zoom        = 10,
    },
    minimal = {
        windows     = { style = "popin 100%", bezier = "linear",        speed = 1.5 },
        windowsIn   = { style = "popin 100%", bezier = "linear",        speed = 1.5 },
        windowsOut  = { style = "popin 100%", bezier = "linear",        speed = 1.5 },
        layers      = { style = "popin 100%", bezier = "linear",        speed = 2.0 },
        workspaces  = { style = "slide",      bezier = "linear",        speed = 2.0 },
        zoom        = 3,
    },
    dramatic = {
        windows     = { style = "slide",         bezier = "easeInOutCubic", speed = 5.0 },
        windowsIn   = { style = "popin 94%",     bezier = "easeInOutCubic", speed = 4.5 },
        windowsOut  = { style = "popin 94%",     bezier = "easeInOutCubic", speed = 4.0 },
        layers      = { style = "popin 94%",     bezier = "easeInOutCubic", speed = 5.0 },
        workspaces  = { style = "slide",         bezier = "easeInOutCubic", speed = 4.5 },
        zoom        = 8,
    },
    dramatic_side = {
        windows     = { style = "slide right",  bezier = "easeInOutCubic", speed = 5.0 },
        windowsIn   = { style = "popin 90%",     bezier = "easeInOutCubic", speed = 4.5 },
        windowsOut  = { style = "popin 90%",     bezier = "easeInOutCubic", speed = 4.0 },
        layers      = { style = "popin 94%",     bezier = "easeInOutCubic", speed = 5.0 },
        workspaces  = { style = "slidefade 25%", bezier = "easeInOutCubic", speed = 4.5 },
        zoom        = 8,
    },
}

local cfg = perfiles[PERFIL] or perfiles.smooth

-- ============================================================================
-- Global
-- ============================================================================

hl.config({
    animations = {
        enabled = theme.animations,
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
    speed = 6,
    bezier = "default"
})


-------------------------------------------------------------------------------
-- BORDER
--
-- Para cambio de color, evita bugs, asi como al cambiar 
-- posicion y bblah blah blah.
-------------------------------------------------------------------------------

hl.animation({
    leaf = "border",
    enabled = true,
    speed = 4,
    bezier = "easeOutQuint"
})


-------------------------------------------------------------------------------
-- WINDOWS
--
-- windows      → movimiento / transformación general
-- windowsIn    → apertura
-- windowsOut   → cierre
--
-- El estilo y bezier vienen del PERFIL seleccionado arriba.
-------------------------------------------------------------------------------

hl.animation({
    leaf = "windows",
    enabled = true,
    speed = cfg.windows.speed,
    bezier = cfg.windows.bezier,
    style = cfg.windows.style
})

hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = cfg.windowsIn.speed,
    bezier = cfg.windowsIn.bezier,
    style = cfg.windowsIn.style
})

hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = cfg.windowsOut.speed,
    bezier = cfg.windowsOut.bezier,
    style = cfg.windowsOut.style
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
    bezier = "quick",
    speed = 1.5,
    enabled = false,
})

hl.animation({
    leaf = "fadeOut",
    bezier = "quick",
    speed = 1.5,
    enabled = true,
})

-------------------------------------------------------------------------------
-- LAYERS
--
-- layers     → movimiento general
-- layersIn   → apertura
-- layersOut  → cierre
-------------------------------------------------------------------------------

hl.animation({
    leaf = "layers",
    enabled = true,
    speed = cfg.layers.speed,
    bezier = cfg.layers.bezier,
    style = cfg.layers.style
})

hl.animation({
    leaf = "layersIn",
    enabled = true,
    speed = cfg.layers.speed,
    bezier = cfg.layers.bezier,
    style = cfg.layers.style
})

hl.animation({
    leaf = "layersOut",
    enabled = true,
    speed = cfg.layers.speed,
    bezier = cfg.layers.bezier,
    style = cfg.layers.style
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
    speed = cfg.workspaces.speed,
    bezier = cfg.workspaces.bezier,
    style = cfg.workspaces.style
})

hl.animation({
    leaf = "workspacesIn",
    enabled = true,
    speed = cfg.workspaces.speed,
    bezier = cfg.workspaces.bezier,
    style = "slidevert"
})

hl.animation({
    leaf = "workspacesOut",
    enabled = true,
    speed = cfg.workspaces.speed,
    bezier = cfg.workspaces.bezier,
    style = "slidevert"
})


-------------------------------------------------------------------------------
-- ZOOM
-------------------------------------------------------------------------------

hl.animation({
    leaf = "zoomFactor",
    enabled = true,
    speed = cfg.zoom,
    bezier = "quick"
})