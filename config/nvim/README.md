# Neovim

## What it is

Neovim is a modern, extensible, Vim-based text editor.

## Why I use it

It is the primary editor for quick edits, config work, and terminal-based coding.
It is configured in Lua with a curated plugin set (LSP, Treesitter, Telescope, Neo-tree, gitsigns) for an IDE-like experience that stays fast.

## What's here

The config is modular Lua, loaded by `init.lua`:

- `lua/core/` - editor settings that don't depend on plugins:
  - `options.lua` - vim options (also sets the leader key before lazy.nvim loads).
  - `keymaps.lua` - keybindings.
  - `autocmds.lua` - autocommands.
- `lua/plugins/` - plugin specs, managed by lazy.nvim:
  - `init.lua` - bootstraps lazy.nvim and imports the specs below.
  - `ui.lua` - colorscheme (Catppuccin Macchiato, transparent) and UI.
  - `editor.lua` - editing plugins (Telescope, Neo-tree, gitsigns, and friends).
  - `treesitter.lua` - syntax parsing and highlighting.
  - `lsp.lua` - language servers.

The plugin manager is lazy.nvim, auto-bootstrapped on first launch (git-cloned into the data dir).
`lazy-lock.json` is intentionally not tracked, since it is an app-managed lockfile.

## Working with it

- Plugins install and update via lazy.nvim; run `:Lazy` to manage them.
- The keymaps mirror the Vim/IdeaVim setup (see `../vim/`) so muscle memory carries between Neovim and JetBrains IDEs / Android Studio.
