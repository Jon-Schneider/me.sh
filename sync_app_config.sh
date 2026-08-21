#!/bin/bash
set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$repo_root" || exit 1

source "lib/common.sh"

message "Updating Application Configuration..."

# Recursively execute all 'configure_*.sh' scripts in configs/apps in sorted order.
# set -euo pipefail makes a failing script abort the whole run.
find -E configs/apps -name 'configure_*.sh' | sort | while read -r config_script; do
	message "Running ${config_script}..."
	bash "$config_script"
done

"${repo_root}/sync_git_filters.sh"
