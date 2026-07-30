# GnuPG

## What it is

Configuration for GnuPG (GPG), used for encryption and signing (for example signed Git commits or encrypted files).

## Why it's here

Consistent, hardened GPG defaults across machines.
Config only - private keys and keyrings live in `~/.gnupg` and are NEVER tracked (see the repo root README "Secrets" section).

## What's here

- `gpg.conf` -> `~/.gnupg/gpg.conf` - strong algorithm preferences (AES256, SHA512), long key-id/fingerprint display, and tidy output.
- `gpg-agent.conf` -> `~/.gnupg/gpg-agent.conf` - `pinentry-mac`, five-minute idle and fifteen-minute maximum caching, no signing cache, no loopback or external password cache, and no smart-card daemon.

The current daily keyring does not contain the certification private key.
No certification-key backup is tracked or managed by this repository.

## Setup note

`install.sh` forces `~/.gnupg` to `0700`, which GnuPG requires or it refuses to run.
