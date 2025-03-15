# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ENV
export PATH=$PATH:$HOME/.rbenv/bin:$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/sbin:/opt/X11/bin:$HOME/Library/Android/sdk/platform-tools:/Users/jsc/.cargo/bin
export EDITOR="vim"
export LESS="-R" # Enable mouse scrolling in less.
export COLOR_RED='\033[0;31m'
export COLOR_RESET='\033[0m' # No Color

# Load rbenv
# 'rbenv init' would not work for me, so set it up manually
eval "$(rbenv init -)"

# Add Brew Autocompletions
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
fi

# ZSH CONFIG

zmodload zsh/complist

autoload -Uz compinit && compinit # Enable completions

_comp_options+=(globdots) # Completions include hidden files

unsetopt nomatch # Disable no-match globbing error zsh enables by default
setopt nocaseglob # Enable case-insensitive pattern matching
setopt autocd  # Enable cding by just tying the dir name.
setopt autocd autopushd # cd acts like pushd
setopt promptsubst # Required for prompt colors to work right

zstyle ':completion:*' completer _extensions _complete _approximate # Give priority to completing extensions first, then regular completions, then possible typos/fixes

zstyle ':autocomplete:*' min-input 2 # Minimum number of characters that must be typed before marlonrichert/zsh-autocomplete starts showing options
zstyle ':autocomplete:tab:*' insert-unambiguous yes # Autocomplete tab first inserts substrings before full matching patterns
zstyle ':autocomplete:tab:*' widget-style menu-select
zstyle ':completion:*' menu select # Use completion menu
zstyle ':completion:*' list-suffixesstyle ':completion:*' expand prefix suffix # partial completion suggestions
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*' # First string arg is to prefer case sensitive completion but fall back on case insensitive completion, second string arg is try to complete substrings from any position
zstyle ':completion:*:cd:*' tag-order local-directories
zstyle ':completion:*:paths' list-suffixes yes

# Enable completion cache
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/.zcompcache"

# Completion menu styles
zstyle ':completion:*' group-name '' # Enable completion menu groupings
zstyle ':completion:*:*:*:*:descriptions' format '%F{green}-- %d --%f' # Style completion menu section headers
zstyle ':completion:*:*:*:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f' # Style completion menu correction suggestions header
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f' # Style no matches found text
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS} # Style directory names in completion menu

bindkey -e # emacs key bindings
bindkey "^[[A" history-beginning-search-backward # up arrow goes to previous command with currently typed prefix. Not required when using marlonrichert/zsh-autocomplete but I might decide to abandon this plugin at some point.
bindkey "^[[B" history-beginning-search-forward # down arrow goes to next command with currently typed prefix, if I have up-arrowed back in history. Not required when using marlonrichert/zsh-autocomplete but I might decide to abandon this plugin at some point.

# Bind Ctrl + A to expanding aliase
zle -C alias-expension complete-word _generic
bindkey '^a' alias-expension
zstyle ':completion:alias-expension:*' completer _expand_alias

# Configure fastlane completions
. ~/.fastlane/completions/completion.zsh

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

### Load git aliases

load_git_aliases() {
    alias gA="git add --all"
    alias ga.="git add ."
    alias gai="g ai"
    alias gaui="g aui"
    alias gab="g absorb --and-rebase" # https://github.com/tummychow/git-absorb
    alias gap="git add --patch"
    alias gapi="g api"
    alias gbr="g branch --sort=-committerdate"
    alias gbrn="gb -m" # Git current branch rename - 'git branch -m <newname>
    alias gcdi="g cdi"
    alias gchi="g chi" # Git checkout head at index. Discards local changes to file at index
    alias gcr="git checkout --track origin/" # Git checkout Remote Branch - add branch name after
    alias gdi="g di"
    alias gdl="gd @~ @" # Git diff last; show diff of last commit
    alias gdt="git difftool"
    alias gfx="git fixup --autosquash"
    alias gfix="gfx"
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
    alias fl="bundle exec fastlane"
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
    alias mer="cd ~/Developer/jsc/me.sh"
    alias od="cd ~/OneDrive"
    alias oi="open *.jpg *.jpeg *.png" # Open images in dir
    alias pi="pod install"
    alias piru="pod install --repo-update"
    alias pls="sudo"
    alias pru="pod repo update"
    alias ra="sudo pkill -9 coreaudiod" # Restart Audio
    alias pw="pwgen -ysB1 20 | pbcopy"
    alias rz="source ~/.zshrc && source ~/.zshrc_local && source ~/.zshrc_ms" # Reload zsh
    alias sac="pushd -q ~/Developer/jsc/me.sh && ./sync_app_config.sh && popd -q"
    alias sacl="pushd -q ~/Developer/jsc/me.sh && gl && ./sync_app_config.sh && popd -q"
    alias sasc="sac && ssc"
    alias sascl="pushd -q ~/Developer/jsc/me.sh && sac && ssc && popd -q"
    alias scan="scanned"
    scanned() { convert -density 175 "$1" +noise Gaussian -rotate 0.5 -depth 2 ~/Tmp/SCAN.pdf }
    scannedg() { convert -density 175 "$1" -colorspace gray +noise Gaussian -rotate 0.5 -depth 2 ~/Tmp/SCAN.pdf }
    alias slq="swiftlint --quiet"
    alias slqa="slq --autocorrect"
    alias ssc="pushd -q ~/Developer/jsc/me.sh && ./sync_sys_config.sh && popd -q"
    alias sscl="pushd -q ~/Developer/jsc/me.sh && gl && ./sync_sys_config.sh && popd -q"
    alias src="cd ~/Developer"
    alias spd="speedtest"
    alias tldr="cht.sh"
    alias tmp="cd ~/Tmp"
    alias thmr="cd ~/Developer/jsc/jon.zsh-theme"
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

###

# Antidote

source $(brew --prefix)/opt/antidote/share/antidote/antidote.zsh
antidote load ${ZDOTDIR:-~}/.zsh_plugins

# LOAD ALIASES

load_git_aliases
load_non_git_aliases

# LOCAL ZSH

source ~/.zshrc_local 2> /dev/null # Load local .zshrc if available. Fail silently

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh