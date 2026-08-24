#!/bin/bash
set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
source "$repo_root/lib/common.sh"

mkdir -p "$HOME/Tmp"

if [[ -L "$HOME/Downloads" ]]; then
	if [[ "$(readlink "$HOME/Downloads")" == "$HOME/Tmp" ]]; then
		message "Downloads already points to ~/Tmp."
		exit 0
	fi
	message "Re-pointing the existing Downloads symlink to ~/Tmp."
	ln -sfn "$HOME/Tmp" "$HOME/Downloads"
	exit 0
fi

if [[ -d "$HOME/Downloads" ]]; then
	message "Downloads is a real folder. Its contents will move to ~/Tmp before it is replaced by a symlink."
	message "Press any key to continue (Ctrl+C to abort):"
	read -r -n 1 -s
	printf '\n'
	find "$HOME/Downloads" -mindepth 1 -maxdepth 1 -exec mv {} "$HOME/Tmp/" \;
	rmdir "$HOME/Downloads"
elif [[ -e "$HOME/Downloads" ]]; then
	error "$HOME/Downloads exists but is neither a directory nor a symlink"
	exit 1
fi

ln -s "$HOME/Tmp" "$HOME/Downloads"
message "Downloads now points to ~/Tmp."
