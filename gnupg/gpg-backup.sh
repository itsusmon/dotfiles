#!/usr/bin/env bash
# gpg-backup.sh - full backup / restore of the local GnuPG identity.
#
# Usage:
#   gpg-backup.sh backup  <dir>   export everything into <dir>
#   gpg-backup.sh restore <dir>   import everything from <dir> into ~/.gnupg
#
# A backup folder contains:
#   secret-keys.asc     every secret key (passphrase protection is preserved)
#   public-keys.asc     the full public keyring (own keys + everyone imported)
#   ownertrust.txt      the trust database, as ownertrust values
#   openpgp-revocs.d/   pre-generated revocation certificates
#   manifest.txt        primary-key fingerprints, used to verify a restore
#
# Restore only needs gpg on the target machine: it recreates $GNUPGHOME with
# the permissions GnuPG demands and verifies every manifest key is usable.
# Config files (gpg.conf, gpg-agent.conf) are not backed up - they come from
# this dotfiles repo via install.sh.
#
# WARNING: the backup holds private keys in plain text, and a key that has no
# passphrase of its own is fully exposed. Keep it on encrypted storage, or wrap
# it:  tar -C <dir> -cf - . | gpg -c > gpg-backup.tar.gpg

set -euo pipefail

export GNUPGHOME="${GNUPGHOME:-$HOME/.gnupg}"

die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }

# Fingerprints of primary keys that have a secret part.
secret_fprs() {
  gpg --list-secret-keys --with-colons 2>/dev/null |
    awk -F: '$1 == "sec" { want = 1 } $1 == "fpr" && want { print $10; want = 0 }'
}

backup() {
  local dir=$1 fprs tmp fpr
  fprs=$(secret_fprs)
  [ -n "$fprs" ] || die "no secret keys in $GNUPGHOME - nothing to back up"

  mkdir -p "$dir" || die "cannot create $dir"
  chmod 700 "$dir"
  tmp=$(mktemp -d "$dir/.gpg-backup.XXXXXX")
  trap 'rm -rf "$tmp"' EXIT

  info "exporting secret keys (pinentry may ask for key passphrases)"
  gpg --export-secret-keys --armor > "$tmp/secret-keys.asc"
  grep -q 'BEGIN PGP PRIVATE KEY BLOCK' "$tmp/secret-keys.asc" ||
    die "secret-key export came out empty (passphrase prompt cancelled?)"

  info "exporting public keyring and ownertrust"
  gpg --export --armor > "$tmp/public-keys.asc"
  gpg --export-ownertrust > "$tmp/ownertrust.txt"

  if [ -d "$GNUPGHOME/openpgp-revocs.d" ]; then
    mkdir -p "$tmp/openpgp-revocs.d"
    find "$GNUPGHOME/openpgp-revocs.d" -name '*.rev' \
      -exec cp -p {} "$tmp/openpgp-revocs.d/" \;
  fi

  {
    printf '# gpg-backup %s | %s\n' \
      "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$(gpg --version | head -n 1)"
    printf '%s\n' "$fprs"
  } > "$tmp/manifest.txt"

  # A cancelled pinentry mid-export leaves a file that parses but is missing
  # keys, so verify the export really contains every key before keeping it.
  for fpr in $fprs; do
    gpg --show-keys --with-colons "$tmp/secret-keys.asc" | grep -q "^fpr:.*:$fpr:" ||
      die "exported secret-keys.asc is missing key $fpr"
  done

  chmod 600 "$tmp"/*.asc "$tmp"/*.txt
  # Replace any previous backup only now, after every export and check passed.
  rm -rf "$dir/secret-keys.asc" "$dir/public-keys.asc" "$dir/ownertrust.txt" \
         "$dir/manifest.txt" "$dir/openpgp-revocs.d"
  mv "$tmp"/* "$dir"/
  rmdir "$tmp"
  trap - EXIT

  info "backed up $(printf '%s\n' "$fprs" | wc -l | tr -d ' ') key(s) to $dir"
  info "WARNING: private keys are in plain text - keep this folder on encrypted storage"
}

restore() {
  local dir=$1 fpr missing=0
  [ -d "$dir" ] || die "backup folder not found: $dir"
  [ -f "$dir/secret-keys.asc" ] && [ -f "$dir/manifest.txt" ] ||
    die "$dir does not look like a gpg-backup folder (secret-keys.asc or manifest.txt missing)"

  # Fresh machine: create the home dir with the permissions GnuPG demands.
  mkdir -p "$GNUPGHOME"
  chmod 700 "$GNUPGHOME"
  [ -e "$GNUPGHOME/gpg.conf" ] ||
    info "note: no gpg.conf in $GNUPGHOME - run dotfiles install.sh for the usual settings (keys work without it)"

  # Drop any stale agent so nothing cached from a previous keyring interferes.
  gpgconf --kill gpg-agent 2>/dev/null || true

  if [ -f "$dir/public-keys.asc" ]; then
    info "importing public keys"
    gpg --import "$dir/public-keys.asc"
  fi

  info "importing secret keys (their passphrase protection travels with them; no prompt)"
  gpg --batch --import "$dir/secret-keys.asc"

  if [ -f "$dir/ownertrust.txt" ]; then
    info "restoring ownertrust"
    gpg --import-ownertrust "$dir/ownertrust.txt"
    gpg --check-trustdb
  fi

  if [ -d "$dir/openpgp-revocs.d" ]; then
    info "restoring revocation certificates"
    mkdir -p "$GNUPGHOME/openpgp-revocs.d"
    chmod 700 "$GNUPGHOME/openpgp-revocs.d"
    find "$dir/openpgp-revocs.d" -name '*.rev' \
      -exec cp -p {} "$GNUPGHOME/openpgp-revocs.d/" \;
    chmod 600 "$GNUPGHOME/openpgp-revocs.d"/*.rev
  fi

  # Every key recorded at backup time must now exist with its secret part.
  while IFS= read -r fpr; do
    case $fpr in '' | '#'*) continue ;; esac
    if gpg --list-secret-keys "$fpr" >/dev/null 2>&1; then
      info "restored $fpr"
    else
      printf 'error: key %s did not restore\n' "$fpr" >&2
      missing=1
    fi
  done < "$dir/manifest.txt"
  [ "$missing" -eq 0 ] || die "restore incomplete - see errors above"

  info "restore complete - keyring at $GNUPGHOME"
}

command -v gpg >/dev/null 2>&1 || die "gpg is not installed"

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
