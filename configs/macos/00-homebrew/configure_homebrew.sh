#!/bin/bash
set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
source "$repo_root/lib/common.sh"
load_homebrew

cd "$repo_root"
message "Reconciling installed packages with the Brewfile..."
brew bundle --verbose
