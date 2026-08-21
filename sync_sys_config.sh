#!/bin/bash
set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$repo_root" || exit 1

source "lib/common.sh"

message "Updating System Configuration..."

# Recursively execute all 'configure_*.sh' scripts in configs/sys in sorted order.
# set -euo pipefail makes a failing script abort the whole run.
find -E configs/sys -name 'configure_*.sh' | sort | while read -r config_script; do
	message "Running ${config_script}..."
	bash "$config_script"
done
