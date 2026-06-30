# ============================================================================
#  Prompt
# ============================================================================

# Enable prompt substitution
setopt PROMPT_SUBST

# Git info for prompt
autoload -Uz vcs_info
precmd_functions+=(vcs_info)
zstyle ':vcs_info:*' enable git
# check-for-changes shows ● for staged/unstaged files (costs a `git status`
# per prompt, ~5-20ms). Set to false to drop the cost and keep just the branch.
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:git:*' formats ' %F{magenta} %b%f'
zstyle ':vcs_info:git:*' actionformats ' %F{magenta} %b%f|%F{red}%a%f'

# Single-line prompt: dir + git branch + prompt char
PROMPT='%F{blue}%~%f${vcs_info_msg_0_} %(?.%F{green}.%F{red})❯%f '
