-- ╭──────────────────────────────────────────────────────────────╮
-- │                     Treesitter Config                       │
-- ╰──────────────────────────────────────────────────────────────╯

return {
  {
    'nvim-treesitter/nvim-treesitter',
    -- Pin to the classic API. The new `main` branch dropped
    -- `nvim-treesitter.configs` (and indent / incremental_selection),
    -- which this config relies on.
    branch = 'master',
    build = ':TSUpdate',
    event = { 'BufReadPre', 'BufNewFile' },
    main = 'nvim-treesitter.configs',
    opts = {
      ensure_installed = {
        'lua',
        'vim',
        'vimdoc',
        'javascript',
        'typescript',
        'python',
        'json',
        'html',
        'css',
        'bash',
        'markdown',
        'markdown_inline',
      },
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      },
      indent = {
        enable = true,
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = '<C-space>',
          node_incremental = '<C-space>',
          scope_incremental = false,
          node_decremental = '<bs>',
        },
      },
    },
  },
}
