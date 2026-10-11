-- ============================================================================
--  MODULE: progs.lua
--
--  Contains: functions for launching and controlling programs.
-- ============================================================================

local programs = require("modules.startup.programs")

local M = {}


-- ============================================================================
--  TERMINAL
-- ============================================================================

--- Lanza la terminal detectada con delay.
--- @param delay number|nil Segundos a esperar antes de lanzar (default: 3)
function M.start_terminal(delay)
    if not programs.terminal then
        return
    end

    delay = delay or 3

    if delay > 0 then
        hl.exec_cmd(
            "sh -c 'sleep "
                .. tostring(delay)
                .. " && setsid -f "
                .. programs.terminal
                .. "'"
        )
    else
        hl.exec_cmd("setsid -f " .. programs.terminal)
    end
end


-- ============================================================================
--  RETURN
-- ============================================================================

return M