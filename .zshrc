export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git history-substring-search kamal mise)
source "$ZSH/oh-my-zsh.sh"

# Oh My Zsh sets LESS=-R, which stops git adding -F: short output then opens a pager
export LESS=-FR

# The virtual display noVNC shows, where agent-browser opens Brave Origin headed
export DISPLAY=:1

source ~/.config/shell/aliases

# Syntax highlighting has to come last, it wraps every widget defined before it
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
