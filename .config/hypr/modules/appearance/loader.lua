local M = {}

local base = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config"))
    .. "/hypr/modules/appearance/autogen/"

local function copy(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = copy(v) end
    return r
end

local function merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            merge(dst[k], v)
        else
            dst[k] = v
        end
    end
    return dst
end

-- Lee el archivo desde disco cada vez (sin caché).
-- Si falta, está corrupto o da error, devuelve los valores por defecto.
function M.load(name, defaults)
    local result = copy(defaults)
    local chunk = loadfile(base .. name .. ".lua")
    if not chunk then return result end
    local ok, data = pcall(chunk)
    if ok and type(data) == "table" then
        merge(result, data)
    end
    return result
end

M.defaults = {
    theme = {
        gaps_in = 3, gaps_out = 6, border_size = 0,
        rounding = 6, rounding_power = 5,
        active_opacity = 1, inactive_opacity = 1,
        animations = true,
        blur   = { enabled = true, size = 2, passes = 2 },
        shadow = { enabled = false, range = 0, render_power = 1 },
    },
    layouta = { layout = "scrolling" },
    animprofile = { profile = "smooth" },

}

return M