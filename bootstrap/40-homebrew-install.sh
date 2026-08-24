#!/bin/bash
set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
source "$repo_root/lib/common.sh"

if ! command -v brew &>/dev/null && [[ ! -x /opt/homebrew/bin/brew && ! -x /usr/local/bin/brew ]]; then
	message "Installing Homebrew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

load_homebrew

brew_bin="$(command -v brew)"
shellenv_line="eval \"\$($brew_bin shellenv)\""

touch "$HOME/.zprofile"
if ! grep -Fqx "$shellenv_line" "$HOME/.zprofile"; then
	printf '%s\n' "$shellenv_line" >> "$HOME/.zprofile"
fi

message "Homebrew is ready."
