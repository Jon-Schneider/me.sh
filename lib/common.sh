#!/bin/bash

# Shared helpers for the me.sh setup and sync commands.

# Print a green status message. Uses %s so messages containing '%' or '\' are printed literally.
function message {
	printf '\033[0;32m%s\033[0m\n' "$1"
}

# Print a red error message. Uses %s so messages containing '%' or '\' are printed literally.
function error {
	printf '\033[0;31m%s\033[0m\n' "$1"
}

# Load Homebrew into PATH in non-login shells, including the first setup run
# immediately after Homebrew was installed.
function load_homebrew {
	local brew_bin
	if command -v brew &>/dev/null; then
		return 0
	fi
	for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
		if [[ -x "$brew_bin" ]]; then
			eval "$("$brew_bin" shellenv)"
			return 0
		fi
	done
	error "Homebrew is not installed; run 'me bootstrap homebrew-install' first"
	return 1
}

# Deployment force mode. When enabled, a destination that would otherwise be
# refused is moved aside instead of failing its unit.
ME_FORCE="${ME_FORCE:-0}"

function force_enabled {
	[[ "$ME_FORCE" == 1 ]]
}

# Move a conflicting destination aside. Timestamped, and never overwrites an
# earlier rescue, so repeated forced runs stay recoverable.
function backup_dest {
	local dest="$1" backup
	backup="${dest}.me-backup-$(date +%Y%m%d%H%M%S)"
	while [[ -e "$backup" || -L "$backup" ]]; do
		backup="${backup}~"
	done
	if ! mv "$dest" "$backup"; then
		error "Could not move existing destination aside: $dest"
		return 1
	fi
	message "Backed up $dest -> $backup"
}
