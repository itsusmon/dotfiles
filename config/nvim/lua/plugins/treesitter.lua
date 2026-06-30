-- ╭──────────────────────────────────────────────────────────────╮
-- │                     Treesitter Config                       │
-- ╰──────────────────────────────────────────────────────────────╯
--
-- nvim-treesitter `main` branch. Unlike the old `master` branch there is no
-- single setup({...}) with highlight/indent/incremental_selection; instead:
--   • highlighting  → vim.treesitter.start() per buffer
--   • indentation   → require('nvim-treesitter').indentexpr()
--   • parsers       → require('nvim-treesitter').install()
--   • incremental selection was dropped upstream and is reimplemented below.

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    event = { 'BufReadPre', 'BufNewFile' },
    cmd = { 'TSUpdate', 'TSInstall', 'TSUninstall', 'TSLog' },
    -- mason provides the `tree-sitter` CLI the main branch needs to build
    -- parsers, and puts it on Neovim's PATH when it loads.
    dependencies = { 'mason-org/mason.nvim' },
    config = function()
      local TS = require('nvim-treesitter')
      TS.setup()

      -- Parsers to keep installed.
      local ensure = {
        'lua', 'vim', 'vimdoc', 'javascript', 'typescript', 'tsx',
        'python', 'json', 'html', 'css', 'bash', 'markdown', 'markdown_inline',
      }

      -- Cache of installed parsers, refreshed after every install.
      local installed = {}
      local function refresh()
        installed = {}
        for _, lang in ipairs(TS.get_installed('parsers')) do
          installed[lang] = true
        end
      end
      refresh()

      -- Enable treesitter features for a buffer (no-op if the parser is missing).
      local function enable(buf, lang)
        if not vim.api.nvim_buf_is_valid(buf) then return end
        if not pcall(vim.treesitter.start, buf, lang) then return end
        if vim.treesitter.query.get(lang, 'indents') then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end

      -- The main branch builds parsers with the `tree-sitter` CLI. Ensure it
      -- exists (installing via mason if needed), then run cb().
      local function with_cli(cb)
        if vim.fn.executable('tree-sitter') == 1 then return cb() end
        local ok, mr = pcall(require, 'mason-registry')
        if not ok then
          return vim.notify('treesitter: tree-sitter CLI missing (mason unavailable)', vim.log.levels.WARN)
        end
        mr.refresh(function()
          local p = mr.get_package('tree-sitter-cli')
          if p:is_installed() then return cb() end
          p:install(nil, vim.schedule_wrap(function()
            if vim.fn.executable('tree-sitter') == 1 then cb() end
          end))
        end)
      end

      -- Install missing ensured parsers.
      local missing = vim.tbl_filter(function(l) return not installed[l] end, ensure)
      if #missing > 0 then
        with_cli(function()
          pcall(function() TS.install(missing):await(refresh) end)
        end)
      end

      -- Turn things on per filetype; auto-install on first sight of a new
      -- language (replaces the old `auto_install = true`).
      local attempted = {}
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('user_treesitter', { clear = true }),
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(ev.match)
          if not lang then return end

          if not installed[lang] then
            refresh() -- maybe a background install just finished
          end

          if installed[lang] then
            enable(ev.buf, lang)
          elseif not attempted[lang] then
            attempted[lang] = true
            with_cli(function()
              pcall(function()
                TS.install({ lang }):await(function()
                  refresh()
                  -- enable for every loaded buffer of this language
                  for _, b in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.api.nvim_buf_is_loaded(b)
                      and vim.treesitter.language.get_lang(vim.bo[b].filetype) == lang then
                      enable(b, lang)
                    end
                  end
                end)
              end)
            end)
          end
        end,
      })

      -- ── Incremental selection (reimplemented; dropped on `main`) ──
      -- <C-space> start/grow by node, <BS> shrink. Mirrors the old keymaps.
      local sel = {} ---@type table<integer, TSNode[]>  per-buffer node stack

      local function select_node(node)
        local srow, scol, erow, ecol = node:range()
        vim.api.nvim_win_set_cursor(0, { srow + 1, scol })
        vim.cmd('normal! v')
        if ecol == 0 then
          erow = erow - 1
          ecol = #(vim.api.nvim_buf_get_lines(0, erow, erow + 1, false)[1] or '')
        else
          ecol = ecol - 1
        end
        pcall(vim.api.nvim_win_set_cursor, 0, { erow + 1, math.max(ecol, 0) })
      end

      local function same_range(a, b)
        local a1, a2, a3, a4 = a:range()
        local b1, b2, b3, b4 = b:range()
        return a1 == b1 and a2 == b2 and a3 == b3 and a4 == b4
      end

      local function init_selection()
        local buf = vim.api.nvim_get_current_buf()
        local ok, parser = pcall(vim.treesitter.get_parser, buf)
        if not ok or not parser then return end
        parser:parse(true) -- make sure the tree is current before querying it
        local node = vim.treesitter.get_node({ bufnr = buf })
        if not node then return end
        sel[buf] = { node }
        select_node(node)
      end

      local function grow_selection()
        local buf = vim.api.nvim_get_current_buf()
        local stack = sel[buf]
        if not stack or #stack == 0 then return init_selection() end
        local node = stack[#stack]
        local parent = node:parent()
        while parent and same_range(parent, node) do
          parent = parent:parent()
        end
        if parent then
          stack[#stack + 1] = parent
          select_node(parent)
        end
      end

      local function shrink_selection()
        local buf = vim.api.nvim_get_current_buf()
        local stack = sel[buf]
        if not stack or #stack <= 1 then return end
        stack[#stack] = nil
        select_node(stack[#stack])
      end

      vim.keymap.set('n', '<C-space>', init_selection, { desc = 'TS: init selection' })
      vim.keymap.set('x', '<C-space>', grow_selection, { desc = 'TS: grow selection' })
      vim.keymap.set('x', '<BS>', shrink_selection, { desc = 'TS: shrink selection' })
    end,
  },
}
