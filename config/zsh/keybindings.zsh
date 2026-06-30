# ============================================================================
#  Key bindings
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
