#!/bin/bash
set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
source "$repo_root/lib/common.sh"

if [[ "$(uname -m)" != "arm64" ]]; then
	message "Rosetta is only needed on Apple silicon; skipping."
	exit 0
fi

if pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto &>/dev/null; then
	message "Rosetta 2 is already installed."
	exit 0
fi

message "Installing Rosetta 2..."
sudo softwareupdate --install-rosetta --agree-to-license
