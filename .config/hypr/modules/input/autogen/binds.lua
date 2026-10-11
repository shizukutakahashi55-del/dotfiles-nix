-- ============================================================================
--  MODULE: modules/input/autogen/binds.lua
--  Auto-generado por OozeShell (Ajustes avanzados → Keybinds). NO EDITAR
--  A MANO: se regenera entero en cada guardado desde el editor.
--
--  Contiene SOLO overrides de binds originales (con combo cambiado) y binds
--  nuevos creados desde el editor. Los binds originales siguen viviendo en
--  modules/input/keybinds.lua; al borrar/desactivar uno, el editor lo comenta
--  ahi con `-- OOZE-DISABLED <id>` en vez de borrarlo, asi se puede restaurar.
--  El estado espejo vive en ~/.config/oozeshell/keybinds.json.
--
--  Los overrides copian el hl.bind() original tal cual (solo cambia el
--  combo), asi que necesitan los mismos requires que keybinds.lua para
--  `programs.*` y `functions.*` (snippets en modules/input/snippets/).
-- ============================================================================

local programs = require("modules.startup.programs")
local functions = require("modules.input.snippets.keybind_functions")
