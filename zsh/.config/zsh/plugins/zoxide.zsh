if ! command -v zoxide &> /dev/null; then
  echo "Zoxide is not installed!"
  echo "Installing zoxide..."
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
fi

eval "$(zoxide init zsh)"
