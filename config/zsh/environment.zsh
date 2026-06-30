# ============================================================================
#  PATH & interactive terminal setup
#  (sourced from ~/.zshrc, AFTER macOS path_helper, so our PATH ordering wins)
#
#  Plain environment variables (XDG, EDITOR, JAVA_HOME, ANDROID_HOME, ...) live
#  in ~/.zshenv so they're available to scripts and non-interactive shells too.
# ============================================================================

# --- GPG (commit signing): point the agent's prompt at the active terminal ---
export GPG_TTY=${TTY:-$(tty)}

# --- PATH ---
typeset -U path  # keep PATH entries unique (zsh built-in)

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
