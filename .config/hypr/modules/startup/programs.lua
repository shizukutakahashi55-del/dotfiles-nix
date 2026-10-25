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

-- Base de todos los IPC de OozeShell (exec_cmd corre en un shell: ~ se expande)
local QS = "quickshell ipc -p ~/.config/quickshell/OozeShell/shell.qml call -- "

local programs = {

    -- Binario de la terminal detectada (lo usa functions/progs.lua en el arranque)
    terminal = terminal,
    -- fileManager = "dolphin",
    -- browser     = "brave",

    -- Apps por rol: el shell resuelve la app elegida en Ajustes -> Apps predeterminadas
    terminalIpc = QS .. "apps open terminal",
    browser     = QS .. "apps open browser",
    fileManager = QS .. "apps open files",

    -- Launcher
    menu = QS .. "launcher toggle",
}


-- ============================================================================
--  RETURN
-- ============================================================================

return programs
