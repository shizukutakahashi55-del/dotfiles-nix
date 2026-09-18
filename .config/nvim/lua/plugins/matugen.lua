-- ============================================================
--  lua/plugins/matugen.lua  –  Tema dinámico Material You (matugen)
-- ============================================================
-- Este plugin lee la paleta que genera `matugen` (el CLI) y la
-- convierte en un colorscheme de Neovim. Se recarga solo cada vez
-- que matugen corre (por ejemplo, al cambiar de wallpaper),
-- vía el post_hook definido en ~/.config/matugen/config.toml.
--
-- Requiere: tener matugen (CLI) generando el archivo JSON en la
-- ruta indicada en `palette_path` más abajo.

return {
  "Senal-D-A-Gunaratna/matugen.nvim",
  lazy     = false,
  priority = 1000, -- se carga temprano, como cualquier colorscheme
  opts = {
    -- Ruta al JSON que matugen genera. Debe coincidir EXACTO con
    -- el output_path que pongas en ~/.config/matugen/config.toml
    palette_path = "~/.cache/matugen/nvim-colors.json",

    -- true (por defecto): aplica el tema automáticamente al iniciar
    -- Neovim y al recibir la señal de recarga. Si prefieres decidir
    -- tú cuándo activarlo, pon esto en false y usa
    -- `:colorscheme matugen` manualmente.
    load_theme = true,
  },
}
