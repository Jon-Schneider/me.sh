#!/bin/bash
set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
source "$repo_root/lib/common.sh"

mkdir -p "$HOME/.ssh"
if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
	message "Generating an SSH key..."
	ssh-keygen -t ed25519 -C "jon@jonschneider.me" -f "$HOME/.ssh/id_ed25519"
fi

message "Adding the SSH key to the Apple keychain..."
ssh-add -K "$HOME/.ssh/id_ed25519"
