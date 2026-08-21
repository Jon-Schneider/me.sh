#!/bin/bash
set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$repo_root" || exit 1

source "lib/common.sh"

message "Updating Application Configuration..."

# Recursively execute all 'configure_*.sh' scripts in configs/apps in sorted order.
# A failing script prints an error and the run continues; failures are summarized
# at the end and reported with a non-zero exit code.
declare -a failed_scripts=()
while IFS= read -r config_script; do
	message "Running ${config_script}..."
	if ! bash "$config_script"; then
		error "${config_script} failed"
		failed_scripts+=("$config_script")
	fi
done < <(find -E configs/apps -name 'configure_*.sh' | sort)

"${repo_root}/sync_git_filters.sh"

if (( ${#failed_scripts[@]} > 0 )); then
	error "${#failed_scripts[@]} script(s) failed:"
	for failed_script in "${failed_scripts[@]}"; do
		error "  ${failed_script}"
	done
	exit 1
fi
