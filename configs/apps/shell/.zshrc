# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ENV
export PATH=$PATH:$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/sbin:/opt/X11/bin:$HOME/.rvm/bin:$HOME/Library/Android/sdk/platform-tools:/Users/jsc/.cargo/bin
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
bindkey "^[[A" history-beginning-search-backward # up arrow goes to previous command with currently typed prefix. Not required when using marlonrichert/zsh-autocomplete but I might decide to abandon this plugin at some point.
bindkey "^[[B" history-beginning-search-forward # down arrow goes to next command with currently typed prefix, if I have up-arrowed back in history. Not required when using marlonrichert/zsh-autocomplete but I might decide to abandon this plugin at some point.

# Utility Functions

function close_xcode_project() {
    if [ -z "$1" ]; then
        echo "Usage: close_xcode_project <project_name>"
        return 1
    fi

    osascript -e "
    tell application \"Xcode\"
        set projectName to \"$1\"
        try
            repeat with w in (windows whose name contains projectName)
                close w
            end repeat
        on error errMsg number errNum
            if errNum is not -128 then
                display dialog \"Error: \" & errMsg
            end if
        end try
    end tell
    "
}

# DEFINE LOAD ALIAS FUNCTIONS

### Load git aliases. Zinit loads plugins async after the console prompt appears, so git aliases (which sometimes conflict with zsh git plugin aliases) need loaded after the zsh git plugin
load_git_aliases() {
    alias gA="git add --all"
    alias ga.="git add ."
    alias gai="g ai"
    alias gaui="g aui"
    alias gap="git add --patch"
    alias gapi="g api"
    alias gbr="g branch --sort=-committerdate"
    alias gcdi="g cdi"
    alias gchi="g chi" # Git checkout head at index. Discards local changes to file at index
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
    alias b="beep"
    alias bb="open -b com.barebones.bbedit"
    alias beep="echo $'\a'" # Beeps. Useful for [long command]; beep
    alias bi="brew install"
    alias bbi="brew bundle install"
    alias bl="brew list"
    alias blc="brew list --cask"
    alias bs="brew search"
    alias bsc="brew search --cask"
    alias bun="brew uninstall"
    alias bu="brew update"
    alias bup="bu && brew upgrade"
    alias bupc="bu && brew upgrade --cask"
    alias cdf='cd "`osascript -e "tell application \\"Finder\\" to get POSIX path of (insertion location as text)"`"' # cd to front finder dir
    alias cht="cht.sh"
    alias dl="cd ~/Downloads"
    alias ddnuke="rm -rf ~/Library/Developer/Xcode/DerivedData" # Nuke derived data
    alias emptytrash="rm -rf ~/.Trash/*" # Faster than emptying trash through Finder
    alias f="open ."
    alias fdr="open ."
    alias fm="nnn" # Open 'nnn' file manager in current dir
    alias gcg="open ~/.gitconfig_js; open ~/.gitconfig_ms; open ~/.gitconfig"
    alias hm="cd ~/"
    alias hst="history"
    alias hstg="hst | grep"
    alias hstr="fc -l -20" # Recent History
    alias jks="jekyll serve"
    alias js="cd ~/Developer/js"
    alias ls='ls -aG $@'
    alias me="mer && vsc"
    alias mer="cd ~/Developer/js/me.sh"
    alias od="cd ~/OneDrive"
    alias oi="open *.jpg *.jpeg *.png" # Open images in dir
    alias pi="pod install"
    alias piru="pod install --repo-update"
    alias pls="sudo"
    alias pru="pod repo update"
    alias ra="sudo pkill -9 coreaudiod" # Restart Audio
    alias pw="pwgen -ysB1 20 | pbcopy"
    alias rz="source ~/.zshrc && source ~/.zshrc_local && source ~/.zshrc_ms" # Reload zsh
    alias sac="pushd -q ~/Developer/js/me.sh && ./sync_app_config.sh && popd -q"
    alias sacl="pushd -q ~/Developer/js/me.sh && gl && ./sync_app_config.sh && popd -q"
    alias sasc="sac && ssc"
    alias sascl="pushd -q ~/Developer/js/me.sh && sac && ssc && popd -q"
    scanned() { convert -density 175 "$1" +noise Gaussian -rotate 0.5 -depth 2 ~/Tmp/SCAN.pdf }
    scannedg() { convert -density 175 "$1" -colorspace gray +noise Gaussian -rotate 0.5 -depth 2 ~/Tmp/SCAN.pdf }
    alias ssc="pushd -q ~/Developer/js/me.sh && ./sync_sys_config.sh && popd -q"
    alias sscl="pushd -q ~/Developer/js/me.sh && gl && ./sync_sys_config.sh && popd -q"
    alias src="cd ~/Developer"
    alias spd="speedtest"
    alias tldr="cht.sh"
    alias tmp="cd ~/Tmp"
    alias thmr="cd ~/Developer/js/jon.zsh-theme"
    alias thm="thmr && vsc"
    alias tr="tree -C -L 2"
    alias vsc="code ."
    alias wst="osascript -e 'tell application \"Messages\" to send \"How are you?\" to buddy \"Wife\"'" # Wife Status
    alias xcg="xcodegen"
    alias xck="osascript -e 'quit app \"Xcode\"'"
    alias xci="xcinfo"
    alias xcii="xcinfo install"
    alias xcil="xcinfo list"
    alias xcp="xcode-info --print-path"
    alias xcpc="close_xcode_project"
    alias xcrmdd="rm -rf ~/Library/Developer/Xcode/DerivedData" # Nuke derived data
    alias xcs="xcode-select"
    alias xcss="sudo xcode-select --switch"
    alias zpu="zplugin update" # zsh plugin update
    alias zpua="zplugin update --all" # zsh plugin update all
    alias zshrc="bb ~/.zshrc"
    alias z="zshrc"
    alias zl="bb ~/.zshrc_local"
    alias zr="source ~/.zshrc" # Zshrc Reload
}

# ZINIT

source $(brew --prefix)/opt/zinit/zinit.zsh
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

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk
