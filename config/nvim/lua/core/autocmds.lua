-- ╭──────────────────────────────────────────────────────────────╮
-- │                       Autocommands                          │
-- ╰──────────────────────────────────────────────────────────────╯

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Highlight on yank (brief flash)
autocmd('TextYankPost', {
  group = augroup('YankHighlight', { clear = true }),
  callback = function()
    vim.highlight.on_yank({ higroup = 'IncSearch', timeout = 200 })
  end,
})

-- Remove trailing whitespace on save
autocmd('BufWritePre', {
  group = augroup('TrimWhitespace', { clear = true }),
  pattern = '*',
  callback = function()
    local save = vim.fn.winsaveview()
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.winrestview(save)
  end,
})

-- Return to last edit position when reopening files
autocmd('BufReadPost', {
  group = augroup('LastPosition', { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lines = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lines then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Force transparent backgrounds on every colorscheme change
autocmd('ColorScheme', {
  group = augroup('TransparentBackground', { clear = true }),
  callback = function()
    local groups = {
      'Normal', 'NormalNC', 'NormalFloat', 'FloatBorder', 'FloatTitle',
      'SignColumn', 'StatusLine', 'StatusLineNC',
      'TabLine', 'TabLineFill',
      'CursorLine', 'WinSeparator', 'VertSplit',
      'Pmenu', 'PmenuSel', 'PmenuThumb',
      'TelescopeNormal', 'TelescopeBorder',
      'TelescopePromptNormal', 'TelescopePromptBorder',
      'TelescopeResultsNormal', 'TelescopeResultsBorder',
      'TelescopePreviewNormal', 'TelescopePreviewBorder',
      'NeoTreeNormal', 'NeoTreeNormalNC', 'NeoTreeEndOfBuffer',
      'NeoTreeFloatBorder', 'NeoTreeWinSeparator',
      'WhichKeyFloat',
      'NoiceCmdlinePopup', 'NoiceCmdlinePopupBorder',
      'NotifyBackground',
      'BufferLineFill', 'BufferLineBackground',
    }
    for _, group in ipairs(groups) do
      vim.api.nvim_set_hl(0, group, { bg = 'NONE', ctermbg = 'NONE' })
    end
  end,
})
