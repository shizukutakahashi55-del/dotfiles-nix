-- ============================================================================
--  MODULE: programs.lua
--
--  Contains: applications used by keybinds and other modules.
-- ============================================================================


-- ============================================================================
--  HELPERS
-- ============================================================================

local function command_exists(command)
    local handle = io.popen("command -v " .. command .. " 2>/dev/null")

    if not handle then
        return false
    end

    local result = handle:read("*a")
    handle:close()

    return result ~= nil and result ~= ""
end


-- ============================================================================
--  TERMINAL
-- ============================================================================

local function find_terminal()
    local terminals = {
        "foot",
        "ghostty",
        "kitty",
        "wezterm",
        "alacritty",
        "xterm",
    }

    for _, terminal in ipairs(terminals) do
        if command_exists(terminal) then
            return terminal
        end
    end

    return nil
end


-- ============================================================================
--  PROGRAMS
-- ============================================================================

local terminal = find_terminal()

local programs = {

    -- Detected terminal
    terminal = terminal,

    -- Launcher
    menu = "quickshell ipc -p ~/.config/quickshell/OozeShell/shell.qml call -- launcher toggle",

    -- File manager
    -- fileManager = (terminal) .. " -e yazi",
     fileManager = "dolphin",
}


-- ============================================================================
--  RETURN
-- ============================================================================

return programs
