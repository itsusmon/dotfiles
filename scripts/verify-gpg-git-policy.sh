#!/bin/bash

set -euo pipefail
set +x
umask 077

dotfiles_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
wrapper="$dotfiles_dir/scripts/bin/gpg-git-sign"
hook="$dotfiles_dir/config/git/hooks/pre-push"
temporary_dir=$(mktemp -d /private/tmp/verify-gpg-git-policy.XXXXXX)

cleanup() {
  rm -rf "$temporary_dir"
}
trap cleanup EXIT

/bin/bash -n "$wrapper"
/bin/bash -n "$hook"

repo="$temporary_dir/repo"
/usr/bin/git init -q -b main "$repo"
/usr/bin/git -C "$repo" config user.name 'Usmonjon Abdurakhmanov'
/usr/bin/git -C "$repo" config user.email heyitsusmon@gmail.com
/usr/bin/git -C "$repo" remote add origin https://github.com/heyitsusmon/local-policy-test.git
/usr/bin/git -C "$repo" -c commit.gpgsign=false commit --allow-empty -m 'Unsigned policy test' >/dev/null
commit_oid=$(/usr/bin/git -C "$repo" rev-parse HEAD)

cd "$repo"
if printf 'refs/heads/main %s refs/heads/main %040d\n' "$commit_oid" 0 |
  "$hook" origin https://github.com/heyitsusmon/local-policy-test.git >/dev/null 2>&1; then
  printf '%s\n' 'error: unsigned personal commit was accepted' >&2
  exit 1
fi

/usr/bin/git remote set-url origin https://github.com.evil.example/heyitsusmon/local-policy-test.git
if : | "$hook" origin https://github.com.evil.example/heyitsusmon/local-policy-test.git >/dev/null 2>&1; then
  printf '%s\n' 'error: GitHub lookalike host was accepted' >&2
  exit 1
fi

/usr/bin/git config user.email other@example.com
if "$wrapper" -bsau 4F430EF8893AE3D330C5B8BE14FC48F9BBE08171 </dev/null >/dev/null 2>&1; then
  printf '%s\n' 'error: unsupported email was accepted by the signing wrapper' >&2
  exit 1
fi

/usr/bin/git config user.email heyitsusmon@gmail.com
/usr/bin/git remote set-url origin https://github.com/heyitsusmon/local-policy-test.git
printf '#!/bin/sh\nexit 42\n' > "$repo/.git/hooks/pre-push"
chmod 755 "$repo/.git/hooks/pre-push"
set +e
: | "$hook" origin https://github.com/heyitsusmon/local-policy-test.git >/dev/null 2>&1
result=$?
set -e
if [[ "$result" -ne 42 ]]; then
  printf 'error: repository hook exit 42 became %s\n' "$result" >&2
  exit 1
fi

printf '%s\n' 'GPG Git policy verification passed'
