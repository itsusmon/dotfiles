-- ╭──────────────────────────────────────────────────────────────╮
-- │                    LSP & Completions                        │
-- ╰──────────────────────────────────────────────────────────────╯

return {

  -- ── Mason (LSP/DAP/Linter Installer) ────────────────────────
  {
    'williamboman/mason.nvim',
    cmd = 'Mason',
    build = ':MasonUpdate',
    opts = {
      ui = {
        border = 'rounded',
        icons = {
          package_installed = '✓',
          package_pending = '➜',
          package_uninstalled = '✗',
        },
      },
    },
  },

  -- ── Mason-LSPConfig (Bridge) ────────────────────────────────
  {
    'williamboman/mason-lspconfig.nvim',
    dependencies = { 'williamboman/mason.nvim' },
    opts = {
      ensure_installed = {
        'lua_ls',
        'pyright',
        'ts_ls',
      },
      automatic_installation = true,
    },
  },

  -- ── LSPConfig ───────────────────────────────────────────────
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      'williamboman/mason-lspconfig.nvim',
      'hrsh7th/cmp-nvim-lsp',
    },
    config = function()
      local lspconfig = require('lspconfig')
      local cmp_lsp = require('cmp_nvim_lsp')

      -- Enhanced capabilities from nvim-cmp
      local capabilities = vim.tbl_deep_extend(
        'force',
        {},
        vim.lsp.protocol.make_client_capabilities(),
        cmp_lsp.default_capabilities()
      )

      -- Diagnostic configuration
      vim.diagnostic.config({
        virtual_text = {
          prefix = '●',
          spacing = 4,
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = ' ',
            [vim.diagnostic.severity.WARN] = ' ',
            [vim.diagnostic.severity.HINT] = '󰌵 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
          },
        },
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          border = 'rounded',
          source = true,
        },
      })

      -- On-attach keymaps
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('LspKeymaps', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('gd', function() vim.lsp.buf.definition() end, 'Go to definition')
          map('gr', function() vim.lsp.buf.references() end, 'References')
          map('gi', function() vim.lsp.buf.implementation() end, 'Implementation')
          map('K', function() vim.lsp.buf.hover() end, 'Hover documentation')
          map('<leader>ca', function() vim.lsp.buf.code_action() end, 'Code action', { 'n', 'v' })
          map('<leader>rn', function() vim.lsp.buf.rename() end, 'Rename symbol')
          map('gD', function() vim.lsp.buf.declaration() end, 'Go to declaration')
          map('<leader>D', function() vim.lsp.buf.type_definition() end, 'Type definition')
          map('<leader>ds', function() vim.lsp.buf.document_symbol() end, 'Document symbols')
        end,
      })

      -- Server configurations
      -- Use mason-lspconfig handlers for automatic setup
      require('mason-lspconfig').setup_handlers({
        -- Default handler: apply capabilities to all servers
        function(server_name)
          lspconfig[server_name].setup({
            capabilities = capabilities,
          })
        end,

        -- Lua LS: custom settings for Neovim development
        ['lua_ls'] = function()
          lspconfig.lua_ls.setup({
            capabilities = capabilities,
            settings = {
              Lua = {
                runtime = { version = 'LuaJIT' },
                workspace = {
                  checkThirdParty = false,
                  library = {
                    vim.env.VIMRUNTIME,
                    '${3rd}/luv/library',
                  },
                },
                completion = { callSnippet = 'Replace' },
                diagnostics = {
                  disable = { 'missing-fields' },
                },
                telemetry = { enable = false },
              },
            },
          })
        end,

        -- Pyright
        ['pyright'] = function()
          lspconfig.pyright.setup({
            capabilities = capabilities,
            settings = {
              python = {
                analysis = {
                  typeCheckingMode = 'basic',
                  autoSearchPaths = true,
                  useLibraryCodeForTypes = true,
                },
              },
            },
          })
        end,

        -- TypeScript
        ['ts_ls'] = function()
          lspconfig.ts_ls.setup({
            capabilities = capabilities,
            settings = {
              typescript = {
                inlayHints = {
                  includeInlayParameterNameHints = 'all',
                  includeInlayFunctionParameterTypeHints = true,
                  includeInlayVariableTypeHints = true,
                },
              },
            },
          })
        end,
      })
    end,
  },

  -- ── nvim-cmp (Autocompletion) ───────────────────────────────
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'saadparwaiz1/cmp_luasnip',
      {
        'L3MON4D3/LuaSnip',
        version = 'v2.*',
        build = 'make install_jsregexp',
        dependencies = {
          {
            'rafamadriz/friendly-snippets',
            config = function()
              require('luasnip.loaders.from_vscode').lazy_load()
            end,
          },
        },
      },
    },
    config = function()
      local cmp = require('cmp')
      local luasnip = require('luasnip')

      luasnip.config.setup({})

      -- Kind icons for completion menu
      local kind_icons = {
        Text = '󰉿', Method = '󰆧', Function = '󰊕', Constructor = '',
        Field = '󰜢', Variable = '󰀫', Class = '󰠱', Interface = '',
        Module = '', Property = '󰜢', Unit = '󰑭', Value = '󰎠',
        Enum = '', Keyword = '󰌋', Snippet = '', Color = '󰏘',
        File = '󰈙', Reference = '󰈇', Folder = '󰉋', EnumMember = '',
        Constant = '󰏿', Struct = '󰙅', Event = '', Operator = '󰆕',
        TypeParameter = '',
      }

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered({
            winhighlight = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None',
          }),
          documentation = cmp.config.window.bordered({
            winhighlight = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None',
          }),
        },
        formatting = {
          format = function(entry, vim_item)
            vim_item.kind = string.format('%s %s', kind_icons[vim_item.kind] or '', vim_item.kind)
            vim_item.menu = ({
              nvim_lsp = '[LSP]',
              luasnip = '[Snip]',
              buffer = '[Buf]',
              path = '[Path]',
            })[entry.source.name]
            return vim_item
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
          ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp', priority = 1000 },
          { name = 'luasnip', priority = 750 },
          { name = 'buffer', priority = 500 },
          { name = 'path', priority = 250 },
        }),
      })
    end,
  },
}
