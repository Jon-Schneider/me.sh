# git-prompt-async.zsh — computes the prompt's git branch/status off the critical path
#
# precmd starts `git status` in the background and the prompt draws immediately with the
# last known values; when git finishes, the result is exported as STARSHIP_GIT_* (rendered
# by [env_var.STARSHIP_GIT_*] in starship.toml) and the prompt redraws.
#
# Sourced from ~/.zshrc after `starship init`.

typeset -g _GIT_PROMPT_FD=''

_git_prompt_clear() {
  unset STARSHIP_GIT_BRANCH STARSHIP_GIT_STAGED STARSHIP_GIT_MODIFIED STARSHIP_GIT_UNTRACKED STARSHIP_GIT_DELETED
}

# Prints "<branch>\t<staged>\t<modified>\t<untracked>\t<deleted>", or nothing outside a repo.
# Counting matches Starship's git_status. --no-optional-locks keeps it from contending for
# index.lock with git commands run concurrently in the same repo.
_git_prompt_worker() {
  emulate -L zsh
  local line branch='' x y
  local -i staged=0 modified=0 untracked=0 deleted=0
  command git --no-optional-locks status --porcelain=2 --branch 2>/dev/null | while IFS= read -r line; do
    case $line in
      '# branch.head '*)
        branch=${line#\# branch.head }
        [[ $branch == '(detached)' ]] && branch=HEAD ;;
      [12]' '*)
        x=${line[3]} y=${line[4]}
        [[ $x != . ]] && (( staged++ ))
        [[ $y == [MT] ]] && (( modified++ ))
        [[ $x == D || $y == D ]] && (( deleted++ )) ;;
      '? '*)
        (( untracked++ )) ;;
    esac
  done
  [[ -n $branch ]] && print -r -- "$branch"$'\t'$staged$'\t'$modified$'\t'$untracked$'\t'$deleted
}

_git_prompt_export() {
  local name=$1 value=$2
  if [[ -n $value && $value != 0 ]]; then
    export "$name=$value"
  else
    unset "$name"
  fi
}

_git_prompt_apply() {
  local -a fields=("${(@ps:\t:)1}")
  _git_prompt_export STARSHIP_GIT_BRANCH "${fields[1]}"
  _git_prompt_export STARSHIP_GIT_STAGED "${fields[2]}"
  _git_prompt_export STARSHIP_GIT_MODIFIED "${fields[3]}"
  _git_prompt_export STARSHIP_GIT_UNTRACKED "${fields[4]}"
  _git_prompt_export STARSHIP_GIT_DELETED "${fields[5]}"
}

_git_prompt_stop() {
  [[ -n $_GIT_PROMPT_FD ]] || return 0
  zle -F $_GIT_PROMPT_FD 2>/dev/null
  exec {_GIT_PROMPT_FD}<&-
  _GIT_PROMPT_FD=''
}

_git_prompt_ready() {
  local result=''
  IFS= read -r result <&$1
  _git_prompt_stop
  _git_prompt_apply "$result"
  zle reset-prompt
}
zle -N _git_prompt_ready

_git_prompt_start() {
  _git_prompt_stop
  exec {_GIT_PROMPT_FD}< <(_git_prompt_worker)
  zle -F -w $_GIT_PROMPT_FD _git_prompt_ready
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _git_prompt_start
# Clear on cd so a new directory never shows the previous repo's branch while git runs.
add-zsh-hook chpwd _git_prompt_clear

# Panes inherit the environment of whatever shell launched herdr, which may carry stale values.
_git_prompt_clear
