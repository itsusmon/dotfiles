# Ghostty

## What it is

Ghostty is a fast, GPU-accelerated terminal emulator.

## Why I use it

It is the daily-driver terminal.
It gives a native macOS feel, GPU rendering, and built-in splits/tabs plus shell integration (prompt marking, jump-to-prompt) without needing tmux for basic pane management.
It pairs with the kanata `Hyper+Return` binding so a terminal is always one chord away.

## What's here

- `config` -> `~/.config/ghostty/config` - the single Ghostty config file.

Key choices:

- Font: JetBrainsMono Nerd Font Mono, 14pt (the Nerd Font supplies prompt/glyph icons).
- Look: transparent titlebar, subtle padding, dimmed unfocused splits.
- macOS: `macos-option-as-alt` so Alt keybindings work; window state is restored across restarts.
- Shell integration: `detect`, enabling prompt jumping (Cmd+Up/Down) and semantic zones.
- Quick Terminal: a drop-down terminal on Cmd+` (backtick).
- Keybindings: `super+...` (Cmd) for splits, tabs, split navigation/resize, search, and config reload.

## Working with it

- Reload config in-app: Cmd+Shift+, .
- Open config in-app: Cmd+, .
