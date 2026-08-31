#!/bin/bash

# 'me remove': the inverse of 'me add'. Takes manifest unit names or file
# paths, deletes the matching symlinks/copies rows and their copied sources
# from the repo, and retires the deployed destinations. Empty manifests and
# unit directories are pruned. Managed (<base>.d) files are out of scope.

# Plan state: one entry per manifest row slated for removal.
declare -a remove_unit=() remove_section=() remove_src=() remove_dest=()
declare -a remove_seen=() remove_action=() touched_units=()
declare remove_stash=""
remove_mode="prompt"

# Fill 'touched_units' with the distinct unit dirs appearing in the plan.
function remove_touched_units {
	local i unit
	touched_units=()
	for (( i=0; i<${#remove_unit[@]}; i++ )); do
		unit="${remove_unit[i]}"
		local known=0 existing
		for existing in ${touched_units[@]+"${touched_units[@]}"}; do
			[[ "$existing" == "$unit" ]] && { known=1; break; }
		done
		(( known )) || touched_units+=("$unit")
	done
}

function remove_tty_available {
	2>/dev/null :</dev/tty
}

# Append one manifest row to the removal plan unless it is already there.
function remove_plan_row {
	local unit="$1" section="$2" src="$3" dest="$4" key existing
	key="$unit"$'\t'"$section"$'\t'"$src"$'\t'"$dest"
	for existing in ${remove_seen[@]+"${remove_seen[@]}"}; do
		if [[ "$existing" == "$key" ]]; then
			return 0
		fi
	done
	remove_seen+=("$key")
	remove_unit+=("$unit")
	remove_section+=("$section")
	remove_src+=("$src")
	remove_dest+=("$dest")
}

# Add every manifest row owned by UNIT_DIR (repo-relative) to the plan.
function remove_plan_unit {
	local unit="$1" operation src dest
	for operation in symlinks copies; do
		while IFS=$'\t' read -r src dest; do
			remove_plan_row "$unit" "$operation" "$src" "$dest"
		done < <(manifest_rows "$unit/config.yml" "$operation")
	done
}

# Resolve a bare-word argument as a manifest unit name across both scopes.
# Legacy configure-script units are rejected loudly rather than silently skipped.
function remove_resolve_name {
	local name="$1" scope
	for scope in "$APPS_SCOPE" "$MACOS_SCOPE"; do
		collect_matches "$scope" "$name"
		if (( ${#matches[@]} > 0 )); then
			if [[ "${matches[0]}" != *config.yml ]]; then
				error "Unit '$name' is a legacy configure-script unit; 'me remove' only handles config.yml units"
				exit 1
			fi
			remove_plan_unit "$(dirname "${matches[0]}")"
			return
		fi
	done
	error "No config named '$name'. 'me remove' accepts manifest unit names or file paths. Available:"
	list_names "$APPS_SCOPE" | sed 's/^/  app: /' >&2
	list_names "$MACOS_SCOPE" | sed 's/^/  macos: /' >&2
	exit 1
}

# Expand the accepted destination spellings (~/, $HOME/) into a live path.
function remove_normalize_live_path {
	local arg="$1"
	arg="${arg/#\~/$HOME}"
	# shellcheck disable=SC2016 # The literal '$HOME' prefix is the registry grammar.
	if [[ "${arg:0:6}" == '$HOME/'* ]]; then
		arg="${arg/#\$HOME/$HOME}"
	fi
	printf '%s' "$arg"
}

# Resolve an argument containing '/': match rows whose deployed destination
# equals the argument, or whose repository source equals it (by repo-relative
# or canonical path). Errors when nothing claims such a file.
function remove_resolve_path {
	local arg="$1" scope unit src dest expanded resolved matched=0
	local live_arg
	live_arg="$(remove_normalize_live_path "$arg")"
	local resolved_arg
	resolved_arg="$(realpath -q "$live_arg")" || resolved_arg=""

	for scope in "$APPS_SCOPE" "$MACOS_SCOPE"; do
		while IFS= read -r unit; do
			is_manifest_unit "$unit" || continue
			unit="$(dirname "$unit")"
			for operation in symlinks copies; do
				while IFS=$'\t' read -r src dest; do
					expanded="$(expand_dest "$dest")"
					if [[ "$expanded" == "$live_arg" ]]; then
						remove_plan_row "$unit" "$operation" "$src" "$dest"
						matched=1
						continue
					fi
					[[ -n "$resolved_arg" ]] || continue
					if [[ "$unit/$src" == "$arg" ]]; then
						remove_plan_row "$unit" "$operation" "$src" "$dest"
						matched=1
						continue
					fi
					resolved="$(realpath -q "$unit/$src")" || continue
					if [[ "$resolved" == "$resolved_arg" ]]; then
						remove_plan_row "$unit" "$operation" "$src" "$dest"
						matched=1
					fi
				done < <(manifest_rows "$unit/config.yml" "$operation")
			done
		done < <(list_config_units "$scope")
	done

	if (( matched == 0 )); then
		error "No manifest row claims '$arg'; try a deployed path ($HOME/...), a repo path (configs/...), or a unit name"
		exit 1
	fi
}

# True when the live file's content differs from its repo source. cmp follows
# symlinks, so one comparison covers both kinds; a missing or dangling
# destination counts as dirty so it is never silently discarded.
function remove_live_is_dirty {
	local index="$1" live repo_file
	live="$(expand_dest "${remove_dest[index]}")"
	repo_file="${remove_unit[index]}/${remove_src[index]}"
	[[ -e "$live" || -L "$live" ]] || return 0
	! cmp -s "$repo_file" "$live"
}

# Read one answer from the terminal into REMOVE_ANSWER. Returns 1 when
# there is no usable tty, so destructive defaults are never applied blindly.
function remove_ask {
	local input
	remove_tty_available || return 1
	if ! read -r -p "$1" input </dev/tty; then
		return 1
	fi
	REMOVE_ANSWER="${input:-$2}"
}

# Decide how each row's deployed file retires and stash content for unlinks
# before anything mutates. Symlinks: delete vs unlink (keep content as a plain
# file). Copies: the live copy already stands alone, so the choice is delete
# vs leave it behind.
function remove_decide_actions {
	local i live dirty stash_target decision
	remove_action=()
	remove_stash="$(mktemp -d "${TMPDIR:-/tmp}/me-remove.XXXXXX")"
	for (( i=0; i<${#remove_unit[@]}; i++ )); do
		live="$(expand_dest "${remove_dest[i]}")"
		dirty=""
		if remove_live_is_dirty "$i"; then
			dirty=" [has local changes]"
		fi
		if [[ ! -e "$live" && ! -L "$live" ]]; then
			remove_action+=("absent")
			continue
		fi
		if [[ "${remove_section[i]}" == symlinks ]]; then
			case "$remove_mode" in
				delete) decision="delete" ;;
				unlink) decision="unlink" ;;
				*)
					if ! remove_ask "Retire $live$dirty ([D]elete or [u]nlink, keeping content as a plain file): " D; then
						error "Cannot ask how to retire $live; pass --delete or --unlink" >&2
						exit 1
					fi
					case "$REMOVE_ANSWER" in
						D|d|delete) decision="delete" ;;
						U|u|unlink) decision="unlink" ;;
						*) error "Unrecognized answer '$REMOVE_ANSWER'"; exit 1 ;;
					esac
					;;
			esac
			if [[ "$decision" == unlink ]]; then
				stash_target="$remove_stash/unlink-$i"
				if ! cp -p "$live" "$stash_target"; then
					error "Could not capture content of $live; it may be dangling. Use --delete instead"
					exit 1
				fi
				chmod u+rw "$stash_target" 2>/dev/null || true
			fi
		else
			decision="keep"
			if [[ "$remove_mode" == delete ]]; then
				decision="delete"
			elif remove_ask "Also delete the live copy at $live?$dirty [y/N]: " n; then
				case "$REMOVE_ANSWER" in
					Y|y|yes) decision="delete" ;;
				esac
			fi
			if [[ "$decision" == keep ]]; then
				message "Keeping the live copy at $live in place"
			fi
		fi
		remove_action+=("$decision")
	done
}

# Delete every planned row from its manifest, dropping sections left empty.
function remove_edit_manifests {
	local i manifest section src dest
	for (( i=0; i<${#remove_unit[@]}; i++ )); do
		manifest="${remove_unit[i]}/config.yml"
		section="${remove_section[i]}"
		src="${remove_src[i]}"
		dest="${remove_dest[i]}"
		# A row may fan one src out to several destinations, so drop just the
		# planned destination, then the row itself once nothing is left. A list
		# that ends up with one destination collapses back to a plain string.
		SRC="$src" DEST="$dest" yq -i "
			(.${section}[] | select(.src == strenv(SRC) and (.dest | type) == \"!!seq\")).dest |= map(select(. != strenv(DEST)))
			| del(.${section}[] | select(.src == strenv(SRC) and ((.dest == strenv(DEST)) or ((.dest | type) == \"!!seq\" and (.dest | length) == 0))))
			| (.${section}[] | select(.src == strenv(SRC) and (.dest | type) == \"!!seq\" and (.dest | length) == 1)).dest |= .[0]
		" "$manifest" \
			|| { error "Could not update $manifest"; exit 1; }
	done
remove_touched_units
	local manifest
	for manifest in "${touched_units[@]/%//config.yml}"; do
		if [[ "$(yq '.symlinks' "$manifest")" != "null" ]] && [[ "$(yq -r '.symlinks // [] | length' "$manifest")" == 0 ]]; then
			yq -i 'del(.symlinks)' "$manifest"
		fi
		if [[ "$(yq '.copies' "$manifest")" != "null" ]] && [[ "$(yq -r '.copies // [] | length' "$manifest")" == 0 ]]; then
			yq -i 'del(.copies)' "$manifest"
		fi
		message "Updated $(manifest_relative "$manifest")"
	done
}

# Delete repo source files that no remaining row or managed overlay references.
function remove_delete_sources {
	local -a handled=()
	local i src key existing operation row_src
	for (( i=0; i<${#remove_unit[@]}; i++ )); do
		src="${remove_unit[i]}/${remove_src[i]}"
		key="${remove_unit[i]}"$'\t'"${remove_src[i]}"
		for existing in ${handled[@]+"${handled[@]}"}; do
			[[ "$existing" == "$key" ]] && continue 2
		done
		handled+=("$key")
		# Keep the source when another row still deploys it or a managed
		# overlay composes it.
		local still_used=0
		for operation in symlinks copies; do
			while IFS=$'\t' read -r row_src _; do
				if [[ "$row_src" == "${remove_src[i]}" ]]; then
					still_used=1
				fi
			done < <(manifest_rows "${remove_unit[i]}/config.yml" "$operation")
		done
		if [[ -d "${src}.d" ]]; then
			still_used=1
		fi
		if (( still_used )); then
			continue
		fi
		rm "$src"
		message "Removed $(manifest_relative "$src") from the repo"
	done
}

# Remove config.yml and the unit directory once a unit owns nothing at all.
function remove_prune_units {
	local unit leftovers
	remove_touched_units
	while IFS= read -r unit; do
		[[ -f "$unit/config.yml" ]] || continue
		if [[ -n "$(find "$unit" -type d -name '*.d' -print -quit)" ]]; then
			continue
		fi
		if [[ -e "$unit/post.sh" || -L "$unit/post.sh" ]]; then
			continue
		fi
		leftovers="$(find "$unit" -mindepth 1 ! -name config.yml -print -quit)"
		if [[ -n "$leftovers" ]]; then
			continue
		fi
		rm "$unit/config.yml"
		rmdir "$unit"
		message "Removed empty unit $(manifest_relative "$unit")"
	done < <(printf '%s\n' "${touched_units[@]}")
}

function run_remove {
	local arg i unit live failed_validation=0
	local -a targets=()
	while (( $# > 0 )); do
		case "$1" in
			--delete)
				[[ "$remove_mode" == prompt || "$remove_mode" == delete ]] || { error "--delete and --unlink are mutually exclusive"; exit 1; }
				remove_mode="delete"
				shift
				;;
			--unlink)
				[[ "$remove_mode" == prompt || "$remove_mode" == unlink ]] || { error "--delete and --unlink are mutually exclusive"; exit 1; }
				remove_mode="unlink"
				shift
				;;
			--)
				shift
				targets+=("$@")
				set --
				;;
			-*)
				error "Unknown flag: $1"
				exit 1
				;;
			*)
				targets+=("$1")
				shift
				;;
		esac
	done
	if (( ${#targets[@]} == 0 )); then
		error "Usage: me remove [--delete|--unlink] <unit|file>..."
		exit 1
	fi

	if ! require_yq; then
		exit 1
	fi

	# Resolve everything before mutating so unknown arguments abort cleanly.
	for arg in "${targets[@]}"; do
		if [[ "$arg" == */* ]]; then
			remove_resolve_path "$arg"
		else
			remove_resolve_name "$arg"
		fi
	done
	if (( ${#remove_unit[@]} == 0 )); then
		message "Nothing to remove."
		return
	fi

	remove_decide_actions

	# Mutate repo first (recoverable via git), then retire live files.
	remove_edit_manifests
	remove_touched_units
	for unit in "${touched_units[@]}"; do
		if ! validate_manifest_unit "$unit" yes no; then
			failed_validation=1
		fi
	done
	if (( failed_validation )); then
		error "Updated manifests failed validation; live files were not touched"
		rm -rf "$remove_stash"
		exit 1
	fi

	remove_delete_sources

	# Retire deployed files.
	for (( i=0; i<${#remove_unit[@]}; i++ )); do
		live="$(expand_dest "${remove_dest[i]}")"
		case "${remove_action[i]}" in
			delete)
				rm -f "$live"
				message "Deleted $live"
				;;
			unlink)
				mv "$remove_stash/unlink-$i" "$live"
				message "Unlinked $live; kept its content as a plain file"
				;;
		esac
	done
	rm -rf "$remove_stash"

	remove_prune_units
	message "Removed ${#remove_unit[@]} file(s); re-run 'me status' to confirm."
}
