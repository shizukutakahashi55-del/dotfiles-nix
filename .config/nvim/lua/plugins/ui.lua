-- ============================================================
--  lua/plugins/ui.lua  –  Interfaz visual
-- ============================================================
return {

  -- ── Barra de estado ───────────────────────────────────────
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        -- "auto" toma los colores del colorscheme activo (matugen
        -- ya trae su propia plantilla para lualine, así que esto
        -- es solo el respaldo antes de que matugen cargue).
        theme                = "auto",
        globalstatus         = true,
        component_separators = { left = "", right = "" },
        section_separators   = { left = "", right = "" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },

  -- ── Pestañas de buffers ───────────────────────────────────
  {
    "akinsho/bufferline.nvim",
    version      = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<Tab>",     "<cmd>BufferLineCycleNext<CR>", desc = "Buffer siguiente" },
      { "<S-Tab>",   "<cmd>BufferLineCyclePrev<CR>", desc = "Buffer anterior" },
      { "<leader>x", "<cmd>bdelete<CR>",             desc = "Cerrar buffer" },
    },
    opts = {
      options = {
        mode            = "buffers",
        diagnostics     = "nvim_lsp",
        show_close_icon = false,
        separator_style = "slant",
        -- Ocultar la bufferline cuando solo hay el dashboard
        custom_filter = function(buf_number)
          local bt = vim.bo[buf_number].buftype
          local ft = vim.bo[buf_number].filetype
          if bt == "terminal" then return false end
          if ft == "dashboard" then return false end
          return true
        end,
      },
    },
  },

  -- ── Guías de indentación ──────────────────────────────────
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {
      indent  = { char = "│" },
      scope   = { enabled = true, show_start = false },
      exclude = {
        filetypes = { "help", "dashboard", "lazy", "mason", "notify" },
      },
    },
  },

  -- ── Pares automáticos ─────────────────────────────────────
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts  = {},
  },

  -- ── Comentarios  (gcc línea / gc en visual) ───────────────
  {
    "numToStr/Comment.nvim",
    opts = {},
  },

  -- ── Notificaciones bonitas ────────────────────────────────
  {
    "rcarriga/nvim-notify",
    config = function()
      local notify = require("notify")
      notify.setup({
        timeout   = 3000,
        max_width = 60,
        render    = "compact",
        stages    = "fade_in_slide_out",
        fps       = 60,
      })
      vim.notify = notify
    end,
  },

  -- ── Dashboard (alpha-nvim) ────────────────────────────────
  {
    "goolord/alpha-nvim",
    event        = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local alpha  = require("alpha")
      local dash   = require("alpha.themes.dashboard")

      -- ── Header ────────────────────────────────────────────
      dash.section.header.val = {
        "██████╗  ██████╗ ██████╗ ███████╗███████╗",
        "██╔═══██╗██╔═══██╗╚════██╗██╔════╝██╔════╝",
        "██║   ██║██║   ██║ █████╔╝█████╗  ███████╗",
        "██║   ██║██║   ██║ ╚═══██╗██╔══╝  ╚════██║",
        "╚██████╔╝╚██████╔╝██████╔╝███████╗███████║",
        " ╚═════╝  ╚═════╝ ╚═════╝ ╚══════╝╚══════╝",
        "",
        "  Bienvenido de regreso, rinooze  ",
      }

      -- ── Botones ───────────────────────────────────────────
      dash.section.buttons.val = {
        dash.button("n", "  Nuevo archivo",       "<cmd>enew<CR>"),
        dash.button("f", "  Buscar archivo",      "<cmd>Telescope find_files<CR>"),
        dash.button("r", "  Archivos recientes",  "<cmd>Telescope oldfiles<CR>"),
        dash.button("g", "  Buscar texto",        "<cmd>Telescope live_grep<CR>"),
        dash.button("c", "  Configuración",       "<cmd>edit $MYVIMRC<CR>"),
        dash.button("l", "󰒲  Plugins (Lazy)",      "<cmd>Lazy<CR>"),
        dash.button("q", "  Salir",               "<cmd>qa<CR>"),
      }

      dash.section.footer.val = "  <Space>fk  ver todos los keymaps"

      dash.config.layout = {
        { type = "padding", val = 6 },
        dash.section.header,
        { type = "padding", val = 2 },
        dash.section.buttons,
        { type = "padding", val = 1 },
        dash.section.footer,
      }

      alpha.setup(dash.config)
    end,
  },

  -- ── Which-key: muestra atajos disponibles ─────────────────
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts  = {
      delay  = 400,
      icons  = { mappings = true },
      -- Mostrar en una ventana flotante centrada
      win = {
        border   = "rounded",
        padding  = { 2, 4 },
      },
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)

      -- Registrar grupos con descripción
      wk.add({
        -- Grupos principales
        { "<leader>f",  group = "󰭎  Buscar (Telescope)" },
        { "<leader>g",  group = "  Git" },
        -- Acciones sueltas
        { "<leader>w",  desc  = "  Guardar archivo" },
        { "<leader>q",  desc  = "  Salir" },
        { "<leader>Q",  desc  = "  Salir todo" },
        { "<leader>x",  desc  = "  Cerrar buffer" },
        { "<leader>tr", desc  = "  Recargar tema Matugen" },
        -- Buffers (sin leader)
        { "<Tab>",      desc  = "  Buffer siguiente" },
        { "<S-Tab>",    desc  = "  Buffer anterior" },
      })
    end,
  },

}