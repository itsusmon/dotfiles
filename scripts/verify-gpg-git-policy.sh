#!/bin/bash

set -euo pipefail
set +x
umask 077

dotfiles_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
wrapper="$dotfiles_dir/scripts/bin/gpg-git-sign"
hook="$dotfiles_dir/config/git/hooks/pre-push"
identities="$dotfiles_dir/config/git/signing-identities.sh"
installed_identities="${XDG_CONFIG_HOME:-"$HOME/.config"}/git/signing-identities.sh"
git_bin=$(command -v git || true)
temporary_root=${TMPDIR:-/tmp}
temporary_root=${temporary_root%/}

if [[ -z "$git_bin" || ! -x "$git_bin" ]]; then
  printf '%s\n' 'error: Git is required to verify the GPG Git policy.' >&2
  printf '%s\n' 'Fix: install Git and confirm `command -v git` succeeds.' >&2
  exit 2
fi
if [[ ! -r "$installed_identities" ]]; then
  printf 'error: installed identity configuration is unavailable: %s\n' \
    "$installed_identities" >&2
  printf '%s\n' 'Fix: run the dotfiles installer before this verification.' >&2
  exit 2
fi

temporary_dir=$(mktemp -d "$temporary_root/verify-gpg-git-policy.XXXXXX")

cleanup() {
  rm -rf "$temporary_dir"
}
trap cleanup EXIT

/bin/bash -n "$wrapper"
/bin/bash -n "$hook"
/bin/bash -n "$identities"

. "$identities"
gpg_git_load_identities

set +e
duplicate_error=$(
  (
    GPG_GIT_IDENTITIES+=("${GPG_GIT_IDENTITIES[0]}")
    gpg_git_load_identities
  ) 2>&1
)
duplicate_status=$?
set -e
if [[ "$duplicate_status" -ne 2 ||
      "$duplicate_error" != *'repeats email'* ||
      "$duplicate_error" != *'Fix:'* ]]; then
  printf '%s\n' 'error: duplicate identity configuration did not produce actionable diagnostics' >&2
  exit 1
fi

for index in "${!gpg_git_identity_emails[@]}"; do
  email=${gpg_git_identity_emails[$index]}
  fingerprint=${gpg_git_identity_fingerprints[$index]}
  host=${gpg_git_identity_hosts[$index]}
  repo="$temporary_dir/success-$index"

  "$git_bin" init -q -b main "$repo"
  "$git_bin" -C "$repo" config user.name 'Usmonjon Abdurakhmanov'
  "$git_bin" -C "$repo" config user.email "$email"
  "$git_bin" -C "$repo" config gpg.format openpgp
  "$git_bin" -C "$repo" config gpg.openpgp.program "$wrapper"
  "$git_bin" -C "$repo" config commit.gpgsign true
  "$git_bin" -C "$repo" remote add origin "https://$host/example/policy-test.git"
  "$git_bin" -C "$repo" commit --allow-empty -m "Signing policy test $index" >/dev/null
  commit_oid=$("$git_bin" -C "$repo" rev-parse HEAD)

  signature_status=$("$git_bin" -C "$repo" show -s --format='%G?' "$commit_oid")
  signing_fingerprint=$("$git_bin" -C "$repo" show -s --format='%GF' "$commit_oid")
  signing_primary=$("$git_bin" -C "$repo" show -s --format='%GP' "$commit_oid")
  [[ "$signature_status" == G || "$signature_status" == U ]] || {
    printf 'error: configured identity %s produced signature status %s\n' \
      "$email" "$signature_status" >&2
    exit 1
  }
  [[ "$signing_fingerprint" == "$fingerprint" ]] || {
    printf 'error: configured identity %s used signing fingerprint %s\n' \
      "$email" "$signing_fingerprint" >&2
    exit 1
  }
  [[ "$signing_primary" == "$GPG_GIT_PRIMARY_FINGERPRINT" ]] || {
    printf 'error: configured identity %s used primary fingerprint %s\n' \
      "$email" "$signing_primary" >&2
    exit 1
  }

  (
    cd "$repo"
    printf 'refs/heads/main %s refs/heads/main %040d\n' "$commit_oid" 0 |
      "$hook" origin "https://$host/example/policy-test.git"
  )
done

test_email=${gpg_git_identity_emails[0]}
test_host=${gpg_git_identity_hosts[0]}
failure_repo="$temporary_dir/failure"
"$git_bin" init -q -b main "$failure_repo"
"$git_bin" -C "$failure_repo" config user.name 'Usmonjon Abdurakhmanov'
"$git_bin" -C "$failure_repo" config user.email "$test_email"
"$git_bin" -C "$failure_repo" remote add origin "https://$test_host/example/policy-test.git"
"$git_bin" -C "$failure_repo" -c commit.gpgsign=false \
  commit --allow-empty -m 'Unsigned policy test' >/dev/null
unsigned_oid=$("$git_bin" -C "$failure_repo" rev-parse HEAD)

(
  cd "$failure_repo"
  if printf 'refs/heads/main %s refs/heads/main %040d\n' "$unsigned_oid" 0 |
    "$hook" origin "https://$test_host/example/policy-test.git" >/dev/null 2>&1; then
    printf '%s\n' 'error: unsigned configured-identity commit was accepted' >&2
    exit 1
  fi
)

"$git_bin" -C "$failure_repo" remote set-url origin \
  "https://$test_host.evil.example/example/policy-test.git"
(
  cd "$failure_repo"
  set +e
  lookalike_error=$(
    : | "$hook" origin \
      "https://$test_host.evil.example/example/policy-test.git" 2>&1
  )
  lookalike_status=$?
  set -e
  if [[ "$lookalike_status" -eq 0 ||
        "$lookalike_error" != *'Configured host for this identity:'* ||
        "$lookalike_error" != *'Fix:'* ]]; then
    printf '%s\n' 'error: lookalike host was accepted' >&2
    exit 1
  fi
)

"$git_bin" -C "$failure_repo" config user.email other@example.com
(
  cd "$failure_repo"
  set +e
  unsupported_error=$(
    "$wrapper" -bsau "$GPG_GIT_PRIMARY_FINGERPRINT" </dev/null 2>&1
  )
  unsupported_status=$?
  set -e
  if [[ "$unsupported_status" -eq 0 ||
        "$unsupported_error" != *'unsupported user.email'* ||
        "$unsupported_error" != *'Fix:'* ]]; then
    printf '%s\n' 'error: unsupported email did not produce actionable diagnostics' >&2
    exit 1
  fi
)

"$git_bin" -C "$failure_repo" config user.email "$test_email"
"$git_bin" -C "$failure_repo" remote set-url origin \
  "https://$test_host/example/policy-test.git"
printf '#!/bin/sh\nexit 42\n' > "$failure_repo/.git/hooks/pre-push"
chmod 755 "$failure_repo/.git/hooks/pre-push"
(
  cd "$failure_repo"
  set +e
  : | "$hook" origin "https://$test_host/example/policy-test.git" >/dev/null 2>&1
  result=$?
  set -e
  if [[ "$result" -ne 42 ]]; then
    printf 'error: repository hook exit 42 became %s\n' "$result" >&2
    exit 1
  fi
)

printf 'GPG Git policy verification passed for %s configured identities\n' \
  "${#gpg_git_identity_emails[@]}"
