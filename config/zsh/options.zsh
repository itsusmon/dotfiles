# ============================================================================
#  Options — history and general shell behavior
# ============================================================================

# --- History ---
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS   # Remove older duplicate entries
setopt HIST_REDUCE_BLANKS     # Remove superfluous blanks
setopt HIST_FIND_NO_DUPS      # Don't show duplicates in search
setopt SHARE_HISTORY          # Share history between sessions
setopt INC_APPEND_HISTORY     # Write history immediately

# --- General ---
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
