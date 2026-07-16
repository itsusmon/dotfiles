# GnuPG

## What it is

Configuration for GnuPG (GPG), used for encryption and signing (for example signed Git commits or encrypted files).

## Why it's here

Consistent, hardened GPG defaults across machines.
Config only - private keys and keyrings live in `~/.gnupg` and are NEVER tracked (see the repo root README "Secrets" section).

## What's here

- `gpg.conf` -> `~/.gnupg/gpg.conf` - strong algorithm preferences (AES256, SHA512), long key-id/fingerprint display, and tidy output.
- `gpg-agent.conf` -> `~/.gnupg/gpg-agent.conf` - passphrase caching (12h idle / 24h max), and `pinentry-mac` as the macOS GUI passphrase prompt (requires `brew install pinentry-mac`).
- `gpg-backup.sh` - backup and restore of the full GPG identity (all secret and public keys, ownertrust, revocation certificates).
  Not symlinked; run it from the repo: `gpg-backup.sh backup <dir>` / `gpg-backup.sh restore <dir>`.
  A restore onto a fresh machine needs nothing but gpg and the backup folder.
  The backup contains private keys in plain text, so keep it on encrypted storage.

## Setup note

`install.sh` forces `~/.gnupg` to `0700`, which GnuPG requires or it refuses to run.
