# ============================================================================
#  zmx integration
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
