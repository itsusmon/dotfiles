-- ╔══════════════════════════════════════════════════════════════╗
-- ║                    Neovim Configuration                     ║
-- ║              Catppuccin Macchiato · Transparent              ║
-- ╚══════════════════════════════════════════════════════════════╝

-- Core settings (leader key set here BEFORE lazy.nvim loads)
require('core.options')
require('core.keymaps')
require('core.autocmds')

-- Plugin manager (lazy.nvim bootstrap + all plugin specs)
require('plugins')
