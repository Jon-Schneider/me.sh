# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ENV
export PATH=$PATH:$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:$HOME/.rvm/bin
export EDITOR="vim"
export LESS="-R" # Enable mouse scrolling in less.
export COLOR_RED='\033[0;31m'
export COLOR_RESET='\033[0m' # No Color

source ~/.rvm/scripts/rvm

# Add Brew Autocompletions
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
fi

# ZSH CONFIG

unsetopt nomatch # Disable no-match globbing error zsh enables by default
setopt nocaseglob # Enable case-insensitive pattern matching
setopt autocd  # Enable cding by just tying the dir name.

zstyle ':autocomplete:*' min-input 2 # Minimum number of characters that must be typed before marlonrichert/zsh-autocomplete starts showing options
zstyle ':autocomplete:tab:*' insert-unambiguous yes # Autocomplete tab first inserts substrings before full matching patterns
zstyle ':autocomplete:tab:*' widget-style menu-select
zstyle ':completion:*' list-suffixesstyle ':completion:*' expand prefix suffix # partial completion suggestions
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*:cd:*' tag-order local-directories
zstyle ':completion:*:paths' list-suffixes yes

autoload -Uz compinit && compinit # Enable completions
setopt autocd autopushd # cd acts like pushd
setopt promptsubst # Required for prompt colors to work right
bindkey $'^[[A' up-line-or-search # up arrow goes to previous command with currently typed prefix. Not required when using marlonrichert/zsh-autocomplete but I might decide to abandon this plugin at some point.
bindkey $'^[[B' down-line-or-search  # down arrow goes to next command with currently typed prefix, if I have up-arrowed back in history. Not required when using marlonrichert/zsh-autocomplete but I might decide to abandon this plugin at some point.

# DEFINE LOAD ALIAS FUNCTIONS

### Load git aliases. Zinit loads plugins async after the console prompt appears, so git aliases (which sometimes conflict with zsh git plugin aliases) need loaded after the zsh git plugin
load_git_aliases() {
    alias gA="git add --all"
    alias ga.="git add ."
    alias gai="g ai"
    alias gap="git add --patch"
    alias gcr="git checkout --track origin/" # Git checkout Remote Branch - add branch name after
    alias gdi="g di"
    alias gdl="gd @~ @" # Git diff last; show diff of last commit
    alias gdt="git difftool"
    alias glfp="git lfs pull"
    alias glm='git pull --rebase=false' # git pull docs say merge strategy (default) used if --rebase=false
    alias glr='git pull --rebase'
    alias gmv="g mv" # Spaces are for plebians
    alias gr="git reset"
    alias grbod="grb origin/develop"
    alias grh="git reset --hard"
    alias grs="git reset --soft"
    grsh() { git reset --soft "@~$1" }
    alias gs="git status"
    alias gsu="gs -uno"
}

load_non_git_aliases() {

    ## Personal Aliases
    alias activitymonitor="htop"
    alias am="activitymonitor"
    alias bb="open -b com.barebones.bbedit"
    alias beep="echo $'\a'" # Beeps. Useful for [long command]; beep
    alias bi="brew install"
    alias bl="brew list"
    alias blc="brew list --cask"
    alias bs="brew search"
    alias bsc="brew search --cask"
    alias bun="brew uninstall"
    alias bu="brew update"
    alias bup="bu && brew upgrade"
    alias cdf='cd "`osascript -e "tell application \\"Finder\\" to get POSIX path of (insertion location as text)"`"' # cd to front finder dir
    alias cht="cht.sh"
    alias dl="cd ~/Downloads"
    alias ddnuke="rm -rf ~/Library/Developer/Xcode/DerivedData" # Nuke derived data
    alias f="open ."
    alias fdr="open ."
    alias fm="nnn"
    alias gcg="open ~/.gitconfig_js; open ~/.gitconfig_ms; open ~/.gitconfig"
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
    alias ra="sudo pkill -9 coreaudiod" # Restart Audio
    alias sac="pushd -q ~/src/js/me.sh && ./sync_app_config.sh && popd -q"
    alias sacl="pushd -q ~/src/js/me.sh && gl && ./sync_app_config.sh && popd -q"
    alias sasc="sac && ssc"
    alias sascl="pushd -q ~/src/js/me.sh && sac && ssc && popd -q"
    alias ssc="pushd -q ~/src/js/me.sh && ./sync_sys_config.sh && popd -q"
    alias sscl="pushd -q ~/src/js/me.sh && gl && ./sync_sys_config.sh && popd -q"
    alias src="cd ~/src"
    alias tldr="cheat.sh"
    alias tmp="cd ~/Tmp"
    alias thmr="cd ~/src/js/jon.zsh-theme"
    alias thm="thmr && vsc"
    alias tr="tree -C -L 2"
    alias vsc="code ."
    alias wst="osascript -e 'tell application \"Messages\" to send \"How are you?\" to buddy \"Wife\"'" # Wife Status
    alias xck="osascript -e 'quit app \"Xcode\"'"
    alias xcrmdd="rm -rf ~/Library/Developer/Xcode/DerivedData" # Nuke derived data
    alias xcs="xcodes"
    alias zpu="zplugin update" # zsh plugin update
    alias zpua="zplugin update --all" # zsh plugin update all
    alias zshrc="bb ~/.zshrc"
    alias z="zshrc"
}

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

zinit snippet OMZP::last-working-dir # Shell crashes if loaded async
zinit wait lucid atload'load_git_aliases' for \
        OMZL::git.zsh \
        OMZP::git        
zinit wait lucid for \
        OMZP::xcode \
        zsh-users/zsh-syntax-highlighting \
        marlonrichert/zsh-autocomplete

zinit ice lucid wait'!0b'
zinit ice depth=1; zinit light romkatv/powerlevel10k

# LOAD ALIASES

load_non_git_aliases

# LOCAL ZSH

source ~/.zshrc_local 2> /dev/null # Load local .zshrc if available. Fail silently

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh