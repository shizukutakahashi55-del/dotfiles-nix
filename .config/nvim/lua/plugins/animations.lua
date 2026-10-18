-- ============================================================
--  lua/plugins/animations.lua  –  Scroll y cursor animados
-- ============================================================
return {

  -- ── Scroll suave ──────────────────────────────────────────
  {
    "karb94/neoscroll.nvim",
    event = "VeryLazy",
    opts = {
      mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "<C-y>", "<C-e>", "zt", "zz", "zb" },
      hide_cursor          = true,
      stop_eof             = true,
      respect_scrolloff    = true,
      cursor_scrolls_alone = true,
      easing               = "quadratic",
    },
  },

  -- ── Estela del cursor ─────────────────────────────────────
  {
    "sphamba/smear-cursor.nvim",
    event = "VeryLazy",
    opts = {
      smear_between_buffers = true,
      smear_between_neighbor_lines = true,
      smear_insert_mode = false,
      stiffness = 0.8,
      trailing_stiffness = 0.5,
      distance_stop_animating = 0.5,
    },
  },

}
