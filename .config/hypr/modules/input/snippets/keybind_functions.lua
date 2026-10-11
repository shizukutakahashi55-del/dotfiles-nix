-- ============================================================================
--  MODULE: keybind_functions.lua
--  Contains: Lua functions used by keybinds.lua.
--  Keybind declarations themselves remain in keybinds.lua.
-- ============================================================================

local loader = require("modules.appearance.loader")
local theme  = loader.load("theme", loader.defaults.theme)
local layouta = loader.load("layouta", loader.defaults.layouta)

local M = {}

-------------------------------------------------------------------------------
-- PER LAYOUT BINDS
-------------------------------------------------------------------------------

        function M.layout_bind(bind_table)
            return function ()
                local workspace = hl.get_active_special_workspace() or
                                hl.get_active_workspace()

                if not workspace then
                    return
                end

                local layout = workspace.tiled_layout

            if bind_table[layout] then
                    hl.dispatch(bind_table[layout])
                end
            end
        end

-------------------------------------------------------------------------------
-- CODING WORKSPACE TOGGLE
-------------------------------------------------------------------------------

 -- CODING WORKSPACE TOGGLE

-- Coding Space Toggle
local codingWorkspace = false

local normalCoding = {
    workspace = "1",
    no_rounding = false,
    no_border = false,
    gaps_in = theme.gaps_in,
    gaps_out = theme.gaps_out,
    layout = layouta.layout,
}

local codingEnabled = {
    
    workspace = "1",
    no_rounding = true,
    no_border = true,
    gaps_in = 0,
    gaps_out = 0,
    layout = "dwindle",
}
-- Coding Space Toggle
function M.toggleCodingWorkspace()

    codingWorkspace = not codingWorkspace
    if codingWorkspace then
        hl.workspace_rule(codingEnabled)
        hl.exec_cmd('notify-send -i vscode "Coding Workspace" "ON 💻"')
    else
        hl.workspace_rule(normalCoding)
        hl.exec_cmd('notify-send -i vscode "Coding Workspace" "OFF 🏠"')
    end
end
-------------------------------------------------------------------------------
-- WINDOW FOCUS
-------------------------------------------------------------------------------

function M.toggleTiledFloatingFocus()
    local window = hl.get_active_window()
    if not window then
        return
    end

    hl.dispatch(hl.dsp.window.cycle_next({
        floating = not window.floating
    }))
end

-------------------------------------------------------------------------------
-- MOVE ALL WINDOWS IN CURRENT WORKSPACE
-------------------------------------------------------------------------------

function M.moveWindowsCurrentWorkspace(ws, f)
    local cws = hl.get_active_workspace()
    local windows = hl.get_windows({ workspace = cws })

    for _,w in pairs(windows) do
        hl.dispatch(
            hl.dsp.window.move({
                window = w ,
                workspace = ws ,
                follow = f
            })
        )
    end
end

-------------------------------------------------------------------------------
-- MINIMIZE WINDOWS
-------------------------------------------------------------------------------

function M.toggleMinimizedWindow()
    if hl.get_workspace("special:minimized") then
        -- Restore minimized window
        hl.dispatch(hl.dsp.window.move({ workspace = hl.get_active_workspace(), window = "tag:minimized" }))
        hl.dispatch(hl.dsp.window.clear_tags({ window = "tag:minimized" }))
    else
        -- Move active window to minimized workspace
        hl.dispatch(hl.dsp.window.tag({ tag = "minimized", window = hl.get_active_window() }))
        hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", follow = false }))
    end
end
-------------------------------------------------------------------------------
-- OSD HELPER
-------------------------------------------------------------------------------

local QS_CONFIG = os.getenv("HOME") .. "/.config/quickshell/OozeShell"

-- Escapa para shell con comillas simples
local function sh(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- osd("icono", "Título", "Subtítulo", activo?)
function M.osd(icon, title, subtitle, active)
    hl.exec_cmd(
        "quickshell ipc -p " .. sh(QS_CONFIG) .. " call -- osd show " ..
        sh(icon) .. " " .. sh(title) .. " " .. sh(subtitle) .. " " ..
        (active and "true" or "false")
    )
end

-------------------------------------------------------------------------------
-- HYPRSUNSET
-------------------------------------------------------------------------------

function M.toggleHyprsunset()
    return hl.dsp.exec_cmd([[
        osd() { quickshell ipc -p "$HOME/.config/quickshell/OozeShell" call -- osd show "$1" "$2" "$3" "$4"; }
        if pgrep -x hyprsunset >/dev/null; then
            pkill -x hyprsunset
            osd "󰖔" "Hyprsunset" "OFF" false
        else
            hyprsunset & disown
            osd "󰖙" "Hyprsunset" "ON" true
        fi
    ]])
end

-------------------------------------------------------------------------------
-- LAYOUT CYCLE
-------------------------------------------------------------------------------

function M.cycleLayout()
    local ok, err = pcall(function ()
        local layouts = {
            scrolling = "󰕰",
            dwindle   = "󰕳",
            master    = "󰓦",
            monocle   = "󰖲",
        }
        local order = { "scrolling", "dwindle", "master", "monocle" }

        local workspace = hl.get_active_workspace()
        if hl.get_active_special_workspace() then
            workspace = hl.get_active_special_workspace()
        end
        if not workspace then
            return
        end

        local next_layout = "dwindle"
        for i = 1, #order do
            if order[i] == workspace.tiled_layout then
                next_layout = order[(i % #order) + 1]
                break
            end
        end

        if workspace.special then
            hl.workspace_rule({ workspace = tostring(workspace.name), layout = next_layout })
        else
            hl.workspace_rule({ workspace = tostring(workspace.id), layout = next_layout })
        end

        hl.exec_cmd(
            'quickshell ipc -p "$HOME/.config/quickshell/OozeShell" call -- osd show "' ..
            layouts[next_layout] .. '" "Layout" "' .. next_layout .. '" true'
        )
    end)

    if not ok then
        hl.exec_cmd("notify-send -u critical 'Error en SUPER+K' '" .. tostring(err):gsub("'", "") .. "'")
    end
end
return M
