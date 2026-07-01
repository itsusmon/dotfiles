# dotfiles

Personal configuration, tracked in one place and symlinked into the locations each tool expects.

## Tools

Each tool has its own README with what it is, why it's used, and how the config is set up.

| Tool | What it's for | Config |
| ---- | ------------- | ------ |
| [Zsh](config/zsh/README.md) | Shell + prompt, modular fast-startup setup | `config/zsh/`, `zshenv`, `zshrc`, `zprofile` |
| [Ghostty](config/ghostty/README.md) | GPU terminal emulator (daily driver) | `config/ghostty/` |
| [kanata](config/kanata/README.md) | Keyboard remapper: Caps -> Esc / Hyper, app launchers | `config/kanata/` |
| [Neovim](config/nvim/README.md) | Main text editor (Lua + lazy.nvim) | `config/nvim/` |
| [Vim / IdeaVim](config/vim/README.md) | Shared Vim config for real Vim + JetBrains IDEs | `config/vim/` |
| [Git](config/git/README.md) | Version control identity + line-ending / ignore policy | `config/git/` |
| [OpenCode](config/opencode/README.md) | Terminal AI coding agent | `config/opencode/` |
| [Gradle](gradle/README.md) | Global JVM / Android build tuning | `gradle/` |
| [SSH](ssh/README.md) | SSH client config (private keys stay untracked) | `ssh/` |
| [GnuPG](gnupg/README.md) | GPG signing / encryption defaults (keys untracked) | `gnupg/` |
| [Agent instructions](AGENT.md) | Shared AI-agent rules (Claude / Gemini / OpenCode) | `AGENT.md` |

## How it works

The real files live in this repo with plain, visible names (`zshrc`, not `.zshrc`).
[`dotfiles.conf`](dotfiles.conf) maps each source to its target under `$HOME`, and
[`install.sh`](install.sh) creates the symlinks.

Only individual **files** are ever symlinked.
When a manifest entry points at a directory, every file beneath it is linked one by one and the
directory tree at the target is created as real directories.
That keeps app-generated junk (lock files, caches, state) out of this repo while still letting the
app write next to the linked files.

## Usage

```sh
git clone <repo> ~/.dotfiles
~/.dotfiles/install.sh
```

`install.sh` is idempotent:

- links already pointing at the right place are left alone
- anything real (or a stale link) in the way is moved into `.backups/<timestamp>/` first

## Adding a new dotfile

1. Move the file into this repo, mirroring its `$HOME` path but dropping the leading dot
   (e.g. `~/.config/foo/bar` → `~/.dotfiles/config/foo/bar`).
2. Add a `SOURCE  TARGET` line to [`dotfiles.conf`](dotfiles.conf).
3. Run `./install.sh`.

## Layout

```
zshenv, zshrc, zprofile        → ~/.zshenv, ~/.zshrc, ~/.zprofile
config/zsh/                    → ~/.config/zsh/*.zsh (sourced by ~/.zshrc)
config/git/                    → ~/.config/git/config, ignore, attributes
config/ghostty/config          → ~/.config/ghostty/config
config/nvim/                   → ~/.config/nvim/ (lua config; lazy-lock.json stays app-managed)
config/vim/                    → ~/.config/vim/ (vimrc + colors) and ~/.config/ideavim/ideavimrc (mirrors the nvim setup)
config/opencode/               → ~/.config/opencode/opencode.jsonc, tui.json
gradle/gradle.properties       → ~/.gradle/gradle.properties
ssh/config                     → ~/.ssh/config
gnupg/gpg.conf, gpg-agent.conf → ~/.gnupg/gpg.conf, ~/.gnupg/gpg-agent.conf
AGENT.md                       → ~/.claude/CLAUDE.md, ~/.gemini/GEMINI.md, ~/.config/opencode/AGENTS.md
```

## Secrets

Only **config** is tracked, never key material. `install.sh` forces `~/.ssh` and `~/.gnupg`
to `0700`, and [`.gitignore`](.gitignore) refuses to stage private keys, keyrings, and GnuPG
runtime state even if one is ever copied into the repo by accident.
