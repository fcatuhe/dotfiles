export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
# Syntax highlighting has to come last, it wraps every widget defined before it
plugins=(git history-substring-search kamal macos mise vscode zsh-autosuggestions zsh-syntax-highlighting)
source "$ZSH/oh-my-zsh.sh"

# Oh My Zsh sets LESS=-R, which stops git adding -F: short output then opens a pager
export LESS=-FR

# Claude Code's native install lives here
export PATH="$HOME/.local/bin:$PATH"

source ~/.config/shell/aliases

export LANG=en_US.UTF-8
export HOMEBREW_NO_ANALYTICS=1
export EDITOR="codium --wait"
export BUNDLER_EDITOR="$EDITOR"
export CONSOLE_USER="François Catuhe"

# Ridecell
export AWS_PROFILE=ridecell
export AWS_REGION=us-west-2
