# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# Hand the terminal over to zsh, unless ~/.local/state/keep-bash exists
if [[ ! -e ~/.local/state/keep-bash ]] && command -v zsh &>/dev/null; then
  if [[ $(ps --no-header --pid=$PPID --format=comm) != zsh && -z $BASH_EXECUTION_STRING && $SHLVL == 1 ]]; then
    if shopt -q login_shell; then exec zsh --login; else exec zsh; fi
  fi
fi

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"
