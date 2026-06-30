-- ╭──────────────────────────────────────────────────────────────╮
-- │                       Editor Plugins                        │
-- ╰──────────────────────────────────────────────────────────────╯

return {

  -- ── Telescope (Fuzzy Finder) ────────────────────────────────
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = 'Telescope',
    keys = {
      { '<leader>ff', '<cmd>Telescope find_files<CR>', desc = 'Find files' },
      { '<leader>fg', '<cmd>Telescope live_grep<CR>', desc = 'Live grep' },
      { '<leader>fb', '<cmd>Telescope buffers<CR>', desc = 'Buffers' },
      { '<leader>fh', '<cmd>Telescope help_tags<CR>', desc = 'Help tags' },
      { '<leader>fd', '<cmd>Telescope diagnostics<CR>', desc = 'Diagnostics' },
      { '<leader>fr', '<cmd>Telescope oldfiles<CR>', desc = 'Recent files' },
    },
    opts = {
      defaults = {
        prompt_prefix = '   ',
        selection_caret = '  ',
        entry_prefix = '  ',
        sorting_strategy = 'ascending',
        layout_strategy = 'horizontal',
        layout_config = {
          horizontal = {
            prompt_position = 'top',
            preview_width = 0.55,
          },
          width = 0.87,
          height = 0.80,
        },
        borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰' },
        file_ignore_patterns = {
          'node_modules', '.git/', '%.lock',
          '__pycache__', '%.pyc',
        },
        winblend = 0, -- fully transparent
      },
      pickers = {
        find_files = {
          hidden = true,
        },
      },
    },
  },

  -- ── Neo-tree (File Explorer) ────────────────────────────────
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    cmd = 'Neotree',
    keys = {
      { '<leader>e', '<cmd>Neotree toggle<CR>', desc = 'Toggle file explorer' },
    },
    opts = {
      close_if_last_window = true,
      popup_border_style = 'rounded',
      enable_git_status = true,
      enable_diagnostics = true,
      window = {
        position = 'left',
        width = 35,
        mappings = {
          ['<space>'] = 'none',
        },
      },
      filesystem = {
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_by_name = { 'node_modules', '.git' },
        },
      },
      default_component_configs = {
        indent = {
          with_expanders = true,
          expander_collapsed = '',
          expander_expanded = '',
        },
        icon = {
          folder_closed = '',
          folder_open = '',
          folder_empty = '',
        },
        git_status = {
          symbols = {
            added = '',
            modified = '',
            deleted = '✖',
            renamed = '󰁕',
            untracked = '',
            ignored = '',
            unstaged = '󰄱',
            staged = '',
            conflict = '',
          },
        },
      },
    },
  },

  -- ── Gitsigns ────────────────────────────────────────────────
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      signs = {
        add = { text = '▎' },
        change = { text = '▎' },
        delete = { text = '' },
        topdelete = { text = '' },
        changedelete = { text = '▎' },
        untracked = { text = '▎' },
      },
      signs_staged = {
        add = { text = '▎' },
        change = { text = '▎' },
        delete = { text = '' },
        topdelete = { text = '' },
        changedelete = { text = '▎' },
      },
      current_line_blame = false,
      current_line_blame_opts = {
        delay = 300,
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = function(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
        end
        map('n', ']c', function() gs.nav_hunk('next') end, 'Next hunk')
        map('n', '[c', function() gs.nav_hunk('prev') end, 'Prev hunk')
        map('n', '<leader>gs', gs.stage_hunk, 'Stage hunk')
        map('n', '<leader>gr', gs.reset_hunk, 'Reset hunk')
        map('n', '<leader>gp', gs.preview_hunk, 'Preview hunk')
        map('n', '<leader>gb', function() gs.blame_line({ full = true }) end, 'Blame line')
      end,
    },
  },

  -- ── Which-key ───────────────────────────────────────────────
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    opts = {
      preset = 'helix',
      win = {
        border = 'rounded',
      },
      spec = {
        { '<leader>f', group = 'Find' },
        { '<leader>g', group = 'Git' },
        { '<leader>c', group = 'Code' },
        { '<leader>r', group = 'Rename' },
      },
    },
  },

  -- ── Autopairs ───────────────────────────────────────────────
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = true,
  },

  -- ── Comment ─────────────────────────────────────────────────
  {
    'numToStr/Comment.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    config = true,
  },
}
