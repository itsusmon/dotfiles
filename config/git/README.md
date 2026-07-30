# Git

## What it is

Configuration for Git, the version control system.

## Why it's here

Machine-wide Git defaults kept in one tracked place so every machine behaves identically: identity, line-ending policy, ignore rules, and attributes.
These use the XDG path `~/.config/git/` rather than the legacy `~/.gitconfig`.

## What's here

- `config` -> `~/.config/git/config` - user identity, OpenPGP signing policy, shared hook path, and `core.autocrlf = input`.
- `ignore` -> `~/.config/git/ignore` - the global gitignore.
  Currently ignores `**/.claude/settings.local.json` so machine-local Claude settings never get committed to any repo.
- `attributes` -> `~/.config/git/attributes` - the global gitattributes.
  Enforces LF line endings for text/source files and marks binaries, so line endings stay consistent across macOS/Linux/Windows checkouts.
- `hooks/pre-push` -> `~/.config/git/hooks/pre-push` - validates Usmonjon's commit signatures and exact push hosts, then chains repository-local hooks.
- `../../scripts/bin/gpg-git-sign` -> `~/.local/bin/gpg-git-sign` - selects the exact GitHub or SQB signing subkey from the repository email.
