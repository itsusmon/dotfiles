# ============================================================================
#  ZSH Configuration — modular loader (optimized for fast startup)
# ============================================================================
#
# The actual configuration lives in ~/.config/zsh/*.zsh and is sourced in the
# order below. Edit those files; this loader just wires them together.
# Order matters: PATH first, compinit before plugins, syntax highlighting last.

ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

for _zsh_module in \
  environment \
  options \
  nvm \
  completion \
  prompt \
  zmx \
  keybindings \
  aliases \
  plugins \
  fzf
do
  [[ -r "$ZSH_CONFIG_DIR/$_zsh_module.zsh" ]] && source "$ZSH_CONFIG_DIR/$_zsh_module.zsh"
done
unset _zsh_module
