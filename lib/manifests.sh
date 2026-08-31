#!/bin/bash

# Declarative config-unit support. A manifest owns ordinary symlinks and static
# copies; managed files remain declared solely by sibling <base>.d/dest markers.

MANIFEST_REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

function require_yq {
	if command -v yq &>/dev/null; then
		return 0
	fi
	# A direct `me` invocation may not have Homebrew's bin directory yet even
	# though yq is installed there. Loading shellenv is read-only and does not
	# implicitly install or run another config unit.
	if load_homebrew &>/dev/null && command -v yq &>/dev/null; then
		return 0
	fi
	error "Manifest-backed configs require yq; run 'me homebrew', then retry"
	return 1
}

function manifest_relative {
	printf '%s' "${1#"$MANIFEST_REPO_ROOT"/}"
}

# Print src<TAB>literal-dest rows in manifest order. A row whose dest is a list
# fans out into one row per destination, so every caller keeps seeing flat
# single-destination rows. Callers must validate the manifest first, so TSV is
# safe: tabs and newlines are rejected by validation.
function manifest_rows {
	# yq emits one newline even when an optional list has no rows.
	yq -r "(.${2} // [])[] | .src as \$src | ([.dest] | flatten(1) | .[]) | [\$src, .] | @tsv" "$1" | sed '/^$/d'
}

function manifest_symlink_rows {
	manifest_rows "$1" symlinks
}

function manifest_copy_rows {
	manifest_rows "$1" copies
}

# Print canonical repo-source<TAB>expanded-destination rows for drift review.
# The manifest must already have passed validate_manifest_unit.
function manifest_copy_files_under {
	local unit="${1%/}" src dest resolved
	while IFS=$'\t' read -r src dest; do
		resolved="$(realpath -q "$unit/$src")" || return 1
		printf '%s\t%s\n' "$(manifest_relative "$resolved")" "$(expand_dest "$dest")"
	done < <(manifest_copy_rows "$unit/config.yml")
}

function validate_home_dest {
	# shellcheck disable=SC2016 # The registry prefix must remain literal.
	local dest="$1" context="$2" suffix component failed=0 prefix='$HOME/'
	local -a dest_parts=()
	if [[ "$dest" != "$prefix"* ]]; then
		error "$context: destination must start with a literal \$HOME/"
		return 1
	fi
	suffix="${dest:${#prefix}}"
	if [[ -z "$suffix" || "$dest" == */ ]]; then
		error "$context: destination must name a file, without a trailing slash"
		failed=1
	fi
	if [[ "$suffix" == *$'\t'* || "$suffix" == *$'\n'* || "$suffix" == *'//'* ]]; then
		error "$context: destination contains an empty, tab, or newline path component"
		failed=1
	fi
	IFS='/' read -r -a dest_parts <<< "$suffix"
	if (( ${#dest_parts[@]} > 0 )); then
		for component in "${dest_parts[@]}"; do
			if [[ "$component" == . || "$component" == .. ]]; then
				error "$context: destination may not contain '.' or '..' components"
				failed=1
			fi
		done
	fi
	return "$failed"
}

function validate_manifest_schema {
	local manifest="$1"
	if ! yq -e '
		(type == "!!map") and
		((((keys - ["symlinks", "copies"]) | length) == 0)) and
		((((.symlinks // []) | type) == "!!seq")) and
		((((.copies // []) | type) == "!!seq")) and
		([(.symlinks // [])[], (.copies // [])[]] | all_c(
			(type == "!!map") and
			(((keys - ["src", "dest"]) | length) == 0) and
			((keys | length) == 2) and
			((.src | type) == "!!str") and
			(.src != "") and
			((.src | test("[\\t\\n]")) | not) and
			(((.dest | type) == "!!str") or (((.dest | type) == "!!seq") and ((.dest | length) > 0))) and
			([.dest] | flatten(1) | all_c(
				(type == "!!str") and (. != "") and ((test("[\\t\\n]")) | not)
			))
		))
	' "$manifest" &>/dev/null; then
		error "$(manifest_relative "$manifest"): expected only 'symlinks' and 'copies', containing string src rows whose dest is a string or a non-empty list of strings"
		return 1
	fi
}

# Validate one manifest unit completely before it mutates the machine.
function validate_manifest_unit {
	local unit manifest post
	unit="${1%/}"
	manifest="$unit/config.yml"
	post="$unit/post.sh"
	local validate_managed="${2:-yes}"
	local validate_live="${3:-yes}"
	local operation src dest resolved marker marker_dest claim normalized existing failed=0
	local -a destinations=()

	if ! require_yq; then
		return 1
	fi
	if find "$unit" -type f -name 'configure_*.sh' | grep -q .; then
		error "$(manifest_relative "$unit"): config.yml and configure_*.sh may not coexist"
		failed=1
	fi
	if [[ ( -e "$post" || -L "$post" ) && ( ! -f "$post" || ! -x "$post" ) ]]; then
		error "$(manifest_relative "$post"): post.sh must be a regular executable file"
		failed=1
	fi
	if ! validate_manifest_schema "$manifest"; then
		return 1
	fi

	for operation in symlinks copies; do
		while IFS=$'\t' read -r src dest; do
			resolved=""
			if [[ "$src" == /* ]]; then
				error "$(manifest_relative "$manifest"): src must be relative: $src"
				failed=1
			elif ! resolved="$(realpath -q "$unit/$src")"; then
				error "$(manifest_relative "$manifest"): source does not exist: $src"
				failed=1
			elif [[ "$resolved" != "$MANIFEST_REPO_ROOT" && "$resolved" != "$MANIFEST_REPO_ROOT/"* ]]; then
				error "$(manifest_relative "$manifest"): source escapes the repository: $src"
				failed=1
			elif [[ "$operation" == copies && ! -f "$resolved" ]]; then
				error "$(manifest_relative "$manifest"): copy source must be a regular file: $src"
				failed=1
			fi
			if validate_home_dest "$dest" "$(manifest_relative "$manifest") ($src)"; then
				normalized="$(expand_dest "$dest")"
				if force_enabled; then
					: # A conflicting destination is moved aside at deploy time.
				elif [[ "$validate_live" == yes && "$operation" == symlinks && -e "$normalized" && ! -L "$normalized" ]]; then
					error "$(manifest_relative "$manifest"): refusing non-symlink destination: $dest (--force moves it aside)"
					failed=1
				elif [[ "$validate_live" == yes && "$operation" == copies && ( -e "$normalized" || -L "$normalized" ) && ! -f "$normalized" && ! -L "$normalized" ]]; then
					error "$(manifest_relative "$manifest"): refusing non-file copy destination: $dest (--force moves it aside)"
					failed=1
				fi
				if (( ${#destinations[@]} > 0 )); then
					for existing in "${destinations[@]}"; do
						if [[ "$existing" == "$normalized" ]]; then
							error "$(manifest_relative "$manifest"): destination is claimed more than once: $dest"
							failed=1
						fi
					done
				fi
				destinations+=("$normalized")
			else
				failed=1
			fi
		done < <(manifest_rows "$manifest" "$operation")
	done

	if [[ "$validate_managed" == yes ]]; then
		while IFS= read -r -d '' marker; do
			if validate_managed_marker "$marker"; then
				IFS= read -r marker_dest < "$marker"
				normalized="$(expand_dest "$marker_dest")"
				if (( ${#destinations[@]} > 0 )); then
					for existing in "${destinations[@]}"; do
						if [[ "$existing" == "$normalized" ]]; then
							error "$(manifest_relative "$unit"): manifest row and managed file both claim $marker_dest"
							failed=1
						fi
					done
				fi
				destinations+=("$normalized")
			else
				failed=1
			fi
		done < <(find "$unit" -type f -path '*.d/dest' -print0 | LC_ALL=C sort -z)

		# Also catch malformed .d directories that do not have a marker file.
		while IFS= read -r -d '' claim; do
			if [[ ! -f "$claim/dest" ]]; then
				error "$(manifest_relative "$claim"): fragment directory is missing its dest marker"
				failed=1
			fi
		done < <(find "$unit" -type d -name '*.d' -print0 | LC_ALL=C sort -z)
	fi

	return "$failed"
}

function validate_managed_marker {
	local marker="$1" base dest lines failed=0
	base="${marker%/dest}"
	base="${base%.d}"
	if [[ ! -f "$base" ]]; then
		error "$(manifest_relative "$marker"): managed base file does not exist"
		failed=1
	fi
	lines="$(awk 'END { print NR }' "$marker")"
	if [[ "$lines" != 1 ]]; then
		error "$(manifest_relative "$marker"): dest marker must contain exactly one line"
		return 1
	fi
	IFS= read -r dest < "$marker"
	if ! validate_home_dest "$dest" "$(manifest_relative "$marker")"; then
		failed=1
	fi
	return "$failed"
}

function deploy_manifest_symlinks {
	local unit="$1" src dest resolved
	while IFS=$'\t' read -r src dest; do
		if ! resolved="$(realpath -q "$unit/$src")"; then
			error "Source disappeared during deployment: $src"
			return 1
		fi
		dest="$(expand_dest "$dest")"
		if ! mkdir -p "$(dirname "$dest")"; then
			error "Could not create destination parent: $(dirname "$dest")"
			return 1
		fi
		if [[ -L "$dest" ]]; then
			if ! rm "$dest"; then
				error "Could not replace symlink destination: $dest"
				return 1
			fi
		elif [[ -e "$dest" ]]; then
			if ! force_enabled; then
				error "Refusing to replace non-symlink destination: $dest"
				return 1
			fi
			backup_dest "$dest" || return 1
		fi
		message "Linking $(manifest_relative "$resolved") -> $dest"
		if ! ln -s "$resolved" "$dest"; then
			error "Could not create symlink destination: $dest"
			return 1
		fi
	done < <(manifest_symlink_rows "$unit/config.yml")
}

function deploy_manifest_copies {
	local unit="$1" src dest resolved parent temp
	while IFS=$'\t' read -r src dest; do
		if ! resolved="$(realpath -q "$unit/$src")"; then
			error "Source disappeared during deployment: $src"
			return 1
		fi
		dest="$(expand_dest "$dest")"
		message "Copying $(manifest_relative "$resolved") -> $dest"
		parent="$(dirname "$dest")"
		if ! mkdir -p "$parent"; then
			error "Could not create destination parent: $parent"
			return 1
		fi
		if [[ -e "$dest" && ! -f "$dest" && ! -L "$dest" ]]; then
			if ! force_enabled; then
				error "Refusing to replace non-file copy destination: $dest"
				return 1
			fi
			backup_dest "$dest" || return 1
		fi
		if ! temp="$(mktemp "$parent/.me-config.XXXXXX")"; then
			error "Could not create temporary copy beside destination: $dest"
			return 1
		fi
		if ! cp -p "$resolved" "$temp"; then
			rm -f "$temp"
			error "Could not copy source: $resolved"
			return 1
		fi
		if [[ -L "$dest" ]] && ! rm "$dest"; then
			rm -f "$temp"
			error "Could not replace symlink destination: $dest"
			return 1
		fi
		if ! mv -f "$temp" "$dest"; then
			rm -f "$temp"
			error "Could not install copy destination: $dest"
			return 1
		fi
	done < <(manifest_copy_rows "$unit/config.yml")
}

function run_manifest_unit {
	local unit
	unit="$(dirname "$1")"
	validate_manifest_unit "$unit" || return 1
	deploy_manifest_symlinks "$unit" || return 1
	deploy_manifest_copies "$unit" || return 1
	deploy_managed_under "$unit" || return 1
	if [[ -f "$unit/post.sh" ]]; then
		message "Running $(manifest_relative "$unit")/post.sh..."
		(
			cd "$unit"
			ME_REPO_ROOT="$MANIFEST_REPO_ROOT" ME_UNIT_DIR="$unit" ./post.sh
		) || return 1
	fi
}

# Print the backup a forced deploy would perform before writing DEST, if any.
function plan_backup_line {
	local kind="$1" dest="$2" expanded
	force_enabled || return 0
	expanded="$(expand_dest "$dest")"
	if [[ "$kind" == symlink && -e "$expanded" && ! -L "$expanded" ]]; then
		printf 'backup %s\n' "$dest"
	elif [[ "$kind" == copy && -e "$expanded" && ! -f "$expanded" && ! -L "$expanded" ]]; then
		printf 'backup %s\n' "$dest"
	fi
}

function plan_manifest_unit {
	local unit src dest marker marker_dest
	unit="$(dirname "$1")"
	validate_manifest_unit "$unit" || return 1
	while IFS=$'\t' read -r src dest; do
		plan_backup_line symlink "$dest"
		printf 'link %s -> %s\n' "$(manifest_relative "$unit")/$src" "$dest"
	done < <(manifest_symlink_rows "$unit/config.yml")
	while IFS=$'\t' read -r src dest; do
		plan_backup_line copy "$dest"
		printf 'copy %s -> %s\n' "$(manifest_relative "$unit")/$src" "$dest"
	done < <(manifest_copy_rows "$unit/config.yml")
	while IFS= read -r -d '' marker; do
		IFS= read -r marker_dest < "$marker"
		src="${marker%/dest}"
		src="${src%.d}"
		printf 'compose %s -> %s\n' "$(manifest_relative "$src")" "$marker_dest"
	done < <(find "$unit" -type f -path '*.d/dest' -print0 | LC_ALL=C sort -z)
	if [[ -f "$unit/post.sh" ]]; then
		printf 'run %s\n' "$(manifest_relative "$unit")/post.sh"
	fi
}
