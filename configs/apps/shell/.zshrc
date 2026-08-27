# ENV
export PATH=$PATH:/opt/homebrew/bin:/opt/homebrew/sbin:$HOME/.rbenv/bin:$HOME/bin:$HOME/.local/bin:$HOME/.mtplx/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/sbin:/opt/X11/bin:$HOME/Library/Android/sdk/platform-tools:/Users/jsc/.cargo/bin
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

_comp_options+=(globdots) # Completions include hidden files

unsetopt nomatch # Disable no-match globbing error zsh enables by default
setopt nocaseglob # Enable case-insensitive pattern matching
setopt autocd  # Enable cding by just tying the dir name.
setopt autocd autopushd # cd acts like pushd
setopt promptsubst # Required for prompt colors to work right

zstyle ':completion:*' completer _extensions _complete _approximate # Give priority to completing extensions first, then regular completions, then possible typos/fixes

zstyle ':autocomplete:*' min-input 2 # Minimum number of characters that must be typed before marlonrichert/zsh-autocomplete starts showing options
zstyle ':autocomplete:*:*' list-lines 10 # Limit autocomplete suggestions to 10 visible lines
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
# zsh-autocomplete's default description and correction formats are required
# for its list-lines cap; overriding them causes zsh to render the full list.
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
    unalias gbs 2>/dev/null
    alias gbs="git-branch-select" # script in ~/bin
    alias gcdi="g cdi"
    alias gchi="g chi" # Git checkout head at index. Discards local changes to file at index
    alias gcml="gcm && gl" # Get checkout main and pull latest
    alias gcr="git checkout --track origin/" # Git checkout Remote Branch - add branch name after
    alias gdi="g di"
    alias gdl="gd @~ @" # Git diff last; show diff of last commit
    alias gdt="git difftool"
    alias gfx="git fixup"
    alias gfix="gfx"
    alias ghs="gh stack"
    alias ghsa="ghs add"
    alias ghsi="ghs init"
    alias ghss="ghs sync"
    alias ghsu="ghs submit"
    alias ghsr="ghs rebase"
    alias ghsm="ghs modify"
    alias ghsv="ghs view"
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
    gul() { rm "$(git rev-parse --git-dir)/index.lock" }
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
    caf() { # Prevents system sleeping for N minutes (e.g. caf 5)
        if [[ -z "$1" ]]; then
            caffeinate
        else
            caffeinate -t $(( $1 * 60 ))
        fi
    }
    alias cafi="caffeinate -i" # Prevents system sleeping as long as passed process is running
    alias cdf='cd "`osascript -e "tell application \\"Finder\\" to get POSIX path of (insertion location as text)"`"' # cd to front finder dir
    alias cht="cht.sh"
    alias ddnuke="rm -rf ~/Library/Developer/Xcode/DerivedData" # Nuke derived data
    alias dev="open ~/Library/Developer"
    alias dl="cd ~/Downloads"
    alias emptytrash="rm -rf ~/.Trash/*" # Faster than emptying trash through Finder
    alias f="open ."
    alias fdr="open ."
    alias fl="bundle exec fastlane"
    alias fm="nnn" # Open 'nnn' file manager in current dir
    alias hd="hunk diff"
    alias hm="cd ~/"
    alias hst="history"
    alias hstg="hst | grep"
    alias hstr="fc -l -20" # Recent History
    alias jira="acli jira"
    alias jks="jekyll serve"
    alias jr="jira"
    alias js="cd ~/Developer/jsc"
    alias kr="sudo killall Karabiner-Core-Service" # Karabiner Restart
    alias lib="open ~/Library"
    alias ls='ls -aG1 $@'
    alias mer="cd ~/Developer/jsc/me.sh"
    alias od="cd ~/OneDrive"
    alias oi="open *.jpg *.jpeg *.png" # Open images in dir
    alias ra="sudo pkill -9 coreaudiod" # Restart Audio
    alias rgp="launchctl unload -S Aqua /Library/LaunchAgents/com.paloaltonetworks.gp.pangpa.plist && launchctl unload -S Aqua /Library/LaunchAgents/com.paloaltonetworks.gp.pangps.plist && launchctl load -S Aqua /Library/LaunchAgents/com.paloaltonetworks.gp.pangpa.plist && launchctl load -S Aqua /Library/LaunchAgents/com.paloaltonetworks.gp.pangps.plist" # Restart Global Protect Service
    alias pw="pwgen -ysB1 20 | pbcopy"
    alias repos="cd ~/Developer/jsc"
    alias rz="source ~/.zshrc && source ~/.zshrc_local && source ~/.zshrc_ms" # Reload zsh
    alias scan="scanned"
    scanned() { convert -density 175 "$1" +noise Gaussian -rotate 0.5 -depth 2 ~/Tmp/SCAN.pdf }
    scannedg() { convert -density 175 "$1" -colorspace gray +noise Gaussian -rotate 0.5 -depth 2 ~/Tmp/SCAN.pdf }
    alias sims="cd ~/Library/Developer/CoreSimulator/Devices"
    alias slq="swiftlint --quiet"
    alias slqa="slq --autocorrect"
    alias src="cd ~/Developer"
    alias spd="speedtest"
    alias tc="tokencount"
    alias thmr="cd ~/Developer/jsc/jon.zsh-theme"
    alias thm="thmr && vsc"
    alias tldr="cht.sh"
    alias tmp="cd ~/Tmp"
    alias tokencount="npx tiktoken-cli"
    alias tr="tree -C -L 2"

    # Unquarantine files
    uq() {
      if (( $# == 0 )); then
          echo "usage: uq <file-or-folder> [...]" >&2
          return 2
      fi

      xattr -d com.apple.quarantine "$@"
    }

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
    alias xl="xlent"
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
        --env-pass=HERDR_ENV,HERDR_SOCKET_PATH,HERDR_PANE_ID,HERDR_TAB_ID,HERDR_WORKSPACE_ID \
        --append-profile="$safehouse_xcode_override" \
        --add-dirs="$HOME/.agents:$HOME/bin:$HOME/.claude:$HOME/.codex:$HOME/Developer/jsc/me.sh:$HOME/Library/Caches:$HOME/Library/Developer" \
        --add-dirs-ro="$HOME/.config/acli" \
        "$@"
    }

    claude-sb() { safe claude --permission-mode bypassPermissions --dangerously-skip-permissions "$@"; }
    alias cldsb="claude-sb"
    alias cldus="claude --permission-mode bypassPermissions --dangerously-skip-permissions" # Claude unsafe

    alias cld="claude"
    alias cldc="cld --continue"
    alias cldr="cld --resume"

    codex-sb() { safe codex --dangerously-bypass-approvals-and-sandbox "$@"; }
    alias cdxsb="codex-sb"
    alias cdxus="codex --dangerously-bypass-approvals-and-sandbox" # Codex unsafe

    alias cdx="codex"
    alias cdxr="cdx resume"

    opencode-sb() { safe opencode "$@"; }
    alias ocsb="opencode-sb"
    alias ocus="oc -- --yolo"

    alias oc="opencode"
    alias occ="oc --continue"

    # Github
    alias ghst="gh stack"
    ghlc() { # "GitHub Last Commit", opens last commit on GitHub
      local url
      url=$(git remote get-url origin \
        | sed -E 's#git@github.com:(.*)\.git#https://github.com/\1#; s#\.git$##')
      open "$url/commit/$(git rev-parse HEAD)"
    }
}

load_worktree_functions() {
	wtc() {
	  local base_branch
	  zparseopts -D -F -K -E -- b:=base_branch -base:=base_branch || return 1
	  base_branch="${base_branch[-1]}"

	  local name="$1"
	  if [ -z "$name" ]; then
		echo "Usage: wtc [--base/-b <base-branch>] <branch-name>"
		return 1
	  fi

	  # Resolve the repo's main worktree (always listed first by `git worktree
	  # list`), so new worktrees land in the primary checkout no matter whether
	  # wtc was invoked from a subdirectory or from inside another worktree.
	  local main_root
	  main_root="$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
	  if [ -z "$main_root" ]; then
		echo "Not inside a git repository"
		return 1
	  fi

	  if [ -z "$base_branch" ]; then
		base_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|^refs/remotes/origin/||')
		if [ -z "$base_branch" ]; then
		  if git show-ref --verify --quiet refs/heads/main; then
			base_branch="main"
		  elif git show-ref --verify --quiet refs/heads/master; then
			base_branch="master"
		  else
			echo "Could not detect default branch (neither main nor master exists locally)"
			return 1
		  fi
		fi
	  fi

	  local dated_branch worktree_path
	  dated_branch="jsc/$(date +%F)--$name"
	  worktree_path="$main_root/.worktrees/${name}"
	  git -C "$main_root" worktree add -b "$dated_branch" "$worktree_path" "$base_branch" || return 1
	  if [ -f "$main_root/.env" ]; then
		cp "$main_root/.env" "$worktree_path/.env" || return 1
	  fi
	  cd "$worktree_path" || return 1
	}
}

###

# Antidote

source $(brew --prefix)/opt/antidote/share/antidote/antidote.zsh
antidote load ${ZDOTDIR:-~}/.zsh_plugins

# Per-directory .env loader (replaces the ohmyzsh dotenv plugin). See ~/bin/autoenv.zsh
source ~/bin/autoenv.zsh

# LOAD ALIASES AND FUNCTIONS

load_git_aliases
load_non_git_aliases
load_worktree_functions

# LOCAL ZSH

source ~/.zshrc_local 2> /dev/null # Load local .zshrc if available. Fail silently
source ~/.env 2> /dev/null # Load local .env if available. Fail silently

eval "$(starship init zsh)"

# Customize config file location for apps that support it (including ghostty)
export XDG_CONFIG_HOME="$HOME/.config"

# Opencode merges shared global config file into ~/.config/opencode/opencode.json, which is left untracked so mtplx and sync-opencode-omlx-models can rewrite it freely.
export OPENCODE_CONFIG="$XDG_CONFIG_HOME/opencode/opencode-shared.json"

# True when the terminal was opened for a specific directory rather than home.
shell_has_preassigned_directory() {
  [[ "${PWD:A}" != "${HOME:A}" ]]
}

# Always-inside-herdr: every top-level interactive shell opens inside the one
# persistent herdr session
#
# - Session already active: attach to it. When this terminal was opened for a
#   specific directory, first create and focus a workspace there. A bare reattach would
#   NOT open anything at $PWD: herdr only honors the startup cwd when the
#   session has no workspaces at all.
# - No session yet: plain `herdr` spawns the background server and opens its
#   startup workspace at $PWD.
if command -v herdr >/dev/null 2>&1 && [[ -z "$HERDR_ENV" && -o interactive ]]; then
  if herdr status server --json 2>/dev/null | grep -q '"running":true'; then
    if shell_has_preassigned_directory; then
      herdr workspace create --cwd "$PWD" --label "${PWD:t}" --focus >/dev/null 2>&1 || true
    fi
    exec herdr
  else
    exec herdr
  fi
fi

# Starship GitHub PR cache hooks

# Instant sidebar cwd updates under herdr: herdr 0.7.x tracks each pane's cwd
# (surfaced by the me.active-cwd plugin's $active_cwd/$active_repo sidebar
# rows) but fires no plugin event when it changes — only focus/create/exit
# events exist — so a bare `cd` otherwise refreshes only on the next
# refocus. Fire the handler ourselves on chpwd; it diffs against its last
# report, so redundant runs are cheap no-ops. Stdio is fully detached:
# herdr captures the handler's log lines when IT spawns the plugin, but
# here the shell would otherwise print them into the pane.
autoload -Uz add-zsh-hook

herdr_active_cwd_refresh() {
  [[ -n "$HERDR_ENV" && -f "$HOME/.config/herdr/active_cwd_on_event.py" ]] || return 0
  HERDR_PLUGIN_STATE_DIR="$HOME/.config/herdr/plugins/config/me.active-cwd" \
    /usr/bin/python3 "$HOME/.config/herdr/active_cwd_on_event.py" \
    </dev/null >/dev/null 2>&1 &!
}
add-zsh-hook chpwd herdr_active_cwd_refresh

# Fresh shells never fire chpwd (initial PWD isn't a change), so a new
# split/pane otherwise stays stale until its first cd or refocus. Nudge the
# handler exactly once, at the first prompt, when the shell's real cwd is
# settled.
typeset -g _HERDR_CWD_REPORTED=0
_herdr_active_cwd_first_prompt() {
  (( _HERDR_CWD_REPORTED )) && return 0
  _HERDR_CWD_REPORTED=1
  herdr_active_cwd_refresh
}
add-zsh-hook precmd _herdr_active_cwd_first_prompt

export STARSHIP_GITHUB_PR_SESSION_CACHE="${TMPDIR:-/tmp}/starship-github-pr-${USER:-user}-$$"
: >| "$STARSHIP_GITHUB_PR_SESSION_CACHE"

refresh_starship_github_pr_cache() {
  command -v starship-github-pr-refresh >/dev/null 2>&1 || return
  starship-github-pr-refresh >/dev/null 2>&1 &!
}

reset_starship_github_pr_cache() {
  : >| "$STARSHIP_GITHUB_PR_SESSION_CACHE"
  refresh_starship_github_pr_cache
}

cleanup_starship_github_pr_cache() {
  rm -f "$STARSHIP_GITHUB_PR_SESSION_CACHE"
}

add-zsh-hook precmd refresh_starship_github_pr_cache
add-zsh-hook chpwd reset_starship_github_pr_cache
add-zsh-hook zshexit cleanup_starship_github_pr_cache
refresh_starship_github_pr_cache
