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
        offsets = {
          {
            filetype  = "neo-tree",
            text      = "  Explorador",
            highlight = "Directory",
            separator = true,
          },
        },
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
        filetypes = { "help", "dashboard", "neo-tree", "lazy", "mason", "notify" },
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
      vim.notify = require("notify")
      require("notify").setup({
        background_colour = "#1a1b26",
        timeout           = 3000,
        max_width         = 60,
        render            = "compact",
        stages            = "fade",
      })
    end,
  },

  -- ── Dashboard (alpha-nvim) + Neo-tree ────────────────────
  {
    "goolord/alpha-nvim",
    event        = "VimEnter",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
      "nvim-neo-tree/neo-tree.nvim",
    },
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

      -- Padding vertical para centrar verticalmente
      dash.config.layout = {
        { type = "padding", val = 6 },
        dash.section.header,
        { type = "padding", val = 2 },
        dash.section.buttons,
        { type = "padding", val = 1 },
        dash.section.footer,
      }

      alpha.setup(dash.config)

      -- ── Abrir Neo-tree cuando alpha esté listo ─────────────
      -- alpha-nvim centra su contenido dentro de su propia ventana,
      -- que ocupa todo el espacio libre (a la derecha de Neo-tree).
      vim.api.nvim_create_autocmd("User", {
        pattern  = "AlphaReady",
        once     = true,
        callback = function()
          vim.cmd("Neotree show left dir=" .. vim.fn.getcwd())
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "alpha" then
              vim.api.nvim_set_current_win(win)
              break
            end
          end
        end,
      })
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
        { "<leader>e",  group = "  Explorador (Neo-tree)" },
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