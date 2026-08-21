#!/bin/bash

# Shared helpers for the me.sh setup and sync scripts.

# Print a green status message. Uses %s so messages containing '%' or '\' are printed literally.
function message {
	printf '\033[0;32m%s\033[0m\n' "$1"
}
