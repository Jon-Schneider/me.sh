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
