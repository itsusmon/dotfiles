# ============================================================================
#  Plugins (must be sourced AFTER compinit and key bindings)
# ============================================================================

# Autosuggestions (fish-like suggestions as you type)
if [[ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  bindkey '^[[Z' autosuggest-accept      # Shift+Tab → accept suggestion
  bindkey '^ '   autosuggest-accept      # Ctrl+Space → accept suggestion
fi

# Syntax highlighting (MUST be sourced last)
if [[ -f ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# --- Background compilation (runs after prompt is displayed — zero cost) ---
{
  # Compile zcompdump
  if [[ -s ~/.zcompdump && (! -s ~/.zcompdump.zwc || ~/.zcompdump -nt ~/.zcompdump.zwc) ]]; then
    zcompile ~/.zcompdump
  fi
  # Compile plugins if not already compiled
  local f
  for f in \
    ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh \
    ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    if [[ -f $f && (! -f ${f}.zwc || $f -nt ${f}.zwc) ]]; then
      zcompile "$f"
    fi
  done
} &!
