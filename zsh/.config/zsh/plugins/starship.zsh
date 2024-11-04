if ! command -v starship &> /dev/null; then
  echo "Starship is not installed!"
  echo "Installing starship..."
  curl -fsSL https://starship.rs/install.sh | sh
fi

eval "$(starship init zsh)"

export STARSHIP_CONFIG="$STARSHIP_HOME/starship.toml"
