-- ╭──────────────────────────────────────────────────────────────╮
-- │                        Key Mappings                         │
-- ╰──────────────────────────────────────────────────────────────╯

local map = vim.keymap.set

-- ── General ──────────────────────────────────────────────────
map('n', '<leader>w', '<cmd>w<CR>', { desc = 'Save file' })
map('n', '<leader>q', '<cmd>q<CR>', { desc = 'Quit' })
map('n', '<leader>h', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })

-- ── Window Navigation ────────────────────────────────────────
map('n', '<C-h>', '<C-w>h', { desc = 'Move to left window' })
map('n', '<C-j>', '<C-w>j', { desc = 'Move to lower window' })
map('n', '<C-k>', '<C-w>k', { desc = 'Move to upper window' })
map('n', '<C-l>', '<C-w>l', { desc = 'Move to right window' })

-- ── Buffer Navigation ────────────────────────────────────────
map('n', '<S-h>', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
map('n', '<S-l>', '<cmd>bnext<CR>', { desc = 'Next buffer' })

-- ── Move Lines ───────────────────────────────────────────────
map('v', '<A-j>', ":m '>+1<CR>gv=gv", { desc = 'Move line down' })
map('v', '<A-k>', ":m '<-2<CR>gv=gv", { desc = 'Move line up' })

-- ── Diagnostics ──────────────────────────────────────────────
map('n', '[d', function() vim.diagnostic.goto_prev() end, { desc = 'Previous diagnostic' })
map('n', ']d', function() vim.diagnostic.goto_next() end, { desc = 'Next diagnostic' })

-- ── Better Defaults ──────────────────────────────────────────
map('n', 'J', 'mzJ`z', { desc = 'Join lines (keep cursor)' })
map('n', '<C-d>', '<C-d>zz', { desc = 'Half page down (centered)' })
map('n', '<C-u>', '<C-u>zz', { desc = 'Half page up (centered)' })
map('n', 'n', 'nzzzv', { desc = 'Next search (centered)' })
map('n', 'N', 'Nzzzv', { desc = 'Prev search (centered)' })

-- ── Visual Mode ──────────────────────────────────────────────
map('v', '<', '<gv', { desc = 'Indent left (stay in visual)' })
map('v', '>', '>gv', { desc = 'Indent right (stay in visual)' })

-- ── Telescope (set here for which-key discoverability) ───────
map('n', '<leader>ff', '<cmd>Telescope find_files<CR>', { desc = 'Find files' })
map('n', '<leader>fg', '<cmd>Telescope live_grep<CR>', { desc = 'Live grep' })
map('n', '<leader>fb', '<cmd>Telescope buffers<CR>', { desc = 'Buffers' })

-- ── Neo-tree ─────────────────────────────────────────────────
map('n', '<leader>e', '<cmd>Neotree toggle<CR>', { desc = 'Toggle file explorer' })
