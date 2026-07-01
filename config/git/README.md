# Git

## What it is

Configuration for Git, the version control system.

## Why it's here

Machine-wide Git defaults kept in one tracked place so every machine behaves identically: identity, line-ending policy, ignore rules, and attributes.
These use the XDG path `~/.config/git/` rather than the legacy `~/.gitconfig`.

## What's here

- `config` -> `~/.config/git/config` - user identity (name/email) and `core.autocrlf = input` (store LF in the repo, don't rewrite on checkout).
- `ignore` -> `~/.config/git/ignore` - the global gitignore.
  Currently ignores `**/.claude/settings.local.json` so machine-local Claude settings never get committed to any repo.
- `attributes` -> `~/.config/git/attributes` - the global gitattributes.
  Enforces LF line endings for text/source files and marks binaries, so line endings stay consistent across macOS/Linux/Windows checkouts.
