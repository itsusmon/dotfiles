-- ╭──────────────────────────────────────────────────────────────╮
-- │              lazy.nvim — Plugin Manager Bootstrap            │
-- ╰──────────────────────────────────────────────────────────────╯

local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  { import = 'plugins.ui' },
  { import = 'plugins.editor' },
  { import = 'plugins.treesitter' },
  { import = 'plugins.lsp' },
}, {
  git = { depth = 1 },
  ui = { border = 'rounded' },
  checker = { enabled = false },
  change_detection = { notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        'gzip', 'matchit', 'matchparen',
        'netrwPlugin', 'tarPlugin', 'tohtml',
        'tutor', 'zipPlugin',
      },
    },
  },
})
