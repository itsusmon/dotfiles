# Vim / IdeaVim

## What it is

Configuration shared between real Vim and IdeaVim (the Vim emulation plugin for JetBrains IDEs and Android Studio).

## Why I use it

So Vim muscle memory works everywhere, not just in Neovim.
`vimrc` is the single source of truth for options and plugin-independent keymaps.
`ideavimrc` sources it, then re-creates the Neovim plugin keybindings (Telescope, LSP, Neo-tree, gitsigns) as IDE actions, so the same keys do the same things inside the IDE.

## What's here

- `vimrc` -> `~/.config/vim/vimrc` - shared options and keymaps.
  It uses `has('ide')` guards so real-Vim-only settings (colorscheme, netrw, fzf, autocommands) don't run inside IdeaVim.
- `ideavimrc` -> `~/.config/ideavim/ideavimrc` - sources the shared vimrc, enables IDE integrations (ideajoin, surround, commentary, and so on), and maps Neovim-style keys to IDE actions.
- `colors/catppuccin_macchiato.vim` -> `~/.config/vim/colors/` - the transparent colorscheme for real Vim, matching Neovim and Ghostty.

Note: real Vim finds this because it lives at `~/.config/vim/vimrc`, the third vimrc path Vim searches.
Don't create `~/.vimrc` or `~/.vim/vimrc`, or they would shadow it.

## Relationship to Neovim

Neovim (`../nvim/`) is the full editor.
This Vim/IdeaVim config deliberately mirrors its keybindings so switching between Neovim, plain Vim, and Android Studio feels the same.
