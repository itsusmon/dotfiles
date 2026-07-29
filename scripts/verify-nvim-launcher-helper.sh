#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d /private/tmp/NvimLauncherHelper.XXXXXX)" || exit 1
helper_binary="$test_dir/nvim-launcher-helper"
server_pids=()

cleanup() {
  local pid

  for pid in ${server_pids+"${server_pids[@]}"}; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
  rm -rf "$test_dir"
}

forget_server() {
  local finished_pid="$1"
  local pid
  local remaining=()

  for pid in ${server_pids+"${server_pids[@]}"}; do
    [[ "$pid" == "$finished_pid" ]] || remaining+=("$pid")
  done
  server_pids=()
  if ((${#remaining[@]} > 0)); then
    server_pids=("${remaining[@]}")
  fi
}

fail() {
  printf '%s\n' "FAIL: $1" >&2
  exit 1
}

run_helper() {
  local state_dir="$1"

  shift
  NVIM_LAUNCHER_TESTING=1 \
    NVIM_LAUNCHER_STATE_DIR="$state_dir" \
    NVIM_TEST_REAL="$nvim_path" \
    "$helper_binary" "$@"
}

wait_for_file() {
  local path="$1"

  for _ in {1..100}; do
    [[ -e "$path" ]] && return
    sleep 0.05
  done
  fail "timed out waiting for $path"
}

stop_server() {
  local socket_path="$1"
  local pid="$2"

  "$nvim_wrapper" \
    --server "$socket_path" \
    --remote-expr "timer_start(0, {-> execute('qa!')})" >/dev/null 2>&1 || true
  for _ in {1..100}; do
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid" 2>/dev/null || true
      forget_server "$pid"
      return
    fi
    sleep 0.05
  done
  fail "Neovim server $pid did not exit"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

[[ "$(uname -s)" == "Darwin" ]] || {
  printf '%s\n' "Nvim launcher helper verification skipped: macOS is required"
  exit 0
}

nvim_path=""
for candidate in \
  /opt/homebrew/bin/nvim \
  /usr/local/bin/nvim \
  /usr/bin/nvim \
  "$HOME/.local/bin/nvim"; do
  if [[ -x "$candidate" ]]; then
    nvim_path="$candidate"
    break
  fi
done
[[ -n "$nvim_path" ]] || fail "Neovim is required"

"$repo_dir/scripts/bin/quiet-build" \
  /usr/bin/xcrun swiftc \
  -O \
  -parse-as-library \
  -target "$(uname -m)-apple-macosx13.0" \
  -o "$helper_binary" \
  "$repo_dir/config/nvim/launcher/NvimLauncherHelper.swift"

nvim_wrapper="$test_dir/nvim-headless"
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'exec "$NVIM_TEST_REAL" --headless --clean "$@"' \
  >"$nvim_wrapper"
chmod 700 "$nvim_wrapper"
export NVIM_TEST_REAL="$nvim_path"

/bin/sleep 0.3 &
lifecycle_target_pid=$!
lifecycle_state="$test_dir/lifecycle-state"
NVIM_LAUNCHER_TESTING=1 \
  NVIM_LAUNCHER_STATE_DIR="$lifecycle_state" \
  "$helper_binary" close-after-exit \
  "$lifecycle_target_pid" \
  test-window-does-not-exist \
  test-tab-does-not-exist \
  test-terminal-does-not-exist \
  >"$test_dir/lifecycle-output" &
lifecycle_helper_pid=$!
/bin/sleep 0.05
kill -0 "$lifecycle_helper_pid" 2>/dev/null ||
  fail "the surface cleanup helper did not wait for Neovim process exit"
wait "$lifecycle_target_pid"
wait "$lifecycle_helper_pid" ||
  fail "the surface cleanup helper failed after the process exited"
IFS=$'\t' read -r close_type close_token <"$test_dir/lifecycle-output"
[[ "$close_type" == "CLOSE_REQUEST" ]] ||
  fail "the surface cleanup helper did not publish a close request"
[[ "$(
  run_helper "$lifecycle_state" consume-close "$close_token"
)" == $'CLOSE\ttest-window-does-not-exist\ttest-tab-does-not-exist\ttest-terminal-does-not-exist' ]] ||
  fail "the one-time close request did not preserve the exact Ghostty identity hierarchy"
if run_helper "$lifecycle_state" consume-close "$close_token" \
  >"$test_dir/replayed-close-output" 2>"$test_dir/replayed-close-error"; then
  fail "a Ghostty close request could be consumed more than once"
fi
[[ -z "$(find "$lifecycle_state/close-requests" -name '*.json' -print -quit)" ]] ||
  fail "the consumed Ghostty close request was not removed"

fixture="$test_dir/fixture"
root="$fixture/project"
nested_root="$root/nested"
prefix_root="$fixture/project-backup"
mkdir -p "$nested_root" "$prefix_root"
ln -s "$root" "$fixture/project-link"
touch "$nested_root/file.txt" "$prefix_root/file.txt"

state="$test_dir/state"
encoded="$(
  run_helper "$state" canonicalize \
    "$root/../project-link//nested/../nested/file.txt"
)"
canonical="$(printf '%s' "$encoded" | /usr/bin/base64 -D)"
[[ "$canonical" == "$nested_root/file.txt" ]] ||
  fail "canonicalization did not resolve separators, components, and symlinks"
[[ "$(run_helper "$state" match-root "$nested_root/file.txt" "$root" "$nested_root")" == 1 ]] ||
  fail "the most specific nested root was not selected"
[[ "$(run_helper "$state" match-root "$prefix_root/file.txt" "$root")" == -1 ]] ||
  fail "a similar string prefix was treated as path containment"
case_file="$root/ActualCase.txt"
touch "$case_file"
if [[ -e "$root/actualcase.txt" ]]; then
  encoded_case="$(run_helper "$state" canonicalize "$root/actualcase.txt")"
  canonical_case="$(printf '%s' "$encoded_case" | /usr/bin/base64 -D)"
  [[ "$canonical_case" == "$case_file" ]] ||
    fail "canonicalization did not follow the filesystem's case behavior"
fi

reservation="$(run_helper "$state" reserve "$nvim_wrapper" "$root")"
IFS=$'\t' read -r reservation_type root_hash token <<<"$reservation"
[[ "$reservation_type" == "NEW" ]] || fail "the first root reservation was not new"

NVIM_LAUNCHER_TESTING=1 \
  NVIM_LAUNCHER_STATE_DIR="$state" \
  "$helper_binary" run-root "$root_hash" "$token" \
  >"$test_dir/server-output" 2>"$test_dir/server-error" &
server_pid=$!
server_pids+=("$server_pid")
socket_path="$state/sockets/$root_hash.sock"
wait_for_file "$socket_path"

[[ "$(run_helper "$state" publish "$root_hash" "$token" window-1 tab-1 terminal-1)" == "READY" ]] ||
  fail "the rooted Neovim server was not published"
record_path="$state/sessions/$root_hash.json"
[[ -f "$record_path" ]] || fail "the session record was not written"
[[ "$(stat -f %Lp "$record_path")" == 600 ]] || fail "the session record is not private"
[[ "$(stat -f %Lp "$state")" == 700 ]] || fail "the state directory is not private"
[[ "$(plutil -extract root raw -o - "$record_path")" == "$root" ]] ||
  fail "the serialized root does not match"
[[ "$(plutil -extract processID raw -o - "$record_path")" == "$server_pid" ]] ||
  fail "the serialized process ID does not identify the server"
[[ -S "$socket_path" ]] || fail "the RPC endpoint is not a Unix-domain socket"
[[ -z "$(find "$state" -name '*.tmp' -print -quit)" ]] ||
  fail "an atomic state-write temporary file was left behind"
initial_argument="$(
  "$nvim_wrapper" \
    --server "$socket_path" \
    --remote-expr "fnamemodify(argv(0), ':p')"
)"
[[ "$initial_argument" == "$root" || "$initial_argument" == "$root/" ]] ||
  fail "Neovim did not receive the canonical directory argument"

special_names=(
  "space name.txt"
  'double"quote.txt'
  "apostrophe's.txt"
  "Юникод.txt"
  'dollar$.txt'
  'semi;colon.txt'
  $'line\nbreak.txt'
  '-leading.txt'
)
special_paths=()
for name in "${special_names[@]}"; do
  path="$root/$name"
  touch "$path"
  special_paths+=("$path")
done

route_output="$(run_helper "$state" route "$nvim_wrapper" "${special_paths[@]}")"
[[ "$route_output" == $'FOCUS\twindow-1\ttab-1\tterminal-1' ]] ||
  fail "remote routing did not return the exact Ghostty identities"
tabs_json="$(
  "$nvim_wrapper" \
    --server "$socket_path" \
    --remote-expr \
    "luaeval(\"vim.json.encode(vim.tbl_map(function(tab) local win = vim.api.nvim_tabpage_get_win(tab); return vim.fn.sha256(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))) end, vim.api.nvim_list_tabpages()))\")"
)"
printf '%s' "$tabs_json" >"$test_dir/tabs.json"
for expected in "${special_paths[@]}"; do
  expected_hash="$(
    printf '%s' "$expected" |
      /usr/bin/shasum -a 256 |
      /usr/bin/awk '{ print $1 }'
  )"
  found=false
  for tab_index in $(seq 0 "${#special_paths[@]}"); do
    actual="$(plutil -extract "$tab_index" raw -o - "$test_dir/tabs.json")"
    if [[ "$actual" == "$expected_hash" ]]; then
      found=true
      break
    fi
  done
  if [[ "$found" != true ]]; then
    printf 'Missing: %q\n' "$expected" >&2
    fail "Neovim did not receive an exact special-character path"
  fi
done
last_special_index=$((${#special_paths[@]} - 1))
[[ "$(
  "$nvim_wrapper" --server "$socket_path" --remote-expr "fnamemodify(expand('%:p'), ':p')"
)" == "${special_paths[$last_special_index]}" ]] ||
  fail "the final remotely opened tab was not selected"

outside_output="$(run_helper "$state" route "$nvim_wrapper" "$prefix_root/file.txt")"
[[ "$outside_output" == $'UNMATCHED\t0' ]] ||
  fail "a file outside every root was not left unmatched"

nested_reservation="$(run_helper "$state" reserve "$nvim_wrapper" "$nested_root")"
IFS=$'\t' read -r nested_type nested_hash nested_token <<<"$nested_reservation"
[[ "$nested_type" == "NEW" ]] || fail "the nested root reservation was not new"
NVIM_LAUNCHER_TESTING=1 \
  NVIM_LAUNCHER_STATE_DIR="$state" \
  "$helper_binary" run-root "$nested_hash" "$nested_token" \
  >"$test_dir/nested-output" 2>"$test_dir/nested-error" &
nested_pid=$!
server_pids+=("$nested_pid")
nested_socket="$state/sockets/$nested_hash.sock"
wait_for_file "$nested_socket"
run_helper "$state" publish \
  "$nested_hash" "$nested_token" window-2 tab-2 terminal-2 >/dev/null

nested_file="$nested_root/most-specific.txt"
touch "$nested_file"
nested_route="$(run_helper "$state" route "$nvim_wrapper" "$nested_file")"
[[ "$nested_route" == $'FOCUS\twindow-2\ttab-2\tterminal-2' ]] ||
  fail "an active nested root did not win longest-root routing"
[[ "$(
  "$nvim_wrapper" --server "$nested_socket" --remote-expr "fnamemodify(expand('%:p'), ':p')"
)" == "$nested_file" ]] || fail "the nested server did not receive its file"

queue_state="$test_dir/queue-state"
queue_root="$fixture/queued-project"
mkdir -p "$queue_root"
queue_file="$queue_root/during-startup.txt"
touch "$queue_file"
queue_reservation="$(run_helper "$queue_state" reserve "$nvim_wrapper" "$queue_root")"
IFS=$'\t' read -r queue_type queue_hash queue_token <<<"$queue_reservation"
[[ "$queue_type" == "NEW" ]] || fail "the startup queue root was not reserved"

run_helper "$queue_state" route "$nvim_wrapper" "$queue_file" \
  >"$test_dir/queued-route" 2>"$test_dir/queued-route-error" &
route_pid=$!
for _ in {1..100}; do
  pending_path="$(
    plutil -extract pendingPaths.0 raw -o - \
      "$queue_state/reservations/$queue_hash.json" 2>/dev/null || true
  )"
  [[ "$pending_path" == "$queue_file" ]] && break
  sleep 0.05
done
[[ "${pending_path:-}" == "$queue_file" ]] ||
  fail "a file was not queued during root startup"

NVIM_LAUNCHER_TESTING=1 \
  NVIM_LAUNCHER_STATE_DIR="$queue_state" \
  "$helper_binary" run-root "$queue_hash" "$queue_token" \
  >"$test_dir/queue-server-output" 2>"$test_dir/queue-server-error" &
queue_server_pid=$!
server_pids+=("$queue_server_pid")
queue_socket="$queue_state/sockets/$queue_hash.sock"
wait_for_file "$queue_socket"
run_helper "$queue_state" publish \
  "$queue_hash" "$queue_token" queue-window queue-tab queue-terminal >/dev/null
wait "$route_pid"
[[ "$(<"$test_dir/queued-route")" == $'FOCUS\tqueue-window\tqueue-tab\tqueue-terminal' ]] ||
  fail "the startup request did not resolve to the published session"
[[ "$(
  "$nvim_wrapper" --server "$queue_socket" --remote-expr "fnamemodify(expand('%:p'), ':p')"
)" == "$queue_file" ]] || fail "the file queued during startup was lost"

once_state="$test_dir/once-state"
once_file="$fixture/one-shot file.txt"
touch "$once_file"
once_reservation="$(run_helper "$once_state" prepare-once "$nvim_wrapper" "$once_file")"
IFS=$'\t' read -r once_type once_hash once_token <<<"$once_reservation"
[[ "$once_type" == "NEW" ]] || fail "the one-shot launch was not prepared"
[[ "$(run_helper "$once_state" route "$nvim_wrapper" "$prefix_root/file.txt")" == $'UNMATCHED\t0' ]] ||
  fail "a concurrent routed open failed while a one-shot launch was starting"
[[ -f "$once_state/reservations/$once_hash.json" ]] ||
  fail "a concurrent routed open removed a valid one-shot reservation"
NVIM_LAUNCHER_TESTING=1 \
  NVIM_LAUNCHER_STATE_DIR="$once_state" \
  "$helper_binary" run-once "$once_hash" "$once_token" \
  >"$test_dir/once-output" 2>"$test_dir/once-error" &
once_server_pid=$!
server_pids+=("$once_server_pid")
once_socket="$once_state/sockets/$once_hash.sock"
wait_for_file "$once_socket"
run_helper "$once_state" publish-once \
  "$once_hash" "$once_token" once-window once-tab once-terminal >/dev/null
[[ ! -e "$once_state/reservations/$once_hash.json" ]] ||
  fail "published one-shot state was not removed"
[[ ! -e "$once_state/sessions/$once_hash.json" ]] ||
  fail "a one-shot launch became a reusable session"
[[ "$(
  "$nvim_wrapper" --server "$once_socket" --remote-expr "fnamemodify(expand('%:p'), ':p')"
)" == "$once_file" ]] || fail "the one-shot launch did not receive its exact file"

concurrent_state="$test_dir/concurrent-state"
concurrent_root="$fixture/concurrent-project"
mkdir -p "$concurrent_root"
run_helper "$concurrent_state" reserve "$nvim_wrapper" "$concurrent_root" \
  >"$test_dir/reserve-a" 2>"$test_dir/reserve-a-error" &
reserve_a_pid=$!
run_helper "$concurrent_state" reserve "$nvim_wrapper" "$concurrent_root" \
  >"$test_dir/reserve-b" 2>"$test_dir/reserve-b-error" &
reserve_b_pid=$!
wait "$reserve_a_pid"
wait "$reserve_b_pid"
new_count="$(
  awk '/^NEW/{ count += 1 } END { print count + 0 }' \
    "$test_dir/reserve-a" \
    "$test_dir/reserve-b"
)"
[[ "$new_count" == 1 ]] || fail "concurrent same-root launches created duplicate reservations"
[[ "$(find "$concurrent_state/reservations" -name '*.json' | wc -l | tr -d ' ')" == 1 ]] ||
  fail "concurrent same-root launches wrote duplicate state"

corrupt_state="$test_dir/corrupt-state"
corrupt_root="$fixture/corrupt-project"
mkdir -p "$corrupt_root"
corrupt_reservation="$(run_helper "$corrupt_state" reserve "$nvim_wrapper" "$corrupt_root")"
IFS=$'\t' read -r _ corrupt_hash corrupt_token <<<"$corrupt_reservation"
run_helper "$corrupt_state" cancel "$corrupt_hash" "$corrupt_token"
printf '%s\n' '{invalid' >"$corrupt_state/sessions/$corrupt_hash.json"
chmod 600 "$corrupt_state/sessions/$corrupt_hash.json"
[[ "$(run_helper "$corrupt_state" route "$nvim_wrapper" "$corrupt_root")" == $'UNMATCHED\t0' ]] ||
  fail "a corrupt stale session blocked a new launch"
[[ ! -e "$corrupt_state/sessions/$corrupt_hash.json" ]] ||
  fail "a corrupt stale session was not removed"
printf '%s\n' '{invalid' >"$corrupt_state/sessions/$corrupt_hash.json"
chmod 600 "$corrupt_state/sessions/$corrupt_hash.json"
replacement_reservation="$(
  run_helper "$corrupt_state" reserve "$nvim_wrapper" "$corrupt_root"
)"
IFS=$'\t' read -r replacement_type replacement_hash replacement_token \
  <<<"$replacement_reservation"
[[ "$replacement_type" == "NEW" && "$replacement_hash" == "$corrupt_hash" ]] ||
  fail "a corrupt stale session blocked a direct root launch"
run_helper "$corrupt_state" cancel "$replacement_hash" "$replacement_token"

symlink_target="$test_dir/symlink-target"
printf '%s\n' "do not modify" >"$symlink_target"
ln -s "$symlink_target" "$corrupt_state/sessions/$corrupt_hash.json"
if run_helper "$corrupt_state" route "$nvim_wrapper" "$corrupt_root" \
  >"$test_dir/symlink-output" 2>"$test_dir/symlink-error"; then
  fail "a symlinked state record was accepted"
fi
[[ "$(<"$symlink_target")" == "do not modify" ]] ||
  fail "a state-file symlink target was modified"
rm "$corrupt_state/sessions/$corrupt_hash.json"

pid_state="$test_dir/pid-state"
pid_root="$fixture/pid-project"
mkdir -p "$pid_root"
pid_reservation="$(run_helper "$pid_state" reserve "$nvim_wrapper" "$pid_root")"
IFS=$'\t' read -r _ pid_hash pid_token <<<"$pid_reservation"
NVIM_LAUNCHER_TESTING=1 \
  NVIM_LAUNCHER_STATE_DIR="$pid_state" \
  "$helper_binary" run-root "$pid_hash" "$pid_token" \
  >"$test_dir/pid-output" 2>"$test_dir/pid-error" &
pid_server_pid=$!
server_pids+=("$pid_server_pid")
pid_socket="$pid_state/sockets/$pid_hash.sock"
wait_for_file "$pid_socket"
run_helper "$pid_state" publish \
  "$pid_hash" "$pid_token" pid-window pid-tab pid-terminal >/dev/null
plutil -replace processID -integer "$((pid_server_pid + 100000))" \
  "$pid_state/sessions/$pid_hash.json"
[[ "$(run_helper "$pid_state" route "$nvim_wrapper" "$pid_root")" == $'UNMATCHED\t0' ]] ||
  fail "a reused process ID could produce a false session match"
[[ ! -e "$pid_state/sessions/$pid_hash.json" ]] ||
  fail "a process-ID-mismatched record was not removed"
[[ ! -S "$pid_socket" ]] ||
  fail "a process-ID-mismatched socket was not invalidated"
kill "$pid_server_pid"
wait "$pid_server_pid" 2>/dev/null || true
forget_server "$pid_server_pid"

identity_state="$test_dir/identity-state"
identity_root="$fixture/identity-project"
mkdir -p "$identity_root"
identity_reservation="$(run_helper "$identity_state" reserve "$nvim_wrapper" "$identity_root")"
IFS=$'\t' read -r _ identity_hash identity_token <<<"$identity_reservation"
NVIM_LAUNCHER_TESTING=1 \
  NVIM_LAUNCHER_STATE_DIR="$identity_state" \
  "$helper_binary" run-root "$identity_hash" "$identity_token" \
  >"$test_dir/identity-output" 2>"$test_dir/identity-error" &
identity_server_pid=$!
server_pids+=("$identity_server_pid")
identity_socket="$identity_state/sockets/$identity_hash.sock"
wait_for_file "$identity_socket"
run_helper "$identity_state" publish \
  "$identity_hash" "$identity_token" identity-window identity-tab identity-terminal \
  >/dev/null
plutil -replace token -string "different-server-token" \
  "$identity_state/sessions/$identity_hash.json"
[[ "$(run_helper "$identity_state" route "$nvim_wrapper" "$identity_root")" == $'UNMATCHED\t0' ]] ||
  fail "a valid socket with a different server identity was reused"
[[ ! -S "$identity_socket" ]] ||
  fail "a socket with a different server identity was not invalidated"
kill "$identity_server_pid"
wait "$identity_server_pid" 2>/dev/null || true
forget_server "$identity_server_pid"

stop_server "$nested_socket" "$nested_pid"
[[ ! -e "$state/sessions/$nested_hash.json" ]] ||
  fail "VimLeavePre did not remove the nested session record"
[[ ! -S "$nested_socket" ]] || fail "Neovim did not remove its RPC socket"

stop_server "$queue_socket" "$queue_server_pid"
[[ ! -e "$queue_state/sessions/$queue_hash.json" ]] ||
  fail "the queued session record was not removed at process exit"

stop_server "$once_socket" "$once_server_pid"
[[ ! -S "$once_socket" ]] || fail "the one-shot socket survived process exit"

stop_server "$socket_path" "$server_pid"
[[ ! -e "$record_path" ]] || fail "the session record was not removed at process exit"
[[ ! -S "$socket_path" ]] || fail "the server socket survived process exit"
[[ "$(run_helper "$state" route "$nvim_wrapper" "$root/space name.txt")" == $'UNMATCHED\t0' ]] ||
  fail "an exited root was still treated as live"

printf '%s\n' "Nvim launcher helper verification passed"
