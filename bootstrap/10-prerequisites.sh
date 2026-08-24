#!/bin/bash
set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
source "$repo_root/lib/common.sh"

message "Sign in to the Mac App Store, then press any key to continue:"
read -r -n 1 -s
printf '\n'

if ! xcode-select -p &>/dev/null; then
	message "Install the Xcode Command Line Tools with 'xcode-select --install'."
	message "When installation finishes, press any key to continue:"
	read -r -n 1 -s
	printf '\n'
fi

if ! xcode-select -p &>/dev/null; then
	error "Xcode Command Line Tools are not installed"
	exit 1
fi

message "Caching sudo credentials..."
sudo -v
