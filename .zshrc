export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git history-substring-search kamal mise vscode)
source "$ZSH/oh-my-zsh.sh"

# Arch ships emcc in /usr/lib/emscripten, off PATH: skyBlip's WASM build needs it
typeset -U path
path+=(/usr/lib/emscripten)

source ~/.config/shell/aliases

# Syntax highlighting has to come last, it wraps every widget defined before it
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
