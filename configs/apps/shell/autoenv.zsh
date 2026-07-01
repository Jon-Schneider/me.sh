# autoenv.zsh — per-directory .env loader for zsh
#
# Sources ./.env as real shell (env vars, aliases, functions all work) when you
# cd into a directory, then on leaving removes exactly what it ADDED and restores
# what it CHANGED (including tied vars like PATH/MANPATH).
#
# Approval is content-hashed like `direnv allow`: a .env is sourced only after you
# approve it, and any edit to the file voids the approval and re-prompts.
#
# Sourced from ~/.zshrc. State lives in $AUTOENV_STATE_DIR (default ~/.config/autoenv).
# CLI: autoenv-allow [file]  pre-approve + load now;  autoenv-revoke [file]  forget it.

: ${AUTOENV_STATE_DIR:=${XDG_CONFIG_HOME:-$HOME/.config}/autoenv}
typeset -g  _AUTOENV_ALLOW="$AUTOENV_STATE_DIR/allowed"   # lines: <sha256>\t<abs-path>
typeset -g  _AUTOENV_DENY="$AUTOENV_STATE_DIR/denied"     # lines: <abs-path>
typeset -g  _AUTOENV_DIR=''
typeset -ga _AUTOENV_UNDO=()
typeset -ga AUTOENV_IGNORE_DIRS=("$HOME")   # dirs whose .env the auto-loader ignores

# ---- approval (content-hashed, like `direnv allow`) ----
_autoenv_hash() { print -r -- "${$(shasum -a 256 -- "$1" 2>/dev/null)%% *}"; }
_autoenv_ask()  { local a; read -k 1 a </dev/tty; print -r -- "$a"; }
_autoenv_approve() {
  emulate -L zsh
  local envpath=${1:A} sum ans tmp            # never name a local 'path' in zsh — it's tied to $PATH
  sum=$(_autoenv_hash "$1")
  mkdir -p -- "$AUTOENV_STATE_DIR"; touch -- "$_AUTOENV_ALLOW" "$_AUTOENV_DENY"
  command grep -Fxq -- "$envpath" "$_AUTOENV_DENY" && return 1
  command grep -Fxq -- "${sum}	${envpath}" "$_AUTOENV_ALLOW" && return 0
  print -n "autoenv: source '${envpath/#$HOME/~}'? ([y]es once / [a]lways / [N]o / n[e]ver) "
  ans=$(_autoenv_ask); print
  case $ans in
    [yY]) return 0 ;;
    [aA]) tmp=$(mktemp)
          command grep -Fv -- "	${envpath}" "$_AUTOENV_ALLOW" > "$tmp" 2>/dev/null
          print -r -- "${sum}	${envpath}" >> "$tmp"; mv -- "$tmp" "$_AUTOENV_ALLOW"; return 0 ;;
    [eE]) print -r -- "$envpath" >> "$_AUTOENV_DENY"; return 1 ;;
    *)    return 1 ;;
  esac
}

# ---- load / unload (snapshot-diff; restores overwritten values incl. PATH/MANPATH) ----
_autoenv_is_env_var() {
  local t=${parameters[$1]}
  [[ $t == *scalar* && $t == *export* && $t != *readonly* && ( $t != *special* || $t == *tied* ) ]]
}
_autoenv_load() {
  emulate -L zsh
  setopt localoptions allexport no_aliases
  local -A pre_var pre_alias pre_func
  local n
  for n in ${(k)parameters}; do _autoenv_is_env_var $n && pre_var[$n]=${(P)n}; done
  for n in ${(k)aliases};   do pre_alias[$n]=${aliases[$n]}; done
  for n in ${(k)functions}; do pre_func[$n]=1; done
  source ./.env
  _AUTOENV_UNDO=()
  for n in ${(k)parameters}; do
    _autoenv_is_env_var $n || continue
    if (( ! ${+pre_var[$n]} )); then _AUTOENV_UNDO+=("unset ${(q)n}")
    elif [[ ${(P)n} != ${pre_var[$n]} ]]; then _AUTOENV_UNDO+=("export ${(q)n}=${(qq)pre_var[$n]}"); fi
  done
  for n in ${(k)aliases}; do
    if (( ! ${+pre_alias[$n]} )); then _AUTOENV_UNDO+=("unalias -- ${(q)n}")
    elif [[ ${aliases[$n]} != ${pre_alias[$n]} ]]; then _AUTOENV_UNDO+=("alias -- ${(q)n}=${(qq)pre_alias[$n]}"); fi
  done
  for n in ${(k)functions}; do (( ${+pre_func[$n]} )) || _AUTOENV_UNDO+=("unfunction -- ${(q)n}"); done
}
_autoenv_unload() {
  emulate -L zsh
  local stmt; for stmt in ${(Oa)_AUTOENV_UNDO}; do eval "$stmt"; done
  _AUTOENV_UNDO=(); _AUTOENV_DIR=''
}

# ---- hook ----
_autoenv_hook() {
  emulate -L zsh
  [[ $PWD == $_AUTOENV_DIR ]] && return
  [[ -n $_AUTOENV_DIR ]] && _autoenv_unload
  (( ${AUTOENV_IGNORE_DIRS[(I)$PWD]} )) && return     # leave ignored dirs (e.g. $HOME) alone
  if [[ -f ./.env ]] && _autoenv_approve ./.env; then
    _autoenv_load; _AUTOENV_DIR=$PWD
  fi
}
autoload -U add-zsh-hook
add-zsh-hook chpwd _autoenv_hook
_autoenv_hook

# ---- CLI: pre-approve / revoke without the cd prompt ----
autoenv-allow() {
  emulate -L zsh
  local f=${1:-./.env} envpath tmp
  [[ -f $f ]] || { print "autoenv: no such file: $f" >&2; return 1; }
  envpath=${f:A}; mkdir -p -- "$AUTOENV_STATE_DIR"; touch -- "$_AUTOENV_ALLOW" "$_AUTOENV_DENY"
  tmp=$(mktemp); command grep -Fv  -- "	${envpath}" "$_AUTOENV_ALLOW" >"$tmp" 2>/dev/null
  print -r -- "$(_autoenv_hash "$f")	${envpath}" >>"$tmp"; mv -- "$tmp" "$_AUTOENV_ALLOW"
  tmp=$(mktemp); command grep -Fxv -- "$envpath" "$_AUTOENV_DENY" >"$tmp" 2>/dev/null; mv -- "$tmp" "$_AUTOENV_DENY"
  [[ ${envpath:h} == $PWD ]] && { _AUTOENV_DIR=''; _autoenv_hook }
}
autoenv-revoke() {
  emulate -L zsh
  local envpath=${1:-./.env}:A list tmp
  for list in "$_AUTOENV_ALLOW" "$_AUTOENV_DENY"; do
    [[ -f $list ]] || continue
    tmp=$(mktemp); command grep -Fv -- "$envpath" "$list" >"$tmp" 2>/dev/null; mv -- "$tmp" "$list"
  done
  print "autoenv: revoked ${envpath/#$HOME/~}"
}
