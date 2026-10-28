export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git history-substring-search kamal mise)
source "$ZSH/oh-my-zsh.sh"

# Oh My Zsh sets LESS=-R, which stops git adding -F: short output then opens a pager
export LESS=-FR

source ~/.config/shell/aliases

# Ctrl+U deletes to the start of the line like in pi and bash, where zsh deletes the whole line
bindkey '^U' backward-kill-line

# Syntax highlighting has to come last, it wraps every widget defined before it
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
