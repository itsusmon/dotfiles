# ============================================================================
#  Completion system
# ============================================================================

# Add zsh-completions to fpath (before compinit)
if [[ -d ~/.zsh/zsh-completions/src ]]; then
  fpath=(~/.zsh/zsh-completions/src $fpath)
fi

# Initialize completion system.
# Only regenerate compdump once per day (check by file age).
autoload -Uz compinit
if [[ -f ~/.zcompdump && $(date +'%j') == $(stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null) ]]; then
  compinit -C  # Same day — skip security check entirely
else
  compinit     # New day — full rebuild
fi

# Completion styling
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' \
  'r:|[._-]=* r:|=*' \
  'l:|=* r:|=*'                                             # Case-insensitive + partial-word + substring
zstyle ':completion:*' menu select                          # Arrow-key menu
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"     # Colored completions
zstyle ':completion:*' group-name ''                        # Group by category
zstyle ':completion:*:descriptions' format '%F{cyan}── %d ──%f'
zstyle ':completion:*:warnings' format '%F{red}No matches found%f'
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache
