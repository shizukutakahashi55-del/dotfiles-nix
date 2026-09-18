-- ============================================================================
--  MODULE: windowrules.lua
--  Contains: window rules and layer rules.
--  Wiki:
--    https://wiki.hypr.land/Configuring/Basics/Window-Rules/
--    https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- ============================================================================

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- MY WINDOW RULES

------Dolphin Opacity--
-- Reglas de ventana para menús y popups de Dolphin / Qt
-- ============================================================================
--  MODULE: windowrules.lua / layer rules
-- ============================================================================

-- 1. Reglas de capa (Layer Rules) para menús de Qt / Dolphin
-- Documentación: https://wiki.hypr.land/Configuring/Keywords/#layer-rules
-- ============================================================================
--  MODULE: windowrules.lua / layer rules
-- ============================================================================

-- 1. Capa para desenfocar los menús contextuales de Qt (clic derecho)
hl.layer_rule({
    "blur, qt-menu",
    "ignorezero, qt-menu",
})

-- 2. Reglas de ventana para Dolphin
hl.window_rule({
    -- Opacidad en la ventana principal de Dolphin para translucidez y blur
    "opacity 0.90 0.85, class:^(org.kde.dolphin)$",

    -- Regla para menús flotantes/popups de Dolphin que no tienen título
    "opacity 0.85 0.80, class:^(org.kde.dolphin)$, title:^()$",

    -- Quitar animación a las ventanas emergentes del menú contextual
    "noanim, class:^(org.kde.dolphin)$, title:^()$",
})

-- WORKSPACE RULES
-- (workspace_rule calls live in modules/layouts.lua, next to the layout
-- config they assign a layout for)


-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
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

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})
