#!/bin/bash
set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
source "$repo_root/lib/common.sh"

developer_root="$HOME/Developer/jsc"
mkdir -p "$developer_root"
for link in "$HOME/repo" "$HOME/repos"; do
	if [[ -e "$link" && ! -L "$link" ]]; then
		error "$link exists and is not a symlink; leaving it untouched"
		exit 1
	fi
	ln -sfn "$developer_root" "$link"
done
message "Repository shortcuts are configured."
