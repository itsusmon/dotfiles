## STARSHIP PROMPT ##
if ! command -v starship &> /dev/null; then
  echo "Starship is not installed!"
  echo "Installing starship..."
  curl -fsSL https://starship.rs/install.sh | sh
fi

eval "$(starship init zsh)"

export STARSHIP_CONFIG="$STARSHIP_HOME/starship.toml"

source "${ZDOTDIR}/core/functions.zsh"
source "${ZDOTDIR}/core/zinit.zsh"
source "${ZDOTDIR}/core/aliases.zsh"
source "${ZDOTDIR}/core/history.zsh"

plugin "zsh-syntax-highlighting"
plugin "zsh-autosuggestions"
plugin "zsh-completions"
plugin "zoxide"
plugin "fzf"

