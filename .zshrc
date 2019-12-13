# Path to oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="robbyrussell"

# Set PATH
export PATH=$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:$HOME/.rvm/bin

ENABLE_CORRECTION="true"

plugins=(
  bbedit
  brew
  dirhistory
  # docker
  # gem
  git
  git-prompt
  # golang
  # kubectl
  last-working-dir
  # minikube
  osx
  # python
  # rails
  # ruby
)

export GOPATH="$HOME/go"
source $HOME/.rvm/scripts/rvm
source $ZSH/oh-my-zsh.sh
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh # Load Syntax Highlighting Plugin installed via brew
unsetopt nomatch

# My Aliases
alias dl="cd ~/Downloads";
alias nc="cd ~/Nextcloud";
alias src="cd ~/src";
alias tmp="cd ~/Tmp";
alias vsc="code .";
