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

# --- XDG Base Directories ---
# macOS doesn't set these; export them explicitly so tools that honor XDG put
# their files under these dirs instead of cluttering $HOME.
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# --- Default editor ---
export EDITOR='nvim'
export VISUAL='nvim'

# --- Toolchains ---
export ANDROID_HOME=/Users/Shared/Library/Android/SDK

# JAVA_HOME (cached to avoid spawning /usr/libexec/java_home each shell)
_java_home_cache="$HOME/.zsh/cache/.java_home_cache"
if [[ -s $_java_home_cache ]]; then
  export JAVA_HOME=$(<$_java_home_cache)
else
  export JAVA_HOME=$(/usr/libexec/java_home -v 21)
  mkdir -p "$HOME/.zsh/cache"
  echo "$JAVA_HOME" > $_java_home_cache
fi
unset _java_home_cache

# Disable Claude's built-in servers
export ENABLE_CLAUDEAI_MCP_SERVERS=false
