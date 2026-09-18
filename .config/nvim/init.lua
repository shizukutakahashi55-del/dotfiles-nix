-- ============================================================
--  ~/.config/nvim/init.lua
-- ============================================================

-- ── Opciones generales ───────────────────────────────────────
vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.tabstop        = 2
vim.opt.shiftwidth     = 2
vim.opt.expandtab      = true
vim.opt.termguicolors  = true
vim.opt.signcolumn     = "yes"
vim.opt.wrap           = false
vim.opt.scrolloff      = 8
vim.opt.updatetime     = 250
vim.opt.splitright     = true
vim.opt.splitbelow     = true
vim.opt.ignorecase     = true
vim.opt.smartcase      = true
vim.opt.clipboard      = "unnamedplus"

-- Tecla líder → Espacio
vim.g.mapleader      = " "
vim.g.maplocalleader = " "

-- Deshabilitar netrw (lo reemplaza Neo-tree)
vim.g.loaded_netrw       = 1
vim.g.loaded_netrwPlugin = 1

-- ── Bootstrap lazy.nvim ──────────────────────────────────────
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ── Cargar plugins ───────────────────────────────────────────
require("lazy").setup("plugins", {
  change_detection = {
    notify = false,
  },
})


-- ── Keymaps generales ────────────────────────────────────────

local map = vim.keymap.set


-- ── Guardar / salir ─────────────────────────────────────────

map("n", "<leader>w", "<cmd>w<CR>", {
  desc = "Guardar archivo",
})

map("n", "<leader>q", "<cmd>q<CR>", {
  desc = "Salir",
})

map("n", "<leader>Q", "<cmd>qa<CR>", {
  desc = "Salir todo",
})


-- ── Moverse entre splits ────────────────────────────────────

map("n", "<C-h>", "<C-w>h", {
  desc = "Split izquierda",
})

map("n", "<C-l>", "<C-w>l", {
  desc = "Split derecha",
})

map("n", "<C-j>", "<C-w>j", {
  desc = "Split abajo",
})

map("n", "<C-k>", "<C-w>k", {
  desc = "Split arriba",
})


-- ── Quitar resaltado de búsqueda ────────────────────────────

map("n", "<Esc>", "<cmd>nohlsearch<CR>", {
  desc = "Quitar resaltado",
})


-- ── Tema (matugen) ───────────────────────────────────────────
-- El tema se aplica y recarga solo (ver lua/plugins/matugen.lua).
-- Este atajo es solo para forzar una recarga manual si lo necesitas.

map("n", "<leader>tr", "<cmd>MatugenReload<CR>", {
  desc = "Recargar tema de Matugen",
})

