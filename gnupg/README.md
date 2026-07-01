# GnuPG

## What it is

Configuration for GnuPG (GPG), used for encryption and signing (for example signed Git commits or encrypted files).

## Why it's here

Consistent, hardened GPG defaults across machines.
Config only - private keys and keyrings live in `~/.gnupg` and are NEVER tracked (see the repo root README "Secrets" section).

## What's here

- `gpg.conf` -> `~/.gnupg/gpg.conf` - strong algorithm preferences (AES256, SHA512), long key-id/fingerprint display, and tidy output.
- `gpg-agent.conf` -> `~/.gnupg/gpg-agent.conf` - passphrase caching (12h idle / 24h max), and a commented `pinentry-mac` line for the macOS GUI passphrase prompt.
  Enable it with `brew install pinentry-mac`, then uncomment the line.

## Setup note

`install.sh` forces `~/.gnupg` to `0700`, which GnuPG requires or it refuses to run.
