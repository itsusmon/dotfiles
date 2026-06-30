#!/usr/bin/env bash
#
# install.sh — link dotfiles from ~/.dotfiles into their target locations.
#
# Reads dotfiles.conf, one "SOURCE  TARGET" pair per line, where SOURCE is
# relative to this repo and TARGET is relative to $HOME. For each pair it
# creates a symlink at TARGET pointing at SOURCE.
#
# Only individual *files* are ever symlinked. When SOURCE is a directory,
# every file beneath it is linked one by one and the directory tree at the
# target is created as real directories. That way an app can drop generated
# files (locks, caches, state) alongside the linked files without polluting
# this repo, and the repo never owns a whole config directory.
#
# Safe to re-run: links that already point at the right place are left alone,
# and any real file or stale link in the way is moved into .backups/ first.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$DOTFILES_DIR/dotfiles.conf"
BACKUP_DIR="$DOTFILES_DIR/.backups/$(date +%Y%m%d-%H%M%S)"

if [[ -t 1 ]]; then
  C_B=$'\e[34m'; C_G=$'\e[32m'; C_Y=$'\e[33m'; C_R=$'\e[31m'; C_DIM=$'\e[2m'; C_X=$'\e[0m'
else
  C_B=; C_G=; C_Y=; C_R=; C_DIM=; C_X=
fi

info() { printf '%s%s%s\n'        "$C_B"  "$1" "$C_X"; }
ok()   { printf '  %s✓%s %s\n'    "$C_G"  "$C_X" "$1"; }
warn() { printf '  %s!%s %s\n'    "$C_Y"  "$C_X" "$1"; }
skip() { printf '  %s· %s%s\n'    "$C_DIM" "$1" "$C_X"; }
die()  { printf '%s%s%s\n'        "$C_R"  "$1" "$C_X" >&2; exit 1; }

linked=0; skipped=0; backed=0

# link_file SOURCE_ABS TARGET_ABS LABEL
link_file() {
  local source_path="$1" target_path="$2" label="$3" rel

  if [[ ! -e "$source_path" ]]; then
    warn "source missing, skipping: $label"; return
  fi

  # Already pointing where it should — nothing to do.
  if [[ -L "$target_path" && "$(readlink "$target_path")" == "$source_path" ]]; then
    skip "$label"; skipped=$((skipped + 1)); return
  fi

  # Make sure the parent exists as a real directory.
  mkdir -p "$(dirname "$target_path")"

  # Move anything real (or a stale link) out of the way, preserving structure.
  if [[ -e "$target_path" || -L "$target_path" ]]; then
    rel="${target_path#"$HOME"/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$target_path" "$BACKUP_DIR/$rel"
    warn "backed up existing $label"
    backed=$((backed + 1))
  fi

  ln -s "$source_path" "$target_path"
  ok "$label"
  linked=$((linked + 1))
}

main() {
  [[ -f "$MANIFEST" ]] || die "No manifest at $MANIFEST"
  info "Linking dotfiles from ${DOTFILES_DIR/#$HOME/~}"

  local src tgt source_path f rel
  while read -r src tgt || [[ -n "$src" ]]; do
    [[ -z "${src// }" || "$src" == \#* ]] && continue
    [[ -z "${tgt:-}" ]] && { warn "no target for '$src', skipping"; continue; }

    source_path="$DOTFILES_DIR/$src"

    if [[ -d "$source_path" ]]; then
      # Directory: link each file under it individually.
      while IFS= read -r f; do
        rel="${f#"$source_path"/}"
        link_file "$f" "$HOME/$tgt/$rel" "$tgt/$rel"
      done < <(find "$source_path" -type f -not -name '.DS_Store' | sort)
    else
      link_file "$source_path" "$HOME/$tgt" "$tgt"
    fi
  done < "$MANIFEST"

  # Harden permissions on security-sensitive dirs we may have just created.
  # SSH and GnuPG refuse to work (or warn loudly) unless their home dir is 0700.
  local secure_dir
  for secure_dir in "$HOME/.ssh" "$HOME/.gnupg"; do
    if [[ -d "$secure_dir" ]]; then chmod 700 "$secure_dir"; fi
  done

  info "Done: $linked linked, $skipped current, $backed backed up"
  if [[ "$backed" -gt 0 ]]; then
    info "Backups: ${BACKUP_DIR/#$HOME/~}"
  fi
}

main "$@"
