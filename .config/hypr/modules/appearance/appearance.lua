-- ============================================================================
--  MODULE: appearance.lua
-- ============================================================================

-- appearance.lua y animations.lua
local colors = require("modules.appearance.colors")   -- esta se queda son los colores automaticos.  No cambiar estas lineas.
local loader = require("modules.appearance.loader")
local theme  = loader.load("theme", loader.defaults.theme)

hl.config({
    general = {
        gaps_in  = theme.gaps_in,
        gaps_out = theme.gaps_out,
        border_size = theme.border_size,
        
        col = {
            active_border         = { colors = { colors.primary, colors.tertiary }, angle = 45 },
            inactive_border       = colors.outline,
            nogroup_border        = colors.error,
            nogroup_border_active = colors.error_cnt,
        },
        resize_on_border = false,
        allow_tearing    = false,

    },
    decoration = {
        rounding = theme.rounding,
        rounding_power = theme.rounding_power,
        active_opacity   = theme.active_opacity,
        inactive_opacity = theme.inactive_opacity,

        shadow = {
            enabled      = theme.shadow.enabled,
            range        = theme.shadow.range,
            render_power = theme.shadow.render_power,
            color        = 0xee1a1a1a,
        },
        blur = {
            enabled = theme.blur.enabled,
            size    = theme.blur.size,
            passes  = theme.blur.passes,
            vibrancy  = 0.1696,
        },
    },
})