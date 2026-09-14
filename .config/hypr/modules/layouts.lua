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

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
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

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

-- -- -- -- -- -- --
-- Actual Layout  --
-- -- -- -- -- -- --

for i = 1, 10 do
    hl.workspace_rule({
        workspace = tostring(i),
        layout = "scrolling", -- You can add WORKSPACES rules for other workspaces, with other Layouts.
    })
-- EXAMPLE OF ANOTHER LAYOUTS workspace-rules -

-- hl.workspace_rule({ workspace = "2", layout = "Dwindle" })

end
