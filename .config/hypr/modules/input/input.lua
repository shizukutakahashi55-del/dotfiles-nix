
-- ============================================================================
--  MODULE: input.lua
--  Contains: keyboard layout, mouse sensitivity, touchpad, trackpad gestures
--  and per-device overrides.
--  Wiki: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/
-- ============================================================================

-- ---------------
-- ---- INPUT ----
-- ---------------

hl.config({
    input = {

        kb_layout  = "us,es",
        kb_variant = "",
        kb_model   = "",
        -- El cambio de layout se maneja desde Lua
        kb_options = "grp:alt_shift_toggle",
        kb_rules   = "",
        follow_mouse = 1,
        -- -1.0 - 1.0, 0 means no modification
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

-- ----------------
-- ---- GESTURES --
-- ----------------

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})


-- -------------------------
-- ---- PER-DEVICE CONFIG --
-- -------------------------

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})
