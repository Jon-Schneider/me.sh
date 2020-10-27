# Path to oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="robbyrussell"

# Set PATH
export PATH=$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:$HOME/.rvm/bin

ENABLE_CORRECTION="true"

plugins=(
  git
  last-working-dir
  xcode
)

source $ZSH/oh-my-zsh.sh
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh # Load Syntax Highlighting Plugin
unsetopt nomatch

export EDITOR="vim"

# My Aliases
alias bb="open -b com.barebones.bbedit"
alias dl="cd ~/Downloads"
alias gcr="git checkout --track origin/" # Git checkout Remote Branch - add branch name after
alias grh="git reset --hard"
alias fdr="open ."
alias hm="cd ~/"
alias me="mer && vsc"
alias mer="cd ~/src/me.sh"
alias nc="cd ~/Nextcloud"
alias odm="cd ~/OneDrive\ -\ Microsoft"
alias odp="cd ~/OneDrive"
alias pi="pod install"
alias piru="pod install --repo-update"
alias pls="sudo"
alias src="cd ~/src"
alias tmp="cd ~/Tmp"
alias vsc="code ."
alias xck="osascript -e 'quit app \"Xcode\"'"
alias zshrc="bb ~/.zshrc"

# OLM Aliases
alias 'omc'='olm config'
alias 'omco'="omc DEV && omo"
alias 'omd'="olm doctor"
alias 'omda'="olm doctor --repair-type=auto"
alias 'oml'="xck && git pull && omco" # Get OLM Latest
alias 'omo'="olm open"
alias 'omr'="cd ~/src/client-cocoa" # "OLM Repo"