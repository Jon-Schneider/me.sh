# ENV variables
export PATH=$PATH:$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:$HOME/.rvm/bin
export EDITOR="vim"

unsetopt nomatch # Disable no-match globbing error zsh enables by default
setopt nocaseglob # Enable case-insensitive pattern matching
setopt autocd  # Enable cding by just tying the dir name.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' # Make compinit completions case-insensitive
autoload -Uz compinit && compinit # Enable completions
setopt autocd autopushd # cd acts like pushd
setopt promptsubst # Required for prompt colors to work right

# Personal Aliases and Functions
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
alias fdr="open ."
alias gcr="git checkout --track origin/" # Git checkout Remote Branch - add branch name after
alias gai="g ai"
alias gdi="g di"
alias gdl="gd @~ @" # Git diff last; show diff of last commit
alias gmv="g mv" # Spaces are for plebians
alias gr="git reset"
alias grh="git reset --hard"
alias grs="git reset --soft"
grsh() { git reset --soft "@~$1" }
alias gs="git status"
alias hm="cd ~/"
alias hst="history"
alias hstg="hst | grep"
alias hstr="fc -l -20" # Recent History
alias js="cd ~/src/js"
alias ls='ls -aG $@'
alias me="mer && vsc"
alias mer="cd ~/src/js/me.sh"
alias od="cd ~/OneDrive"
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
alias zpu="zplugin update" # zsh plugin update
alias zpua="zplugin update --all" # zsh plugin update all
alias zshrc="bb ~/.zshrc"

# MS Aliases
alias odm="cd ~/OneDrive\ -\ Microsoft"
alias ms="cd ~/src/ms"

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

source ~/.rvm/scripts/rvm
source ~/.zshrc_local 2> /dev/null # Load local .zshrc if available. Fail silently

# ZINIT

if [[ ! -f $HOME/.zinit/bin/zinit.zsh ]]; then
    print -P "%F{33}▓▒░ %F{220}Installing %F{33}DHARMA%F{220} Initiative Plugin Manager (%F{33}zdharma/zinit%F{220})…%f"
    command mkdir -p "$HOME/.zinit" && command chmod g-rwX "$HOME/.zinit"
    command git clone https://github.com/zdharma/zinit "$HOME/.zinit/bin" && \
        print -P "%F{33}▓▒░ %F{34}Installation successful.%f%b" || \
        print -P "%F{160}▓▒░ The clone has failed.%f%b"
fi

source "$HOME/.zinit/bin/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

zinit ice lucid wait
zinit snippet OMZL::git.zsh
zinit ice lucid wait
zinit snippet OMZP::git
zinit snippet OMZP::last-working-dir # Shell crashes if loaded async
zinit ice lucid wait
zinit snippet OMZP::xcode
zinit ice lucid wait
zinit light zsh-users/zsh-syntax-highlighting

# Load local dev clone of my theme if present, otherwise use remote
[[ -d "$HOME/src/js/jon.zsh-theme" ]] && local theme_path="$HOME/src/js/jon.zsh-theme" || local theme_path="Jon-Schneider/jon.zsh-theme"
zinit ice lucid wait'!'
zinit light $theme_path