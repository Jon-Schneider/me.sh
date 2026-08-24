#!/bin/bash

# Managed config deployment: a file is MANAGED iff its sibling '<file>.d/'
# directory contains a 'dest' marker naming where it deploys. Managed files are
# materialized copies composed from the repo base plus machine-local overlay
# fragments, instead of symlinked. App-written runtime state lands in the
# deployed copy and never reaches the repo; 'me up' reviews it for keepers.

COMPOSE_REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
source "${COMPOSE_REPO_ROOT}/lib/common.sh"
DEEP_MERGE="$COMPOSE_REPO_ROOT/lib/deep_merge.py"

# Expand a registry destination. Only a literal '$HOME/' prefix is expanded;
# nothing else in the registry is evaluated.
function expand_dest {
	local dest="$1" prefix='$HOME/'
	if [[ "$dest" == "$prefix"* ]]; then
		printf '%s/%s' "$HOME" "${dest:${#prefix}}"
	else
		printf '%s' "$dest"
	fi
}

# Print 'src<TAB>deployed-dest' pairs for every managed file under DIR (an
# absolute repo path or repo-relative). A file is managed iff its '<file>.d/'
# directory exists and contains a 'dest' marker whose single line names the
# destination (literal '$HOME/' prefix is expanded).
function managed_files_under {
	local dir="${1%/}" d src dest marker
	[[ "$dir" == "$COMPOSE_REPO_ROOT"/* ]] && dir="${dir#"$COMPOSE_REPO_ROOT"/}"
	while IFS= read -r -d '' d; do
		src="${d%.d}"
		marker="$d/dest"
		if [[ ! -f "$src" ]]; then
			error "Fragment directory without base file: ${d#$COMPOSE_REPO_ROOT/}"
			continue
		fi
		if [[ ! -f "$marker" ]]; then
			error "Fragment directory missing its 'dest' marker: ${d#$COMPOSE_REPO_ROOT/}"
			continue
		fi
		IFS= read -r dest < "$marker"
		printf '%s\t%s\n' "${src#$COMPOSE_REPO_ROOT/}" "$(expand_dest "$dest")"
	done < <(cd "$COMPOSE_REPO_ROOT" && find "$dir" -type d -name '*.d' -print0 | LC_ALL=C sort -z)
}

# Print usable overlay fragments for FILE: .json/.yaml/.yml/.toml merge plus
# executables (transformers), sorted so numeric prefixes control order.
# Dotfiles are skipped silently.
function overlay_fragments {
	local overlay_dir="$1" frag
	[[ -d "$overlay_dir" ]] || return 0
	while IFS= read -r frag; do
		frag="$overlay_dir/$frag"
		case "$frag" in
			*.json|*.yaml|*.yml|*.toml) printf '%s\n' "$frag" ;;
			.*) ;;
			*) [[ -x "$frag" ]] && printf '%s\n' "$frag" ;;
		esac
	done < <(ls "$overlay_dir" | LC_ALL=C sort)
}

# Merge a fragment into the document in TARGET (in place). Each side is parsed
# by its own suffix; TARGET_FORMAT is passed explicitly because deploy targets
# are often extensionless temp files.
function merge_fragment {
	local target="$1" fragment="$2" fmt="$3"
	"$DEEP_MERGE" "$target" "$fragment" "$fmt"
}

# Compose BASE plus its <BASE>.d/ fragments into OUT. Exit status: 0 composed,
# 2 no usable fragments (caller may fall back to symlinking/copying), 1 hard
# failure (a fragment broke -- callers must NOT silently fall back).
# Executable fragments act as transformers: content on stdin, rewritten content
# on stdout.
function compose_file {
	local base="$1" out="$2" fmt frag tmp
	fmt="${base##*.}"
	case "$fmt" in json|yaml|yml|toml) ;; *) fmt="json" ;; esac
	local -a fragments=()
	while IFS= read -r frag; do
		fragments+=("$frag")
	done < <(overlay_fragments "${base}.d")
	(( ${#fragments[@]} > 0 )) || return 2

	cp "$base" "$out"
	for frag in "${fragments[@]}"; do
		case "$frag" in
			*.json|*.yaml|*.yml|*.toml)
				merge_fragment "$out" "$frag" "$fmt" || {
					error "Fragment merge failed: $frag"
					return 1
				}
				;;
			*)
				tmp="$(mktemp "${TMPDIR:-/tmp}/me-compose.XXXXXX")"
				if ! "$frag" < "$out" > "$tmp"; then
					rm -f "$tmp"
					error "Fragment failed: $frag"
					return 1
				fi
				mv "$tmp" "$out"
				;;
		esac
	done
	return 0
}

# Deploy SRC to DEST: a composed materialized copy when SRC has overlay
# fragments, otherwise a symlink. Never writes through an existing symlink.
function deploy_config {
	local src="$1" dest="$2" tmp mode rc=0
	mkdir -p "$(dirname "$dest")"
	compose_file "$src" "$tmp" || rc=$?
	if (( rc == 0 )); then
		mode="$(stat -f '%Lp' "$src")"
		rm -f "$dest"
		mv "$tmp" "$dest"
		chmod "$mode" "$dest"
		message "Composed ${src#$COMPOSE_REPO_ROOT/} + overlays -> $dest"
	elif (( rc == 2 )); then
		ln -sfn "$src" "$dest"
		message "Linked ${src#$COMPOSE_REPO_ROOT/} -> $dest"
	else
		error "Compose failed for ${src#$COMPOSE_REPO_ROOT/}; leaving $dest untouched"
		return 1
	fi
}

# Deploy every managed file under DIR (see managed_files_under). Managed files
# are always materialized -- even without fragments yet -- so app-written
# runtime state lands in the deployed copy instead of the repo. A broken
# fragment aborts that file's deploy loudly instead of shipping an uncomposed base.
function deploy_managed_under {
	local src dest tmp rc mode failed=0
	while IFS=$'\t' read -r src dest; do
		message "Composing ${src#$COMPOSE_REPO_ROOT/} -> $dest"
		if ! mkdir -p "$(dirname "$dest")"; then
			error "Could not create destination parent for $dest"
			failed=1
			continue
		fi
		if ! tmp="$(mktemp "${TMPDIR:-/tmp}/me-deploy.XXXXXX")"; then
			error "Could not create a temporary file for $src"
			failed=1
			continue
		fi
		rc=0
		compose_file "$COMPOSE_REPO_ROOT/$src" "$tmp" || rc=$?
		if (( rc == 2 )); then
			if ! cp "$COMPOSE_REPO_ROOT/$src" "$tmp"; then
				error "Could not copy managed base $src"
				rm -f "$tmp"
				failed=1
				continue
			fi
		elif (( rc != 0 )); then
			error "Compose failed for $src; destination left untouched"
			rm -f "$tmp"
			failed=1
			continue
		fi
		if [[ -e "$dest" && -d "$dest" && ! -L "$dest" ]]; then
			error "Refusing to replace directory destination: $dest"
			rm -f "$tmp"
			failed=1
			continue
		fi
		mode="$(stat -f '%Lp' "$COMPOSE_REPO_ROOT/$src")"
		if ! chmod "$mode" "$tmp" || ! rm -f "$dest" || ! mv "$tmp" "$dest"; then
			error "Could not deploy $src to $dest"
			rm -f "$tmp"
			failed=1
			continue
		fi
	done < <(managed_files_under "$1")
	return "$failed"
}
