# Configuración de Neovim

## Estructura

- `init.lua` → opciones generales, tecla líder (`Espacio`), instalación de lazy.nvim y keymaps globales (guardar, salir, splits, quitar resaltado, recargar tema).
- `lazy-lock.json` → versiones fijadas de cada plugin.
- `lua/plugins/` → un archivo por área; lazy.nvim los carga todos.
  - `telescope.lua` → búsqueda de archivos, texto, buffers, git y diagnósticos (`<leader>f…`, `<leader>g…`).
  - `treesitter.lua` → resaltado, indentación y textobjects.
  - `matugen.lua` → colorscheme dinámico que se recarga solo al cambiar de wallpaper.
  - `animations.lua` → scroll suave (`neoscroll.nvim`) y estela del cursor (`smear-cursor.nvim`).
  - `ui.lua` → lualine, bufferline, guías de indentación, autopairs, comentarios, notificaciones, dashboard y which-key.

## Navegación sin árbol

No hay explorador de archivos. Se navega con búsqueda:

| Atajo | Acción |
|---|---|
| `<leader>ff` | Buscar archivos |
| `<leader>fr` | Archivos recientes |
| `<leader>fg` | Buscar texto en el proyecto |
| `<leader>fb` | Buffers abiertos |
| `<Tab>` / `<S-Tab>` | Buffer siguiente / anterior |
| `<leader>fk` | Ver todos los keymaps |

Al abrir un directorio (`nvim .`) se usa netrw, que viene con Neovim.

## Animaciones

- Notificaciones (`nvim-notify`): aparecen con fundido y salen deslizándose (`fade_in_slide_out`) a 60 fps. El fondo sigue al colorscheme activo, así que cambia con matugen.
- Scroll (`neoscroll.nvim`): anima `<C-u>`, `<C-d>`, `<C-b>`, `<C-f>`, `<C-y>`, `<C-e>`, `zt`, `zz` y `zb` con easing cuadrático. Se detiene en el final del archivo y respeta `scrolloff`.
- Cursor (`smear-cursor.nvim`): deja una estela al saltar entre líneas y buffers. No se anima en modo inserción para no estorbar al escribir. Ajustes en `lua/plugins/animations.lua`: `stiffness` y `trailing_stiffness` controlan qué tan rápido se alcanza el destino; valores más bajos dan una estela más larga.
- Para desactivar una, borra su bloque en `animations.lua`; `:Lazy clean` retira el plugin.
