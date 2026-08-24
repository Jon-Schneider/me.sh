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
