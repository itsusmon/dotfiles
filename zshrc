# ============================================================================
#  ZSH Configuration — Optimized for fast startup
# ============================================================================

# --- Default Editor ---
export EDITOR='nvim'
export VISUAL='nvim'

# --- GPG (commit signing): point the agent's prompt at the active terminal ---
export GPG_TTY=${TTY:-$(tty)}

# --- History ---
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS   # Remove older duplicate entries
setopt HIST_REDUCE_BLANKS     # Remove superfluous blanks
setopt HIST_FIND_NO_DUPS      # Don't show duplicates in search
setopt SHARE_HISTORY          # Share history between sessions
setopt INC_APPEND_HISTORY     # Write history immediately

# --- General Options ---
setopt AUTO_CD                # cd by just typing directory name
setopt AUTO_PUSHD             # Push directories onto stack
setopt PUSHD_IGNORE_DUPS      # Don't push duplicate dirs
setopt CORRECT                # Command correction
setopt INTERACTIVE_COMMENTS   # Allow comments in interactive shell
setopt NO_BEEP                # No beep on error
setopt IGNORE_EOF             # Prevent Ctrl+D from closing the shell
setopt CDABLE_VARS            # cd into named dirs without ~/
setopt GLOB_DOTS              # Include dotfiles in glob results
setopt NO_CASE_GLOB           # Case-insensitive globbing
setopt NO_CASE_MATCH          # Case-insensitive pattern matching

# ============================================================================
#  PATH & Environment (early, before anything that needs binaries)
# ============================================================================

# De-duplicate: only add if not already present
typeset -U path  # Ensures PATH entries are unique (zsh built-in)

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

# Configure JAVA_HOME variable (cached to avoid spawning a subprocess)
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

# ============================================================================
#  NVM — Lazy-loaded for fast shell startup (~230ms saved)
# ============================================================================

export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  # Add NVM's default node to PATH immediately (no-cost, instant)
  # Resolves the version alias to actual installed directory
  _nvm_default_alias="$NVM_DIR/alias/default"
  if [[ -r $_nvm_default_alias ]]; then
    _nvm_alias_val=$(<$_nvm_default_alias)
    # The alias might be "24" but the dir is "v24.18.0" — use glob to resolve
    _nvm_resolved_dir=($NVM_DIR/versions/node/v${_nvm_alias_val}*(N[1]))
    if [[ -n $_nvm_resolved_dir && -d "$_nvm_resolved_dir/bin" ]]; then
      path=("$_nvm_resolved_dir/bin" $path)
    fi
    unset _nvm_alias_val _nvm_resolved_dir
  fi
  unset _nvm_default_alias

  # Lazy-load wrapper: full NVM loads on first call to nvm command
  nvm() {
    unfunction nvm 2>/dev/null
    source "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
    nvm "$@"
  }
fi

# ============================================================================
#  Completion System
# ============================================================================

# Add zsh-completions to fpath (before compinit)
if [[ -d ~/.zsh/zsh-completions/src ]]; then
  fpath=(~/.zsh/zsh-completions/src $fpath)
fi

# Initialize completion system
# Only regenerate compdump once per day (check by file age)
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
  'l:|=* r:|=*'                                              # Case-insensitive + partial-word + substring
zstyle ':completion:*' menu select                          # Arrow-key menu
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"     # Colored completions
zstyle ':completion:*' group-name ''                        # Group by category
zstyle ':completion:*:descriptions' format '%F{cyan}── %d ──%f'
zstyle ':completion:*:warnings' format '%F{red}No matches found%f'
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# ============================================================================
#  Prompt (PS1)
# ============================================================================

# Enable prompt substitution
setopt PROMPT_SUBST

# Git info for prompt
autoload -Uz vcs_info
precmd_functions+=(vcs_info)
zstyle ':vcs_info:*' enable git
# check-for-changes=false avoids running `git status` on every prompt (~5-20ms)
# The branch name still shows; you just won't see ● for staged/unstaged files
zstyle ':vcs_info:*' check-for-changes false
zstyle ':vcs_info:git:*' formats ' %F{magenta} %b%f'
zstyle ':vcs_info:git:*' actionformats ' %F{magenta} %b%f|%F{red}%a%f'

# Single-line prompt: dir + git branch + prompt char
PROMPT='%F{blue}%~%f${vcs_info_msg_0_} %(?.%F{green}.%F{red})❯%f '

# Right prompt: execution time + timestamp
RPROMPT='%F{242}%*%f'

# ============================================================================
#  zmx Integration
# ============================================================================

# Show zmx session in prompt when inside one
if [[ -n $ZMX_SESSION ]]; then
  PROMPT='%F{yellow}[zmx:%F{white}${ZMX_SESSION}%F{yellow}]%f '"$PROMPT"

  # Ctrl+D → detach immediately (session keeps running)
  _zmx_detach() {
    zle -I
    echo ""
    zmx detach
  }
  zle -N _zmx_detach
  bindkey '^D' _zmx_detach

  # Ctrl+C → interrupt line if text present, confirmation if empty
  _zmx_confirm_exit() {
    if [[ -n $BUFFER ]]; then
      zle send-break
      return
    fi
    zle -I
    print -Pn "\n%F{yellow}zmx:%f End session '$ZMX_SESSION'? [d]etach / [e]xit / [c]ancel: "
    read -k1 _zmx_choice
    echo ""
    case $_zmx_choice in
      d|D) zmx detach ;;
      e|E) builtin exit ;;
      *)   echo "Cancelled." ;;
    esac
    unset _zmx_choice
    zle reset-prompt
  }
  zle -N _zmx_confirm_exit
  bindkey '^C' _zmx_confirm_exit

  # `exit` command → same confirmation
  exit() {
    echo ""
    print -Pn "%F{yellow}zmx:%f End session '$ZMX_SESSION'? [d]etach / [e]xit / [c]ancel: "
    read -k1 _zmx_choice
    echo ""
    case $_zmx_choice in
      d|D) zmx detach ;;
      e|E) builtin exit "$@" ;;
      *)   echo "Cancelled." ;;
    esac
    unset _zmx_choice
  }
fi

# zmx completions — deferred to first use
_zmx_load_completions() {
  if command -v zmx &> /dev/null; then
    eval "$(zmx completions zsh)"
  fi
  # Remove this hook after first completion
  compdef -d zmx 2>/dev/null
}
compdef _zmx_load_completions zmx

# zmx convenience aliases
alias za='zmx attach'
alias zr='zmx run'
alias zl='zmx list'
alias zk='zmx kill'
alias zh='zmx history'
alias zs='zmx send'
alias zt='zmx tail'
alias zw='zmx wait'

# ============================================================================
#  Key Bindings
# ============================================================================

# Use emacs keybindings (more intuitive for most users)
bindkey -e

# --- Option+Arrow → word-by-word navigation ---
bindkey '^[f'      forward-word          # Option+Right (ESC-f)
bindkey '^[b'      backward-word         # Option+Left  (ESC-b)
bindkey '^[[1;3C'  forward-word          # Option+Right (xterm/iTerm2)
bindkey '^[[1;3D'  backward-word         # Option+Left  (xterm/iTerm2)
bindkey '^[[1;5C'  forward-word          # Ctrl+Right   (fallback)
bindkey '^[[1;5D'  backward-word         # Ctrl+Left    (fallback)

# --- Cmd+Arrow → beginning/end of line ---
bindkey '^[[1;9D'  beginning-of-line     # Cmd+Left  (iTerm2)
bindkey '^[[1;9C'  end-of-line           # Cmd+Right (iTerm2)
bindkey '^[OH'     beginning-of-line     # Cmd+Left  (Terminal.app / Home)
bindkey '^[OF'     end-of-line           # Cmd+Right (Terminal.app / End)
bindkey '^[[H'     beginning-of-line     # Home key
bindkey '^[[F'     end-of-line           # End key
bindkey '^A'       beginning-of-line     # Ctrl+A fallback
bindkey '^E'       end-of-line           # Ctrl+E fallback

# --- Other navigation ---
bindkey '^[[3~'    delete-char           # Delete key
bindkey '^[d'      kill-word             # Option+Delete → delete word forward
bindkey '^[^?'     backward-kill-word    # Option+Backspace → delete word backward

# --- Text Selection (Shift+Arrow) ---
# Pattern: activate region on first call, then just move cursor
_select-forward-char()        { ((REGION_ACTIVE)) || zle set-mark-command; zle forward-char }
_select-backward-char()       { ((REGION_ACTIVE)) || zle set-mark-command; zle backward-char }
_select-up-line()             { ((REGION_ACTIVE)) || zle set-mark-command; zle up-line-or-history }
_select-down-line()           { ((REGION_ACTIVE)) || zle set-mark-command; zle down-line-or-history }
_select-forward-word()        { ((REGION_ACTIVE)) || zle set-mark-command; zle forward-word }
_select-backward-word()       { ((REGION_ACTIVE)) || zle set-mark-command; zle backward-word }
_select-end-of-line()         { ((REGION_ACTIVE)) || zle set-mark-command; zle end-of-line }
_select-beginning-of-line()   { ((REGION_ACTIVE)) || zle set-mark-command; zle beginning-of-line }
zle -N _select-forward-char
zle -N _select-backward-char
zle -N _select-up-line
zle -N _select-down-line
zle -N _select-forward-word
zle -N _select-backward-word
zle -N _select-end-of-line
zle -N _select-beginning-of-line

bindkey '^[[1;2C'  _select-forward-char         # Shift+Right
bindkey '^[[1;2D'  _select-backward-char        # Shift+Left
bindkey '^[[1;2A'  _select-up-line              # Shift+Up
bindkey '^[[1;2B'  _select-down-line            # Shift+Down
bindkey '^[[1;4C'  _select-forward-word         # Shift+Option+Right
bindkey '^[[1;4D'  _select-backward-word        # Shift+Option+Left
bindkey '^[[1;10C' _select-end-of-line          # Shift+Cmd+Right
bindkey '^[[1;10D' _select-beginning-of-line    # Shift+Cmd+Left

# --- Prefix history search (type something, then Up/Down) ---
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A'     up-line-or-beginning-search    # Up arrow
bindkey '^[[B'     down-line-or-beginning-search  # Down arrow
bindkey '^R'       history-incremental-search-backward  # Ctrl+R

# Edit command in $EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E'     edit-command-line      # Ctrl+X Ctrl+E → open in editor

# ============================================================================
#  Aliases & Utilities
# ============================================================================

# ls with colors
alias ls='ls -G'
alias ll='ls -lah'
alias la='ls -A'

# Safety nets
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Grep with color
alias grep='grep --color=auto'

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

# ============================================================================
#  Background compilation (runs after prompt is displayed — zero cost)
# ============================================================================
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

# fzf
source <(fzf --zsh)

# ── fzf + bat integration ─────────────────────────────────────────────
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
