# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"

# Type a directory name to cd into it
shopt -s autocd

source ~/.config/shell/aliases

# First word green when bash can run it, red when it cannot
enable -f ~/.local/lib/bash/hl.so hl 2>/dev/null && hl on
