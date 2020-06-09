ZSH=$HOME/.oh-my-zsh
ZSH_THEME="robbyrussell"
plugins=(git gitfast last-working-dir common-aliases vscode zsh-syntax-highlighting history-substring-search osx heroku)

export HOMEBREW_NO_ANALYTICS=1

source "${ZSH}/oh-my-zsh.sh"
unalias rm

type -a rbenv > /dev/null && eval "$(rbenv init -)"

type -a pyenv > /dev/null && eval "$(pyenv init -)" && eval "$(pyenv virtualenv-init -)"

[[ -f "$HOME/.aliases" ]] && source "$HOME/.aliases"

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

export EDITOR="code --wait"

export AWS_PROFILE=emea
