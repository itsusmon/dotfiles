-- ╭──────────────────────────────────────────────────────────────╮
-- │                       UI Plugins                            │
-- ╰──────────────────────────────────────────────────────────────╯

return {

  -- ── Catppuccin Colorscheme ─────────────────────────────────
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    lazy = false,
    opts = {
      flavour = 'macchiato',
      transparent_background = true,
      show_end_of_buffer = false,
      term_colors = true,
      styles = {
        comments = { 'italic' },
        conditionals = { 'italic' },
        functions = {},
        keywords = { 'bold' },
        strings = {},
        variables = {},
      },
      integrations = {
        cmp = true,
        gitsigns = true,
        indent_blankline = { enabled = true, colored_indent_levels = false },
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { 'undercurl' },
            hints = { 'undercurl' },
            warnings = { 'undercurl' },
            information = { 'undercurl' },
          },
        },
        neotree = true,
        noice = true,
        notify = true,
        telescope = { enabled = true },
        treesitter = true,
        which_key = true,
      },
    },
    config = function(_, opts)
      require('catppuccin').setup(opts)
      vim.cmd.colorscheme('catppuccin')
    end,
  },

  -- ── Lualine (statusline) ───────────────────────────────────
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    event = 'VeryLazy',
    opts = {
      options = {
        theme = 'auto',
        globalstatus = true,
        section_separators = '',
        component_separators = '│',
      },
      sections = {
        lualine_a = { { 'mode', fmt = function(s) return s:sub(1, 1) end } },
        lualine_b = { 'branch', 'diff' },
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { 'diagnostics', 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' },
      },
    },
  },

  -- ── Bufferline (buffer tabs) ───────────────────────────────
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    event = 'VeryLazy',
    config = function()
      local highlights = {}
      local ok, catbuf = pcall(require, 'catppuccin.groups.integrations.bufferline')
      if ok then
        highlights = catbuf.get({
          custom = {
            all = {
              fill = { bg = 'NONE' },
              background = { bg = 'NONE' },
            },
          },
        })
      end
      require('bufferline').setup({
        options = {
          diagnostics = 'nvim_lsp',
          always_show_bufferline = false,
          offsets = {
            { filetype = 'neo-tree', text = 'Explorer', highlight = 'Directory', separator = true },
          },
        },
        highlights = highlights,
      })
    end,
  },

  -- ── Indent Blankline (indent guides) ──────────────────────
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {
      indent = { char = '│' },
      scope = { enabled = true, show_start = false, show_end = false },
      exclude = {
        filetypes = { 'help', 'neo-tree', 'lazy', 'mason', 'notify', 'dashboard' },
      },
    },
  },

  -- ── Noice (better UI for messages/cmdline) ────────────────
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = {
      'MunifTanjim/nui.nvim',
      {
        'rcarriga/nvim-notify',
        opts = {
          background_colour = '#000000',
          stages = 'fade',
          timeout = 3000,
          render = 'wrapped-compact',
        },
      },
    },
    opts = {
      -- Classic bottom command line (not the centered popup).
      cmdline = { view = 'cmdline' },
      lsp = {
        override = {
          ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
          ['vim.lsp.util.stylize_markdown'] = true,
          ['cmp.entry.get_documentation'] = true,
        },
      },
      presets = {
        bottom_search = true,
        long_message_to_split = true,
        lsp_doc_border = true,
      },
    },
  },
}
