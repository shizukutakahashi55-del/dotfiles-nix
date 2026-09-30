local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

-- ============================================================
-- WezTerm — OozeSoft 🌸
-- ============================================================

-- ── Fuente ──────────────────────────────────────────────────

config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 12.0
config.line_height = 1.0

-- ── Ventana ─────────────────────────────────────────────────

config.window_padding = {
    left = 12,
    right = 12,
    top = 12,
    bottom = 12,
}

config.window_background_opacity = 0.75
config.window_decorations = "NONE"

config.hide_mouse_cursor_when_typing = true
config.adjust_window_size_when_changing_font_size = false

-- ── Tabs ────────────────────────────────────────────────────

config.enable_tab_bar = false

-- ── Cursor ─────────────────────────────────────────────────

config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 500

-- ── Scrollback ─────────────────────────────────────────────

config.scrollback_lines = 10000

-- ── Shell ──────────────────────────────────────────────────

config.default_prog = {
    "/etc/profiles/per-user/oozenix/bin/zsh",
    "-l",
}

-- ── Renderizado ────────────────────────────────────────────

config.front_end = "WebGpu"
config.animation_fps = 60

-- ── Mouse ──────────────────────────────────────────────────

config.mouse_bindings = {
    {
        event = {
            Down = {
                streak = 1,
                button = "Right",
            },
        },
        mods = "NONE",
        action = act.PasteFrom("Clipboard"),
    },
}

-- ============================================================
-- Keybindings
-- ============================================================

config.keys = {

    -- ── Cerrar pane ─────────────────────────────────────────

    {
        key = "q",
        mods = "CTRL|SHIFT",
        action = act.CloseCurrentPane {
            confirm = false,
        },
    },

    -- ── Nueva ventana ──────────────────────────────────────

    {
        key = "Enter",
        mods = "CTRL|SHIFT",
        action = act.SpawnWindow,
    },

    -- ── Split horizontal ───────────────────────────────────

    {
        key = "d",
        mods = "CTRL|SHIFT",
        action = act.SplitHorizontal {
            domain = "CurrentPaneDomain",
        },
    },

    -- ── Split vertical ─────────────────────────────────────

    {
        key = "r",
        mods = "CTRL|SHIFT",
        action = act.SplitVertical {
            domain = "CurrentPaneDomain",
        },
    },

    -- ── Navegar entre panes ────────────────────────────────

    {
        key = "h",
        mods = "CTRL|SHIFT",
        action = act.ActivatePaneDirection("Left"),
    },

    {
        key = "j",
        mods = "CTRL|SHIFT",
        action = act.ActivatePaneDirection("Down"),
    },

    {
        key = "k",
        mods = "CTRL|SHIFT",
        action = act.ActivatePaneDirection("Up"),
    },

    {
        key = "l",
        mods = "CTRL|SHIFT",
        action = act.ActivatePaneDirection("Right"),
    },

    -- ── Redimensionar ──────────────────────────────────────

    {
        key = "h",
        mods = "CTRL|SHIFT|ALT",
        action = act.AdjustPaneSize {
            "Left",
            5,
        },
    },

    {
        key = "j",
        mods = "CTRL|SHIFT|ALT",
        action = act.AdjustPaneSize {
            "Down",
            5,
        },
    },

    {
        key = "k",
        mods = "CTRL|SHIFT|ALT",
        action = act.AdjustPaneSize {
            "Up",
            5,
        },
    },

    {
        key = "l",
        mods = "CTRL|SHIFT|ALT",
        action = act.AdjustPaneSize {
            "Right",
            5,
        },
    },

    -- ── Zoom pane ───────────────────────────────────────────

    {
        key = "w",
        mods = "CTRL|SHIFT",
        action = act.TogglePaneZoomState,
    },

    -- ── Copiar / pegar ─────────────────────────────────────

    {
        key = "c",
        mods = "CTRL|SHIFT",
        action = act.CopyTo("Clipboard"),
    },

    {
        key = "v",
        mods = "CTRL|SHIFT",
        action = act.PasteFrom("Clipboard"),
    },

    -- ── Limpiar scrollback ─────────────────────────────────

    {
        key = "l",
        mods = "CTRL|SHIFT",
        action = act.ClearScrollback("ScrollbackAndViewport"),
    },

    -- ── Recargar configuración ─────────────────────────────

    {
        key = ",",
        mods = "CTRL|SHIFT",
        action = act.ReloadConfiguration,
    },

    -- ── Búsqueda ────────────────────────────────────────────

    {
        key = "f",
        mods = "CTRL|SHIFT",
        action = act.Search {
            CaseInSensitiveString = "",
        },
    },

    -- ── Scroll ─────────────────────────────────────────────

    {
        key = "PageUp",
        mods = "SHIFT",
        action = act.ScrollByPage(-1),
    },

    {
        key = "PageDown",
        mods = "SHIFT",
        action = act.ScrollByPage(1),
    },

    -- ── Tamaño de fuente ───────────────────────────────────

    {
        key = "=",
        mods = "CTRL",
        action = act.IncreaseFontSize,
    },

    {
        key = "-",
        mods = "CTRL",
        action = act.DecreaseFontSize,
    },

    {
        key = "0",
        mods = "CTRL",
        action = act.ResetFontSize,
    },
}

-- ============================================================
-- Selección
-- ============================================================

config.selection_word_boundary = " \t\n{}[]()\"'`.,;:"

-- ============================================================
-- URLs
-- ============================================================

config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- ============================================================
-- Kitty graphics
-- ============================================================

config.enable_kitty_graphics = true

-- ============================================================
-- Bell
-- ============================================================

config.audible_bell = "Disabled"

config.visual_bell = {
    fade_in_function = "EaseIn",
    fade_out_function = "EaseOut",
    fade_in_duration_ms = 75,
    fade_out_duration_ms = 75,
}

-- ============================================================
-- Cierre
-- ============================================================

config.quit_when_all_windows_are_closed = true
config.window_close_confirmation = "NeverPrompt"

-- ============================================================
-- Colores
-- ============================================================

config.color_scheme = "OozeSoft"

return config
