# ============================================================================
#  PATH & interactive terminal setup
#  (sourced from ~/.zshrc, AFTER macOS path_helper, so our PATH ordering wins)
#
#  Plain environment variables (XDG, EDITOR, JAVA_HOME, ANDROID_HOME, ...) live
#  in ~/.zshenv so they're available to scripts and non-interactive shells too.
# ============================================================================

# --- GPG (commit signing): point the agent's prompt at the active terminal ---
export GPG_TTY=${TTY:-$(tty)}

# --- Homebrew ---
# Sets HOMEBREW_PREFIX/CELLAR/REPOSITORY and prepends /opt/homebrew/{bin,sbin}
# to PATH. Kept here (not in ~/.zprofile as brew suggests) so it runs AFTER
# macOS path_helper and our explicit ordering below still wins.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- PATH ---
typeset -U path  # keep PATH entries unique (zsh built-in)

path=(
  "$HOME/.local/bin"
  "$HOME/.fzf/bin"
  "$HOME/.lmstudio/bin"
  "$HOME/.opencode/bin"
  "$ANDROID_HOME/tools"
  "$ANDROID_HOME/tools/bin"
  "$ANDROID_HOME/platform-tools"
  "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
  "$HOME/Library/Python/3.9/bin"
  $path
)
