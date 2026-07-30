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
- `signing-identities.sh` -> `~/.config/git/signing-identities.sh` - the shared declarative mapping from repository email to exact signing subkey and allowed push host.
- `hooks/pre-push` -> `~/.config/git/hooks/pre-push` - validates Usmonjon's commit signatures and exact push hosts, then chains repository-local hooks.
- `../../scripts/bin/gpg-git-sign` -> `~/.local/bin/gpg-git-sign` - selects the exact configured signing subkey from the repository email.

## Adding a signing identity

Add one record near the top of `signing-identities.sh`:

```sh
'email@example.com|FULL_SIGNING_SUBKEY_FINGERPRINT|exact.git.host'
```

The signing subkey must be available in the standard `~/.gnupg` keyring.
Run `scripts/verify-gpg-git-policy.sh` after every identity change.
The verification script automatically tests every configured identity.

The scripts use `${XDG_CONFIG_HOME:-$HOME/.config}` and discover `git` and `gpg` from `PATH`.
They do not assume a username, home directory, Homebrew prefix, or operating-system Git path.
Someone adopting this repository must replace the example identities with their own primary fingerprint, emails, signing-subkey fingerprints, and exact push hosts.
Configuration and policy failures include the rejected value, configuration path, and a suggested fix.
The installer places `gpg-git-sign` in `~/.local/bin`, which must be present in `PATH`.
