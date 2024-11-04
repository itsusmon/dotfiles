# Download Zinit, if it's not there yet
if [ ! -d $ZINIT_HOME ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git $ZINIT_HOME
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

