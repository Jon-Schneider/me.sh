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
alias bi="brew install"
alias bl="brew list"
alias blc="brew list --cask"
alias bs="brew search"
alias bsc="brew search --cask"
alias bun="brew uninstall"
alias bup="brew upgrade"
alias cdf='cd "`osascript -e "tell application \\"Finder\\" to get POSIX path of (insertion location as text)"`"' # cd to front finder dir
alias cht="cht.sh"
alias dl="cd ~/Downloads"
alias ddnuke="rm -rf ~/Library/Developer/Xcode/DerivedData" # Nuke derived data
alias gcr="git checkout --track origin/" # Git checkout Remote Branch - add branch name after
alias gai="g ai"
alias gdi="g di"
alias gdl="gd @~ @" # Git diff last; show diff of last commit
alias gr="git reset"
alias grh="git reset --hard"
alias grs="git reset --soft"
alias gs="git status"
alias fdr="open ."
alias hm="cd ~/"
alias hst="history"
alias me="mer && vsc"
alias mer="cd ~/src/js/me.sh"
alias nc="cd ~/Nextcloud"
alias odm="cd ~/OneDrive\ -\ Microsoft"
alias odp="cd ~/OneDrive"
alias pi="pod install"
alias piru="pod install --repo-update"
alias pls="sudo"
alias sac="pushd ~/src/js/me.sh && ./sync_app_config.sh && popd"
alias sacl="pushd ~/src/js/me.sh && gl && ./sync_app_config.sh && popd"
alias src="cd ~/src"
alias tmp="cd ~/Tmp"
alias vsc="code ."
alias wst="osascript -e 'tell application \"Messages\" to send \"How are you?\" to buddy \"Wife\"'" # Wife Status
alias xck="osascript -e 'quit app \"Xcode\"'"
alias xcrmdd="rm -rf ~/Library/Developer/Xcode/DerivedData" # Nuke derived data
alias zshrc="bb ~/.zshrc"

# OLM Aliases
alias 'omc'='olm config'
alias 'omco'="omc DEV && omo"
alias 'omd'="olm doctor"
alias 'omda'="olm doctor --repair-type=auto"
alias 'oml'="xck && git pull && omco" # Get OLM Latest
alias 'olmcb'="pushd ~/src/ms/client-cocoa/app-ios; ./carthage-build-xcode-12.sh --platform iOS; popd" # Carthage build
alias 'omo'="olm open"
alias 'omr'="cd ~/src/ms/client-cocoa" # "OLM Repo"

# OAR Aliases
alias 'oar'="cd ~/src/ms/outlook-auth-framework"

# Functions
grsh() {
    git reset --soft "@~$1"
}

source ~/.zshrc_local 2> /dev/null # Load local .zshrc if available. Fail silently