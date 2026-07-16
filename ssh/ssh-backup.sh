#!/usr/bin/env bash
# ssh-backup.sh - full backup / restore of the local SSH identity.
#
# Usage:
#   ssh-backup.sh backup  <dir>   copy everything into <dir>
#   ssh-backup.sh restore <dir>   copy everything from <dir> into ~/.ssh
#
# A backup folder contains every regular file from ~/.ssh (private keys,
# public keys, known_hosts, authorized_keys, ...) plus:
#   manifest.txt   sha256 of every file, used to verify backup and restore
#
# Skipped on purpose: symlinks (config comes from this dotfiles repo via
# install.sh) and directories (agent / control sockets are runtime state).
#
# Restore only needs OpenSSH on the target machine: it recreates ~/.ssh with
# the permissions OpenSSH demands, verifies every file against the manifest,
# and moves aside (never overwrites) an existing file whose content differs.
#
# WARNING: the backup holds private keys as-is; a key that has no passphrase
# of its own is fully exposed. Keep it on encrypted storage, or wrap it:
#   tar -C <dir> -cf - . | gpg -c > ssh-backup.tar.gpg

set -euo pipefail

SSH_DIR="${SSH_DIR:-$HOME/.ssh}"

die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }

sha() { shasum -a 256 "$1" | awk '{print $1}'; }

is_private_key() { grep -q 'PRIVATE KEY' "$1" 2>/dev/null; }

backup() {
  local dir=$1 tmp f name keys=0 files=0
  [ -d "$SSH_DIR" ] || die "$SSH_DIR does not exist"
  find "$SSH_DIR" -maxdepth 1 -type f -exec grep -l 'PRIVATE KEY' {} + 2>/dev/null | grep -q . ||
    die "no private keys in $SSH_DIR - nothing to back up"

  mkdir -p "$dir" || die "cannot create $dir"
  chmod 700 "$dir"
  tmp=$(mktemp -d "$dir/.ssh-backup.XXXXXX")
  trap 'rm -rf "$tmp"' EXIT

  printf '# ssh-backup %s | %s\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$(ssh -V 2>&1)" > "$tmp/manifest.txt"

  # Top-level regular files only: symlinks are dotfiles-managed config and
  # directories hold runtime sockets; neither belongs in a backup.
  while IFS= read -r f; do
    name=$(basename "$f")
    [ "$name" = ".DS_Store" ] && continue
    cp -p "$f" "$tmp/$name"
    printf '%s  %s\n' "$(sha "$f")" "$name" >> "$tmp/manifest.txt"
    files=$((files + 1))
    if is_private_key "$f"; then
      keys=$((keys + 1))
      info "private key $name: $(ssh-keygen -l -f "$f" </dev/null)"
    fi
  done < <(find "$SSH_DIR" -maxdepth 1 -type f | sort)

  # Verify every staged copy against the manifest before keeping anything.
  while read -r hash name; do
    [ "$(sha "$tmp/$name")" = "$hash" ] || die "staged copy of $name is corrupt"
  done < <(grep -v '^#' "$tmp/manifest.txt")

  chmod 600 "$tmp"/*
  # Replace any previous backup only now, after every copy and check passed.
  find "$dir" -maxdepth 1 ! -path "$dir" ! -path "$tmp" -exec rm -rf {} +
  mv "$tmp"/* "$dir"/
  rmdir "$tmp"
  trap - EXIT

  info "backed up $files file(s) ($keys private key(s)) to $dir"
  info "WARNING: private keys are stored as-is - keep this folder on encrypted storage"
}

restore() {
  local dir=$1 hash name src dest ts
  [ -d "$dir" ] || die "backup folder not found: $dir"
  [ -f "$dir/manifest.txt" ] || die "$dir/manifest.txt missing - not an ssh-backup folder"

  # Fresh machine: create the dir with the permissions OpenSSH demands.
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  [ -e "$SSH_DIR/config" ] ||
    info "note: no config in $SSH_DIR - run dotfiles install.sh for the usual settings (keys work without it)"

  ts=$(date '+%Y%m%d%H%M%S')
  while read -r hash name; do
    src=$dir/$name
    dest=$SSH_DIR/$name
    [ -f "$src" ] || die "backup is incomplete: $name is in the manifest but missing"
    [ "$(sha "$src")" = "$hash" ] || die "backup file $name does not match its manifest hash"

    if [ -e "$dest" ] && [ "$(sha "$dest")" != "$hash" ]; then
      info "moving aside differing existing $name -> $name.pre-restore.$ts"
      mv "$dest" "$dest.pre-restore.$ts"
    fi
    cp -p "$src" "$dest"

    # Media like cloud drives can drop permissions, so re-enforce them here.
    case $name in
      *.pub) chmod 644 "$dest" ;;
      *)     chmod 600 "$dest" ;;
    esac

    [ "$(sha "$dest")" = "$hash" ] || die "restored $name does not match its manifest hash"
    if is_private_key "$dest"; then
      ssh-keygen -l -f "$dest" </dev/null >/dev/null || die "restored $name is not a valid private key"
      info "restored private key $name: $(ssh-keygen -l -f "$dest" </dev/null)"
    else
      info "restored $name"
    fi
  done < <(grep -v '^#' "$dir/manifest.txt")

  info "restore complete - keys at $SSH_DIR"
}

command -v ssh-keygen >/dev/null 2>&1 || die "openssh (ssh-keygen) is not installed"

case "${1:-}" in
  backup | restore)
    [ -n "${2:-}" ] || die "usage: $(basename "$0") ${1} <dir>"
    "$1" "$2"
    ;;
  *)
    printf 'usage: %s backup|restore <dir>\n' "$(basename "$0")" >&2
    exit 1
    ;;
esac
