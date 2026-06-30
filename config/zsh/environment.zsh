# ============================================================================
#  Environment — editor, PATH, and exported variables
#  (loaded early, before anything that needs binaries on PATH)
# ============================================================================

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

# --- GPG (commit signing): point the agent's prompt at the active terminal ---
export GPG_TTY=${TTY:-$(tty)}

# --- PATH ---
typeset -U path  # keep PATH entries unique (zsh built-in)

export ANDROID_HOME=/Users/Shared/Library/Android/SDK

path=(
  "$HOME/.local/bin"
  "$HOME/.fzf/bin"
  "/Users/usmon/.lmstudio/bin"
  "/Users/usmon/.opencode/bin"
  "$ANDROID_HOME/tools"
  "$ANDROID_HOME/tools/bin"
  "$ANDROID_HOME/platform-tools"
  "/Users/usmon/Library/Application Support/JetBrains/Toolbox/scripts"
  $path
)

# --- JAVA_HOME (cached to avoid spawning /usr/libexec/java_home each shell) ---
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
