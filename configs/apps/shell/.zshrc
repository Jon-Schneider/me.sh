# ENV
export PATH=$PATH:$HOME/.rbenv/bin:$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/sbin:/opt/X11/bin:$HOME/Library/Android/sdk/platform-tools:/Users/jsc/.cargo/bin
export EDITOR="micro"
export LESS="-R" # Enable mouse scrolling in less.
export COLOR_RED='\033[0;31m'
export COLOR_RESET='\033[0m' # No Color

# Load rbenv
# 'rbenv init' would not work for me, so set it up manually
eval "$(rbenv init -)"

# Add local + Brew autocompletions
fpath=("$HOME/.zsh/completions" $fpath)

if type brew &>/dev/null; then
  fpath=("$(brew --prefix)/share/zsh/site-functions"
$fpath)
fi

setopt completealiases # Enable autocompletions for aliases

# ZSH CONFIG

zmodload zsh/complist

autoload -Uz compinit && compinit # Enable completions

_comp_options+=(globdots) # Completions include hidden files

# Add Graphite (gt) Autocompletions
_gt_yargs_completions()
{
  local reply
  local si=$IFS
  IFS=$'
' reply=($(COMP_CWORD="$((CURRENT-1))" COMP_LINE="$BUFFER" COMP_POINT="$CURSOR" gt --get-yargs-completions "${words[@]}"))
  IFS=$si
  _describe 'values' reply
}
compdef _gt_yargs_completions gt

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

# Up arrow history filtering
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

bindkey -e # emacs key bindings
bindkey "^[[A" history-beginning-search-backward # up arrow goes to previous command with currently typed prefix. Not required when using marlonrichert/zsh-autocomplete but I might decide to abandon this plugin at some point.
bindkey "^[[B" history-beginning-search-forward # down arrow goes to next command with currently typed prefix, if I have up-arrowed back in history. Not required when using marlonrichert/zsh-autocomplete but I might decide to abandon this plugin at some point.

# Bind Ctrl + A to expanding aliase
zle -C alias-expension complete-word _generic
bindkey '^a' alias-expension
zstyle ':completion:alias-expension:*' completer _expand_alias

# Bind Cmd + Arrow Keys to escape sequences for moving cursor to start and end of line
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line

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
    unalias gcb 2>/dev/null # Unalias gcb so I can create a function instead
    gcb() { git checkout -b "jsc/$(date +%F)--$1" }
    alias gbl="git branches-latest" # Lists git branches with last commit date, sorted from least recently to most recently updated
    alias gbr="g branch --sort=-committerdate"
    alias gbrn="gb -m" # Git current branch rename - 'git branch -m <newname>
    alias gcdi="g cdi"
    alias gchi="g chi" # Git checkout head at index. Discards local changes to file at index
    alias gcml="gcm && gl" # Get checkout main and pull latest
    alias gcr="git checkout --track origin/" # Git checkout Remote Branch - add branch name after
    alias gdi="g di"
    alias gdl="gd @~ @" # Git diff last; show diff of last commit
    alias gdt="git difftool"
    alias gfx="git fixup"
    alias gfix="gfx"
    alias glfp="git lfs pull"
    alias glm='git pull --rebase=false' # git pull docs say merge strategy (default) used if --rebase=false
    alias glr='git pull --rebase'
    alias gmv="g mv" # Spaces are for plebians
    alias gpff="gp --force" # 'gpf' is mapped to 'git push --force-with-lease --force-if-includes'
    alias gptg="g push --tags"
    alias gr="git reset"
    alias grbbi='echo "Running git_rebase_bbedit"; ~/bin/git_rebase_bbedit'
    alias grh="git reset --hard"
    alias grs="git reset --soft"
    alias grsh="git reset --soft @~1"
    grsi() { git reset --soft "@~$1" }
    alias gtd="g todo" # Prints TODO comments in uncommitted changes
    alias gs="git status"
    alias gstas="git stash --staged" # Stash only staged changes
    alias gstau="git stash push --keep-index" # Stash only unstaged changes
    alias gsu="gs -uno"
    alias gwtl="git worktree list"
    alias gwtp="git worktree prune"
    alias gwtr="git worktree remove"
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
    alias bup="brew upgrade"
    alias bupc="bu && brew upgrade --cask"
    alias cdf='cd "`osascript -e "tell application \\"Finder\\" to get POSIX path of (insertion location as text)"`"' # cd to front finder dir
    alias cht="cht.sh"
    alias cld="claude"
    alias cldc="claude --continue"
    alias cldr="claude --resume"
    alias ddnuke="rm -rf ~/Library/Developer/Xcode/DerivedData" # Nuke derived data
    alias dev="open ~/Library/Developer"
    alias dl="cd ~/Downloads"
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
    alias jira="acli jira"
    alias jks="jekyll serve"
    alias jr="jira"
    alias js="cd ~/Developer/jsc"
    alias lib="open ~/Library"
    alias ls='ls -aG $@'
    alias me="mer && vsc"
    alias mer="cd ~/Developer/jsc/me.sh"
    alias od="cd ~/OneDrive"
    alias oi="open *.jpg *.jpeg *.png" # Open images in dir
    alias pi="pod install"
    alias piru="pod install --repo-update"
    alias pru="pod repo update"
    alias ra="sudo pkill -9 coreaudiod" # Restart Audio
    alias pw="pwgen -ysB1 20 | pbcopy"
    alias repos="cd ~/Developer/jsc"
    alias rz="source ~/.zshrc && source ~/.zshrc_local && source ~/.zshrc_ms" # Reload zsh
    alias sac="pushd -q ~/Developer/jsc/me.sh && ./sync_app_config.sh && popd -q"
    alias sacl="pushd -q ~/Developer/jsc/me.sh && gl && ./sync_app_config.sh && popd -q"
    alias sasc="sac && ssc"
    alias sascl="pushd -q ~/Developer/jsc/me.sh && sac && ssc && popd -q"
    alias scan="scanned"
    scanned() { convert -density 175 "$1" +noise Gaussian -rotate 0.5 -depth 2 ~/Tmp/SCAN.pdf }
    scannedg() { convert -density 175 "$1" -colorspace gray +noise Gaussian -rotate 0.5 -depth 2 ~/Tmp/SCAN.pdf }
    alias sims="cd ~/Library/Developer/CoreSimulator/Devices"
    alias slq="swiftlint --quiet"
    alias slqa="slq --autocorrect"
    alias ssc="pushd -q ~/Developer/jsc/me.sh && ./sync_sys_config.sh && popd -q"
    alias sscl="pushd -q ~/Developer/jsc/me.sh && gl && ./sync_sys_config.sh && popd -q"
    alias src="cd ~/Developer"
    alias spd="speedtest"
    alias tc="tokencount"
    alias thmr="cd ~/Developer/jsc/jon.zsh-theme"
    alias thm="thmr && vsc"
    alias tldr="cht.sh"
    alias tmp="cd ~/Tmp"
    alias tokencount="npx tiktoken-cli"
    alias tr="tree -C -L 2"
    alias vsc="code ."
    alias wst="osascript -e 'tell application \"Messages\" to send \"How are you?\" to buddy \"Wife\"'" # Wife Status
    alias xcg="xcodegen"
    alias xck="osascript -e 'quit app \"Xcode\"'"
    alias xci="xcinfo"
    alias xcii="xcinfo install"
    alias xcil="xcinfo list"
    alias xcg="xcodegen"
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

    # Agents and Sandboxing aliases

    safe() {
      local safehouse_xcode_override="$HOME/.config/agent-safehouse/profiles/55-integrations-optional/xcode-cli.sb"

      safehouse \
        --enable=xcode \
        --enable=lldb \
        --enable=macos-gui \
        --enable=keychain \
        --env-pass=TMUX,TMUX_PANE \
        --append-profile="$safehouse_xcode_override" \
        --add-dirs="$HOME/.agents:$HOME/bin:$HOME/.claude:$HOME/.codex:$HOME/Developer/jsc/me.sh:$HOME/Library/Caches:$HOME/Library/Developer" \
        --add-dirs-ro="$HOME/.config/acli" \
        "$@"
    }

    claude-sb() { safe claude --permission-mode bypassPermissions 		--dangerously-skip-permissions "$@"; }
    alias cld="claude-sb"
    alias cldc="cld --continue"
    alias cldr="cld --resume"

    codex-sb() { safe codex --dangerously-bypass-approvals-and-sandbox "$@"; }
    alias cdx="codex-sb"
    alias cdxr="cdx resume"

    gemini-sb() { safe gemini "$@" }
    alias gemi="gemini-sb --approval-mode=yolo"
    alias gemil="gemi lastest"
    alias gemir="gemi --resume"

    opencode-sb() { safe opencode "$@"; }
    alias oc="opencode-sb"
    alias occ="oc --continue"

    # Github
    alias ghst="gh stack"
    ghlc() { # "GitHub Last Commit", opens last commit on GitHub
      local url
      url=$(git remote get-url origin \
        | sed -E 's#git@github.com:(.*)\.git#https://github.com/\1#; s#\.git$##')
      open "$url/commit/$(git rev-parse HEAD)"
    }

    # Tmux aliases
    alias ta="tmux attach"
    alias tls="tmux list-sessions"
    alias tk="tmux kill-session -t"
    alias tm="tmux"
    tmnw() {
      printf "new window: "
      read NEW_WINDOW
      tmux new-window -n $NEW_WINDOW
    }
    alias tmr="tmux rename-session"
}

load_worktree_functions() {
	wtc() {
	  local name="$1"
	  if [ -z "$name" ]; then
		echo "Usage: wtc <branch-name>"
		return 1
	  fi

	  local root
	  root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
		echo "Not inside a git repository"
		return 1
	  }

	  # Enforce running from repo root
	  if [ "$PWD" != "$root" ]; then
		echo "Run this from repo root: $root"
		return 1
	  fi

	  local dated_branch repo_name worktree_path
	  dated_branch="jsc/$(date +%F)--$name"
	  worktree_path="./.worktrees/${name}"
	  git worktree add -b "$dated_branch" "$worktree_path" || return 1
	  cd "$worktree_path" || return 1
	}
}

###

# Antidote

source $(brew --prefix)/opt/antidote/share/antidote/antidote.zsh
antidote load ${ZDOTDIR:-~}/.zsh_plugins

# LOAD ALIASES AND FUNCTIONS

load_git_aliases
load_non_git_aliases
load_worktree_functions

# LOCAL ZSH

source ~/.zshrc_local 2> /dev/null # Load local .zshrc if available. Fail silently

eval "$(starship init zsh)"

# Customize config file location for apps that support it (including ghostty)
export XDG_CONFIG_HOME="$HOME/.config"

# Skip tmux autostart when the terminal was opened for a specific directory.
shell_has_preassigned_directory() {
  [[ "${PWD:A}" != "${HOME:A}" ]]
}

# Attach to main session if not already active, create a new tmux session if it is
if command -v tmux >/dev/null 2>&1 && [[ -z "$TMUX" && -o interactive ]]; then
  if shell_has_preassigned_directory; then
    dir_name="${PWD:t}"  # <-- last path component

    if tmux has-session -t main 2>/dev/null; then
      new_window="$(tmux new-window -P -F '#{window_id}' -t main -c "$PWD" -n "$dir_name")"
      tmux select-window -t "$new_window"
      exec tmux attach -t main
    else
      exec tmux new-session -s main -c "$PWD" -n "$dir_name"
    fi
  else
    if tmux has-session -t main 2>/dev/null; then
      exec tmux attach -t main
    else
      exec tmux new-session -s main
    fi
  fi
fi