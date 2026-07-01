# Zsh

## What it is

Configuration for Zsh, the default macOS shell.

## Why it's structured this way

It is split into small modules for fast startup and easy maintenance.
The root loaders (`zshenv`, `zshrc`, `zprofile`) are tiny; the real config lives in `~/.config/zsh/*.zsh` and is sourced in a deliberate order.

## The loaders (repo root, not this directory)

- `zshenv` -> `~/.zshenv` - environment variables for ALL shells (XDG dirs, `EDITOR=nvim`, cached `JAVA_HOME`, `ANDROID_HOME`).
  PATH is intentionally NOT set here, because macOS `path_helper` would reorder it afterward.
- `zshrc` -> `~/.zshrc` - the interactive loader; it sources the modules below in order.
- `zprofile` -> `~/.zprofile` - login-shell PATH additions from installers (JetBrains Toolbox, Antigravity CLI).

## Modules (sourced in this order by zshrc)

- `environment.zsh` - PATH and environment, built after `path_helper` runs.
- `options.zsh` - zsh options (history, globbing, and so on).
- `nvm.zsh` - Node Version Manager.
- `completion.zsh` - the completion system (compinit).
- `prompt.zsh` - a single-line prompt showing directory, git branch, and status via `vcs_info`.
- `zmx.zsh` - integration with `zmx` (a terminal session manager): shows the session in the prompt, adds detach/exit handling, and defines `z*` aliases.
- `keybindings.zsh` - line-editor key bindings.
- `aliases.zsh` - shortcuts (colored `ls`, safety `-i` on rm/cp/mv, `..` navigation, colored grep).
- `plugins.zsh` - autosuggestions and syntax highlighting, plus background `zcompile` for speed.
- `fzf.zsh` - fzf fuzzy-finder and bat integration, with Catppuccin colors, previews, and a bat-based MANPAGER.

## External dependencies

These are installed separately and are not tracked in this repo:

- fzf and bat (Homebrew).
- The zsh plugins under `~/.zsh/` (zsh-autosuggestions, zsh-syntax-highlighting), git-cloned.
- `zmx`, an external session-manager binary.
