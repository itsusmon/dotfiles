#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

[[ "$(uname -s)" == "Darwin" ]] || {
  printf '%s\n' "Nvim.app verification skipped: macOS is required"
  exit 0
}

repo_copy="$test_dir/repository with spaces"
test_home="$test_dir/home with spaces"
mkdir -p "$repo_copy/config/nvim/launcher" "$repo_copy/scripts/bin" "$test_home"
cp "$repo_dir/install.sh" "$repo_dir/dotfiles.conf" "$repo_copy/"
cp "$repo_dir/scripts/bin/"* "$repo_copy/scripts/bin/"
cp -R "$repo_dir/config/nvim/launcher/." "$repo_copy/config/nvim/launcher/"

non_macos_home="$test_dir/non-macOS home"
fake_bin="$test_dir/non-macOS bin"
mkdir -p "$non_macos_home" "$fake_bin"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" Linux' >"$fake_bin/uname"
chmod +x "$fake_bin/uname"
PATH="$fake_bin:/usr/bin:/bin" HOME="$non_macos_home" "$repo_copy/install.sh" \
  >"$test_dir/non-macOS-output"
grep -Fq "Nvim.app requires macOS" "$test_dir/non-macOS-output" ||
  fail "the main installer did not skip Nvim.app on a non-macOS system"
[[ ! -e "$non_macos_home/Applications/Nvim.app" ]] ||
  fail "the non-macOS installer created Nvim.app"

first_output="$test_dir/first-output"
HOME="$test_home" "$repo_copy/install.sh" >"$first_output"
installed_app="$test_home/Applications/Nvim.app"
[[ -d "$installed_app" ]] || fail "the main installer did not create Nvim.app"
[[ -x "$installed_app/Contents/Resources/nvim-launcher-helper" ]] ||
  fail "the installed application is missing its launcher helper"
HOME="$test_home" "$test_home/.local/bin/nvim-app" verify >/dev/null ||
  fail "the first installed application did not validate"
document_types="$test_dir/document-types.json"
plutil -extract CFBundleDocumentTypes json -o "$document_types" \
  "$installed_app/Contents/Info.plist"
grep -Fq '"public.folder"' "$document_types" ||
  fail "the installed application does not advertise Finder folder handling"
helper_architecture="$(file -b "$installed_app/Contents/Resources/nvim-launcher-helper")"
case "$(uname -m)" in
  arm64) [[ "$helper_architecture" == *"arm64"* ]] ;;
  x86_64) [[ "$helper_architecture" == *"x86_64"* ]] ;;
  *) fail "the test is running on an unsupported Mac architecture" ;;
esac || fail "the launcher helper was not compiled for the current Mac architecture"
strings "$installed_app/Contents/Resources/nvim-launcher-helper" \
  >"$test_dir/helper-strings"
if grep -Fq "NSAppleScript" "$test_dir/helper-strings"; then
  fail "the helper still sends Automation Apple events outside Nvim.app"
fi
macos_major="$(sw_vers -productVersion)"
macos_major="${macos_major%%.*}"
if ((macos_major >= 26)) && /usr/bin/xcrun --find actool >/dev/null 2>&1; then
  [[ -f "$installed_app/Contents/Resources/Assets.car" ]] ||
    fail "the installed application is missing adaptive icon resources"
  /usr/bin/assetutil --info "$installed_app/Contents/Resources/Assets.car" \
    >"$test_dir/icon-assets.json"
  grep -Fq '"Appearance" : "NSAppearanceNameDarkAqua"' "$test_dir/icon-assets.json" ||
    fail "the installed application is missing its dark icon appearance"
  grep -Fq 'Nvim-dark' "$test_dir/icon-assets.json" ||
    fail "the adaptive icon does not contain the dark Neovim artwork"
  grep -Fq 'Nvim-light' "$test_dir/icon-assets.json" ||
    fail "the adaptive icon does not contain the light Neovim artwork"
fi

first_hash="$(
  /usr/libexec/PlistBuddy -c "Print :NvimLauncherSourceHash" \
    "$installed_app/Contents/Info.plist"
)"
first_script_hash="$(shasum -a 256 "$installed_app/Contents/Resources/Scripts/main.scpt")"

second_output="$test_dir/second-output"
HOME="$test_home" "$repo_copy/install.sh" >"$second_output"
grep -Fq "$installed_app is current" "$second_output" ||
  fail "the second installer run did not report the application as current"
second_script_hash="$(shasum -a 256 "$installed_app/Contents/Resources/Scripts/main.scpt")"
[[ "$second_script_hash" == "$first_script_hash" ]] ||
  fail "the second installer run rebuilt an unchanged application"

rm "$installed_app/Contents/Resources/Scripts/main.scpt"
rm "$installed_app/Contents/Resources/nvim-launcher-helper"
HOME="$test_home" "$repo_copy/install.sh" >/dev/null
[[ -f "$installed_app/Contents/Resources/Scripts/main.scpt" ]] ||
  fail "the installer did not repair an incomplete application"
[[ -x "$installed_app/Contents/Resources/nvim-launcher-helper" ]] ||
  fail "the installer did not repair a missing launcher helper"
HOME="$test_home" "$repo_copy/scripts/bin/nvim-app" verify >/dev/null ||
  fail "the repaired application did not validate"

printf '\n-- Source update verification.\n' >>"$repo_copy/config/nvim/launcher/NvimLauncher.applescript"
HOME="$test_home" "$repo_copy/install.sh" >/dev/null
updated_hash="$(
  /usr/libexec/PlistBuddy -c "Print :NvimLauncherSourceHash" \
    "$installed_app/Contents/Info.plist"
)"
[[ "$updated_hash" != "$first_hash" ]] ||
  fail "a launcher source change did not update the installed application"

working_app_hash="$(
  find "$installed_app" -type f -exec shasum -a 256 {} + |
    sort |
    shasum -a 256
)"
printf '\nthis is not valid AppleScript ???\n' \
  >>"$repo_copy/config/nvim/launcher/NvimLauncher.applescript"
if HOME="$test_home" "$repo_copy/install.sh" \
  >"$test_dir/failure-output" 2>"$test_dir/failure-error"; then
  fail "a controlled AppleScript build failure reported success"
fi
preserved_app_hash="$(
  find "$installed_app" -type f -exec shasum -a 256 {} + |
    sort |
    shasum -a 256
)"
[[ "$preserved_app_hash" == "$working_app_hash" ]] ||
  fail "a failed build changed the existing working application"
plutil -lint "$installed_app/Contents/Info.plist" >/dev/null ||
  fail "the working application's Info.plist was invalid after a failed replacement"
codesign --verify --deep --strict "$installed_app" ||
  fail "the working application's signature was invalid after a failed replacement"

HOME="$test_home" "$repo_copy/scripts/bin/nvim-app" uninstall >/dev/null
[[ ! -e "$installed_app" ]] || fail "uninstall did not remove Nvim.app"
HOME="$test_home" "$repo_copy/scripts/bin/nvim-app" uninstall >/dev/null ||
  fail "uninstall was not safe when Nvim.app was already absent"

mkdir -p "$installed_app/Contents"
cp "$repo_copy/config/nvim/launcher/Info.plist" "$installed_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.example.unrelated" \
  "$installed_app/Contents/Info.plist"
printf '%s\n' "keep me" >"$installed_app/unrelated-marker"
if HOME="$test_home" "$repo_copy/scripts/bin/nvim-app" install \
  >"$test_dir/unrelated-output" 2>"$test_dir/unrelated-error"; then
  fail "installation replaced an unrelated Nvim.app"
fi
[[ "$(<"$installed_app/unrelated-marker")" == "keep me" ]] ||
  fail "installation changed an unrelated Nvim.app"

printf '%s\n' "Nvim.app verification passed"
