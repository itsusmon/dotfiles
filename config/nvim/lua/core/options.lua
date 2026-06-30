-- ╭──────────────────────────────────────────────────────────────╮
-- │                        Vim Options                          │
-- ╰──────────────────────────────────────────────────────────────╯

local opt = vim.opt

-- Leader key (MUST be set before lazy.nvim loads)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Indentation (2 spaces)
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- System clipboard
opt.clipboard = 'unnamedplus'

-- Colors
opt.termguicolors = true

-- Files
opt.swapfile = false
opt.backup = false
opt.undofile = true

-- UI
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.signcolumn = 'yes'
opt.cursorline = true
opt.mouse = 'a'
opt.showmode = false -- lualine handles this
opt.wrap = false
opt.breakindent = true

-- Splits
opt.splitright = true
opt.splitbelow = true

-- Performance
opt.updatetime = 250
opt.timeoutlen = 300

-- Completion
opt.completeopt = 'menu,menuone,noselect'

-- Misc
opt.conceallevel = 0
opt.pumheight = 10
opt.fillchars = { eob = ' ' } -- remove ~ from end of buffer
