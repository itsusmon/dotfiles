#!/usr/bin/env bash

set -u

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
quiet_build="$repo_dir/scripts/bin/quiet-build"
test_dir="$(mktemp -d)" || exit 1

cleanup() {
  rm -rf "$test_dir"
}

fail() {
  printf '%s\n' "FAIL: $1" >&2
  exit 1
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# shellcheck disable=SC2016 # The literal dollar sign tests argument preservation.
argument='value with spaces & * ? [brackets] $dollar "quote"'
success_output="$(
  # shellcheck disable=SC2016 # Positional parameters expand in the child shell.
  EXPECTED_ARGUMENT="$argument" "$quiet_build" -- bash -c '
    [[ "$1" == "$EXPECTED_ARGUMENT" ]] || exit 91
    printf "%s\n" "hidden stdout"
    printf "%s\n" "hidden stderr" >&2
  ' _ "$argument"
)" || fail "successful command failed"
[[ "$success_output" == "BUILD SUCCESSFUL" ]] ||
  fail "success output was not exactly one BUILD SUCCESSFUL line"

help_output="$("$quiet_build" --help)" || fail "--help failed"
[[ "$help_output" == *"Usage: quiet-build [--] <command> [arguments...]"* ]] ||
  fail "--help did not print usage"
[[ "$help_output" == *"Discards captured stdout and stderr"* ]] ||
  fail "--help did not describe successful command behavior"
[[ "$help_output" == *"preserves the command's exit status"* ]] ||
  fail "--help did not describe failing command behavior"
[[ "$help_output" == *"Do not use it for interactive commands"* ]] ||
  fail "--help did not describe when the wrapper should not be used"

failure_stdout="$test_dir/failure.stdout"
failure_stderr="$test_dir/failure.stderr"
if "$quiet_build" bash -c '
  printf "%s\n" "failure stdout"
  printf "%s\n" "failure stderr" >&2
  exit 37
' >"$failure_stdout" 2>"$failure_stderr"; then
  fail "failing command reported success"
else
  failure_status=$?
fi
[[ "$failure_status" == 37 ]] || fail "failing command did not preserve exit status 37"
[[ ! -s "$failure_stdout" ]] || fail "failing command wrote to stdout"
[[ "$(<"$failure_stderr")" == $'failure stdout\nfailure stderr' ]] ||
  fail "failing command did not display complete stdout and stderr"

usage_stderr="$test_dir/usage.stderr"
if "$quiet_build" >"$test_dir/usage.stdout" 2>"$usage_stderr"; then
  fail "empty command reported success"
else
  usage_status=$?
fi
[[ "$usage_status" == 2 ]] || fail "empty command did not exit with status 2"
[[ "$(<"$usage_stderr")" == "Usage: quiet-build [--] <command> [arguments...]" ]] ||
  fail "empty command did not print the expected usage"

interrupt_dir="$test_dir/interrupt logs"
mkdir -p "$interrupt_dir"
# shellcheck disable=SC2016 # PPID expands in the child shell.
if TMPDIR="$interrupt_dir" "$quiet_build" bash -c 'kill -TERM "$PPID"' \
  >"$test_dir/interrupt.stdout" 2>"$test_dir/interrupt.stderr"; then
  fail "interrupted command reported success"
else
  interrupt_status=$?
fi
[[ "$interrupt_status" == 143 ]] || fail "TERM did not produce exit status 143"
[[ -z "$(find "$interrupt_dir" -type f -print)" ]] ||
  fail "temporary log remained after interruption"

repo_copy="$test_dir/repository with spaces"
mkdir -p "$repo_copy/scripts/bin"
cp "$repo_dir/install.sh" "$repo_copy/install.sh"
cp "$quiet_build" "$repo_copy/scripts/bin/quiet-build"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$repo_copy/scripts/bin/nvim-app"
chmod +x "$repo_copy/scripts/bin/nvim-app"
: >"$repo_copy/dotfiles.conf"

test_home="$test_dir/home directory"
bin_home="$test_home/.local/bin"
mkdir -p "$test_home"
HOME="$test_home" "$repo_copy/install.sh" >/dev/null ||
  fail "installer failed with an isolated nvim-app stub"
installed="$bin_home/quiet-build"
expected_source="$repo_copy/scripts/bin/quiet-build"
[[ -L "$installed" && "$(readlink "$installed")" == "$expected_source" ]] ||
  fail "installation did not create the expected absolute symlink"

HOME="$test_home" "$repo_copy/install.sh" >/dev/null ||
  fail "second installer run failed"
[[ -L "$installed" && "$(readlink "$installed")" == "$expected_source" ]] ||
  fail "second installation changed the correct symlink"

rm -f "$installed"
ln -s "$repo_copy/wrong-target" "$installed"
HOME="$test_home" "$repo_copy/install.sh" >/dev/null ||
  fail "installer failed while refreshing an incorrect symlink"
[[ -L "$installed" && "$(readlink "$installed")" == "$expected_source" ]] ||
  fail "installation did not refresh an incorrect symlink"

collision_home="$test_dir/collision home"
collision_bin="$collision_home/.local/bin"
mkdir -p "$collision_bin"
printf '%s\n' "keep me" >"$collision_bin/quiet-build"
if HOME="$collision_home" "$repo_copy/install.sh" \
  >"$test_dir/collision.stdout" 2>"$test_dir/collision.stderr"; then
  fail "installation accepted an unrelated destination file"
fi
[[ ! -L "$collision_bin/quiet-build" ]] ||
  fail "installation replaced an unrelated destination file with a symlink"
[[ "$(<"$collision_bin/quiet-build")" == "keep me" ]] ||
  fail "installation changed an unrelated destination file"
[[ "$(<"$test_dir/collision.stderr")" == *"already exists and is not a symlink"* ]] ||
  fail "installation collision did not report a clear error"

printf '%s\n' "quiet-build verification passed"
