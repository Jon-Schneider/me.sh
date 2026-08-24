#!/bin/bash

# 'me add': adopt an existing file into a config unit. Copies the file into the
# unit directory, adds a symlink or copy row to its config.yml (creating the
# unit if needed), then deploys the unit immediately. Anything not passed as a
# flag is prompted for interactively.

function add_tty_available {
	2>/dev/null :</dev/tty
	return $?
}

# Fail when a required answer cannot be prompted for.
function add_need_tty {
	if ! add_tty_available; then
		error "This information is required interactively; pass it via flags instead (--link/--app/--dest)" >&2
		exit 1
	fi
}

# Print one line read from the terminal.
function add_prompt {
	local prompt="$1" answer
	add_need_tty
	if ! read -r -p "$prompt" answer </dev/tty; then
		error "Could not read an answer from the terminal" >&2
		exit 1
	fi
	printf '%s' "$answer"
}

# Prompt, falling back to DEFAULT on an empty answer.
function add_prompt_with_default {
	local prompt="$1" default="$2" answer
	answer="$(add_prompt "$prompt")"
	if [[ -n "$answer" ]]; then
		printf '%s' "$answer"
	else
		printf '%s' "$default"
	fi
}

# Rewrite ~/ and absolute-under-$HOME spellings into the literal '$HOME/'
# grammar every destination uses.
function add_normalize_dest {
	local dest="$1"
	# shellcheck disable=SC2088 # Matching the literal two-character prefix, not expanding it.
	if [[ "${dest:0:2}" == "~/" ]]; then
		dest="\$HOME/${dest#~/}"
	elif [[ "$dest" == "$HOME"/* ]]; then
		dest="\$HOME/${dest#"$HOME"/}"
	fi
	printf '%s' "$dest"
}

# Canonicalize the accepted link-type spellings to a manifest section name.
function add_parse_link_type {
	case "$1" in
		s|symlink|symlinks) printf 'symlinks' ;;
		c|copy|copies) printf 'copies' ;;
		*) return 1 ;;
	esac
}

# Canonicalize the accepted scope spellings.
function add_parse_scope {
	case "$1" in
		a|app|apps) printf 'apps' ;;
		m|mac|macos|sys|system) printf 'macos' ;;
		*) return 1 ;;
	esac
}

# Reject legacy configure-script units loudly even though callers capture our
# stdout.
function add_reject_legacy {
	error "Unit '$1' is a legacy configure-script unit; convert it to config.yml before adding files" >&2
	exit 1
}

# Find the manifest-unit directory for NAME across both scopes, printing the
# repo-relative unit directory. Prints nothing when no unit exists.
function add_find_unit_dir {
	local name="$1" scope
	for scope in "$APPS_SCOPE" "$MACOS_SCOPE"; do
		collect_matches "$scope" "$name"
		if (( ${#matches[@]} > 0 )); then
			if [[ "${matches[0]}" != *config.yml ]]; then
				add_reject_legacy "$name"
			fi
			printf '%s' "$(dirname "${matches[0]}")"
			return 0
		fi
	done
	return 0
}

# True when EXPANDED_DEST is already claimed by UNIT's manifest rows or managed
# markers, so adding another row would make the unit invalid.
function add_dest_claimed_in_unit {
	local unit="$1" dest="$2" operation src row_dest marker marker_dest
	for operation in symlinks copies; do
		while IFS=$'\t' read -r src row_dest; do
			if [[ "$(expand_dest "$row_dest")" == "$dest" ]]; then
				return 0
			fi
		done < <(manifest_rows "$unit/config.yml" "$operation")
	done
	while IFS= read -r -d '' marker; do
		IFS= read -r marker_dest < "$marker"
		if [[ "$(expand_dest "$marker_dest")" == "$dest" ]]; then
			return 0
		fi
	done < <(find "$unit" -type f -path '*.d/dest' -print0)
	return 1
}

function run_add {
	local src="" link_type_raw="" app_name="" dest_raw="" scope_raw=""
	local args=()

	while (( $# > 0 )); do
		case "$1" in
			--link|--app|--dest|--scope)
				(( $# >= 2 )) || { error "$1 requires a value"; exit 1; }
				args+=("$1" "$2")
				shift 2
				;;
			--)
				shift
				break
				;;
			-*)
				error "Unknown flag: $1"
				exit 1
				;;
			*)
				[[ -z "$src" ]] || { error "'me add' takes exactly one file"; exit 1; }
				src="$1"
				shift
				;;
		esac
	done
	(( $# == 0 )) || { error "'me add' takes exactly one file"; exit 1; }

	set -- ${args[@]+"${args[@]}"}
	while (( $# > 0 )); do
		case "$1" in
			--link) link_type_raw="$2" ;;
			--app) app_name="$2" ;;
			--dest) dest_raw="$2" ;;
			--scope) scope_raw="$2" ;;
		esac
		shift 2
	done

	if ! require_yq; then
		exit 1
	fi

	# Source file.
	if [[ -z "$src" ]]; then
		src="$(add_prompt "File to add: ")"
	fi
	src="${src/#\~/$HOME}"
	local resolved
	if ! resolved="$(realpath -q "$src")" || [[ ! -f "$resolved" ]]; then
		error "Not a regular file: $src"
		exit 1
	fi
	local base="${resolved##*/}"

	# Link type.
	local link_type
	if [[ -n "$link_type_raw" ]]; then
		link_type="$(add_parse_link_type "$link_type_raw")" || { error "--link must be symlink or copy, got '$link_type_raw'"; exit 1; }
	else
		link_type="$(add_parse_link_type "$(add_prompt_with_default "Link type ([s]ymlink or [c]opy): " symlink)")"
	fi

	# Unit name: existing manifest unit to merge into, or a new one to create.
	local unit_dir="" new_unit=0
	if [[ -z "$app_name" ]]; then
		message "Existing units:"
		list_names "$APPS_SCOPE" | sed 's/^/  app: /'
		list_names "$MACOS_SCOPE" | sed 's/^/  macos: /'
		app_name="$(add_prompt "Target unit (a name above, or a new unit name): ")"
	fi
	[[ "$app_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { error "Invalid unit name: $app_name"; exit 1; }
	unit_dir="$(add_find_unit_dir "$app_name")"
	if [[ -z "$unit_dir" ]]; then
		local scope
		if [[ -n "$scope_raw" ]]; then
			scope="$(add_parse_scope "$scope_raw")" || { error "--scope must be apps or macos, got '$scope_raw'"; exit 1; }
		else
			scope="$(add_parse_scope "$(add_prompt_with_default "Scope for new unit '[a]pps or [m]acos': " apps)")"
		fi
		unit_dir="configs/$scope/$app_name"
		new_unit=1
	fi

	# Destination inside $HOME, following the shared dest grammar.
	local dest suggested
	if [[ -n "$dest_raw" ]]; then
		dest="$dest_raw"
	else
		if [[ "$resolved" == "$HOME"/* ]]; then
			suggested="\$HOME/${resolved#"$HOME"/}"
		else
			suggested="\$HOME/.config/$app_name/$base"
		fi
		dest="$(add_prompt_with_default "Deploy destination [$suggested]: " "$suggested")"
	fi
	dest="$(add_normalize_dest "$dest")"
	validate_home_dest "$dest" "me add ($base)" || exit 1
	local expanded_dest
	expanded_dest="$(expand_dest "$dest")"

	# Copy the file into the unit directory.
	local repo_file="$unit_dir/$base"
	if [[ -e "$repo_file" ]]; then
		if ! cmp -s "$repo_file" "$resolved"; then
			error "$(manifest_relative "$repo_file") already exists with different content; rename or merge manually"
			exit 1
		fi
		message "Reusing identical $(manifest_relative "$repo_file")"
	else
		mkdir -p "$unit_dir"
		if ! cp -p "$resolved" "$repo_file"; then
			error "Could not copy $src into $repo_file"
			exit 1
		fi
	fi

	# Wire the row into config.yml, creating the manifest for a new unit. Check
	# claims first so a rejected adoption never leaves a half-updated manifest.
	local manifest="$unit_dir/config.yml"
	if [[ "$new_unit" == 1 || ! -f "$manifest" ]]; then
		printf '%s:\n  - src: %s\n    dest: %s\n' "$link_type" "$base" "$dest" > "$manifest"
		message "Created $(manifest_relative "$manifest")"
	elif [[ "$(SRC="$base" DEST="$dest" yq -r ".${link_type} // [] | map(select(.src == strenv(SRC) and .dest == strenv(DEST))) | length" "$manifest")" != 0 ]]; then
		message "$(manifest_relative "$manifest") already maps $base -> $dest; nothing to change"
	elif add_dest_claimed_in_unit "$unit_dir" "$expanded_dest"; then
		error "$(manifest_relative "$unit_dir") already claims $dest; remove that row first" >&2
		exit 1
	elif SRC="$base" DEST="$dest" yq -i ".${link_type} += [{\"src\": strenv(SRC), \"dest\": strenv(DEST)}]" "$manifest"; then
		message "Updated $(manifest_relative "$manifest")"
	else
		error "Could not update $manifest"
		exit 1
	fi

	# Validate schema/sources/destinations (but not live destinations) before
	# touching anything live. Deploying a symlink over a real file requires the
	# original to be gone first, so the retirement below happens between this
	# check and the deploy; if the deploy itself fails afterward, the content
	# survives in the repository copy.
	selected=()
	add_selected "$manifest"
	if ! validate_manifest_unit "$unit_dir" yes no; then
		error "The updated unit failed validation; nothing was deployed"
		exit 1
	fi
	if [[ "$link_type" == symlinks && -f "$expanded_dest" && ! -L "$expanded_dest" ]]; then
		if cmp -s "$repo_file" "$expanded_dest"; then
			rm "$expanded_dest" || { error "Could not remove $expanded_dest for relinking"; exit 1; }
		else
			error "Destination exists with different content: $expanded_dest; move it aside first"
			exit 1
		fi
	fi

	message "Adopted $src as $(manifest_relative "$repo_file") -> $dest"
	run_selected
}
