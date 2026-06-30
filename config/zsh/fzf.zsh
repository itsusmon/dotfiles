# ============================================================================
#  fzf + bat integration
# ============================================================================

# Load fzf's keybindings and completion
source <(fzf --zsh)

# Default fzf options: preview with fzf-preview script
export FZF_DEFAULT_OPTS="
  --preview 'fzf-preview {}'
  --preview-window 'right:50%:border-left:wrap'
  --bind 'ctrl-/:toggle-preview'
  --bind 'ctrl-u:preview-half-page-up'
  --bind 'ctrl-d:preview-half-page-down'
  --color=bg+:-1,bg:-1,spinner:#f4dbd6,hl:#ed8796
  --color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6
  --color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796
  --color=border:#6e738d,label:#cad3f5,preview-bg:-1
  --border=rounded
  --margin=1
  --padding=1
"

# Ctrl+T: paste file path (with preview)
export FZF_CTRL_T_OPTS="
  --preview 'fzf-preview {}'
  --preview-window 'right:60%:border-left:wrap'
  --header '📂 Select file'
"

# Alt+C: cd into directory (with tree preview)
export FZF_ALT_C_OPTS="
  --preview 'CLICOLOR_FORCE=1 ls -lAhpG {} 2>/dev/null || ls -lAhp {}'
  --preview-window 'right:50%:border-left'
  --header '📁 Select directory'
"

# Ctrl+R: search command history (with command preview)
export FZF_CTRL_R_OPTS="
  --preview 'echo {}'
  --preview-window 'up:3:wrap:border-bottom'
  --header '🕐 Command history'
"

# Use bat as manpager with fzf integration
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# Aliases: fzf-powered shortcuts
alias fze='fzf --preview "fzf-preview {}" --preview-window "right:60%:wrap" --bind "enter:become(fzf-open {})"'
