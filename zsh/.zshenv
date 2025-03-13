XDG_CONFIG_HOME="${HOME}/.config"
XDG_DATA_HOME="${HOME}/.local/share"
XDG_STATE_HOME="${HOME}/.local/state"
XDG_CACHE_HOME="${HOME}/.cache"

ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
ZINIT_HOME="${XDG_DATA_HOME}/zinit/zinit"
STARSHIP_HOME="${XDG_CONFIG_HOME}/starship"

JAVA_HOME="${XDG_DATA_HOME}/JetBrains/Toolbox/apps/android-studio/jbr"

ANDROID_USER_HOME="${HOME}/.android"
ANDROID_HOME="${ANDROID_USER_HOME}/sdk"
ANDROID_AVD_HOME="${ANDROID_USER_HOME}/avd"

PATH="${PATH}:${XDG_DATA_HOME}/bin:${ANDROID_HOME}/emulator:$HOME/.maestro/bin"
