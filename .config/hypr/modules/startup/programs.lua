
-- ============================================================================
--  MODULE: programs.lua
--
--  Contains: applications used by keybinds and autostart.
-- ============================================================================


-- ============================================================================
--  HELPERS
-- ============================================================================

local function command_exists(command)
    -- io.popen captura stdout; si devuelve algo el comando existes.
    local handle = io.popen("command -v " .. command .. " 2>/dev/null")
    if not handle then return false end
    local result = handle:read("*a")
    handle:close()
    return result ~= nil and result ~=""
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
    terminal = terminal or "ghostty",
    -- Launcher
    menu = "quickshell ipc -p ~/.config/quickshell/OozeShell/shell.qml call -- launcher toggle",
    -- Legacy Launcher
    -- menu = "~/.config/rofi/Launcher/launcher.sh",
    
    -- File manager
    -- fileManager = (terminal or "ghostty") .. " -e yazi",
    fileManager = "dolphin",
}


-- ============================================================================
--  AUTOSTART TERMINAL
-- ============================================================================

--- Lanza la terminal detectada tras un retraso (no bloqueante).
--- @param delay number|nil Segundos a esperar antes de lanzar (default: 3)
function programs.start_terminal(delay)
    if not terminal then return end

    delay = delay or 2

    if delay > 0 then
        hl.exec_cmd("sh -c 'sleep " .. tostring(delay) .. " && setsid -f " .. terminal .. "'")
    else
        hl.exec_cmd("setsid -f " .. terminal)
    end
end
-- ============================================================================
--  RETURN
-- ============================================================================

return programs

