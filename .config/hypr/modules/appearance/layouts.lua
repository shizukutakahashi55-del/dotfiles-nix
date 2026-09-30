-- ============================================================================
--  MODULE: layouts.lua
--  Contains: Dwindle / Master / Scrolling layout options, the commented
--  "smart gaps" recipe, and the workspace_rule loop that assigns the
--  scrolling layout to workspaces 1-10.
--  Wiki:
--    https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
--    https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/
--    https://wiki.hypr.land/Configuring/Layouts/Master-Layout/
--    https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- ============================================================================

-- Se recarga siempre desde disco (require cachea el módulo y, tras un
-- reload de Hyprland, podría quedarse con el valor viejo)
-- layouts.lua (ya no necesitas el package.loaded = nil)
local loader  = require("modules.appearance.loader")
local layouta = loader.load("layouta", loader.defaults.layouta)
-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
        smart_split    = false,
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
        mfact      = 0.55,
        smart_resizing = true,
        focus_master_on_close = true,
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
        column_width             = 0.5,
        focus_fit_method         = 1,
    },
})

-- -- -- -- -- -- --
-- Actual Layout  --
-- -- -- -- -- -- --

for i = 1, 10 do
    hl.workspace_rule({
        workspace = tostring(i),
        layout = layouta.layout, 
    })
end
