-- ============================================================================
--  MODULE: appearance.lua
-- ============================================================================

local colors = require("modules.colors")

hl.config({
    general = {
        gaps_in  = 3,
        gaps_out = 6,

        border_size = 2,

        col = {
            active_border         = { colors = { colors.primary, colors.tertiary }, angle = 45 },
            inactive_border       = colors.outline,
            nogroup_border        = colors.error,
            nogroup_border_active = colors.error_cnt,
        },

        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 5,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = false,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
        },
    },
})