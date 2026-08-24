#!/bin/bash
set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
source "$repo_root/lib/common.sh"
load_homebrew

latest_ruby="$(rbenv install -l | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | tail -1)"
if [[ -z "$latest_ruby" ]]; then
	error "rbenv did not report a current stable Ruby version"
	exit 1
fi

if rbenv versions --bare | grep -Fqx "$latest_ruby"; then
	message "Ruby $latest_ruby is already installed."
else
	message "Installing Ruby $latest_ruby..."
	rbenv install "$latest_ruby"
fi
