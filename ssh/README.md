# SSH

## What it is

Client configuration for OpenSSH.

## Why it's here

Central SSH client defaults and per-host settings, tracked so key handling and connection behavior are identical everywhere.
Config only - private keys live in `~/.ssh` and are NEVER tracked (see the repo root README "Secrets" section).

## What's here

- `config` -> `~/.ssh/config`:
  - `github.com` - Ed25519 auth key with post-quantum key exchange (mlkem768x25519).
    The passphrase is added to the agent for 12h then auto-removed, and is deliberately NOT persisted in the macOS keychain (that would make the 12h expiry meaningless).
  - `Host *` - agent + keychain defaults and keepalive settings so idle connections don't drop.

## Setup note

`install.sh` forces `~/.ssh` to `0700`.
Add new per-host blocks to `config` as you set up machines and keys.
