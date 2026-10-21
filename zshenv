# ============================================================================
#  ~/.zshenv — sourced for EVERY zsh (login, interactive, and scripts)
# ============================================================================
#
# Environment variables that should exist in all shells and scripts live here.
# Interactive-only setup (prompt, aliases, keybindings, plugins) stays in
# ~/.zshrc and its ~/.config/zsh/ modules.
#
# NOTE: PATH is intentionally NOT set here. On macOS /etc/zprofile runs
# `path_helper` AFTER ~/.zshenv, which would reorder PATH and undo our
# careful ordering — so PATH is built in ~/.config/zsh/environment.zsh
# (sourced from ~/.zshrc, after path_helper runs).

# --- XDG Directories ---
# macOS doesn't set these; export them explicitly so tools that honor XDG put
# their files under these dirs instead of cluttering $HOME.
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DESKTOP_DIR="$HOME/Desktop"
export XDG_DOCUMENTS_DIR="$HOME/Documents"
export XDG_DOWNLOAD_DIR="$HOME/Downloads"
export XDG_MUSIC_DIR="$HOME/Music"
export XDG_PICTURES_DIR="$HOME/Pictures"
export XDG_PROJECTS_DIR="$HOME/Projects"
export XDG_PUBLICSHARE_DIR="$HOME/Public"
export XDG_TEMPLATES_DIR="$HOME/Templates"
export XDG_VIDEOS_DIR="$HOME/Videos"

# --- Default editor ---
export EDITOR='nvim'
export VISUAL='nvim'

# --- Toolchains ---
export ANDROID_HOME=/Users/Shared/Library/Android/SDK

# Keep the default on Java 21, using Homebrew's stable path when available.
# An explicitly selected project/runtime JAVA_HOME takes precedence.
if [[ -z ${JAVA_HOME:-} ]]; then
  for _java_prefix in /opt/homebrew /usr/local; do
    _java_candidate="$_java_prefix/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
    if [[ -x $_java_candidate/bin/java ]]; then
      export JAVA_HOME=$_java_candidate
      break
    fi
  done
  if [[ -z ${JAVA_HOME:-} ]]; then
    export JAVA_HOME=$(/usr/libexec/java_home -v 21 2>/dev/null)
  fi
  unset _java_prefix _java_candidate
fi

# Disable Homebrew hints
export HOMEBREW_NO_ENV_HINTS=1
. "$HOME/.cargo/env"
