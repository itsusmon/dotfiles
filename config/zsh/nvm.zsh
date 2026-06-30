# ============================================================================
#  NVM — lazy-loaded for fast shell startup (~230ms saved)
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
