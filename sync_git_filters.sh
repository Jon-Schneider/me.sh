#!/bin/bash

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${script_dir}/lib/common.sh"

message "Updating Git Filters..."

# Git clean/smudge filters are defined in .git/config, which is never cloned, so
# every machine has to register its own. Convention: an executable named
# 'clean_<name>' anywhere under configs/ defines filter.<name>, and the
# .gitattributes beside it maps the files that use it.
#
# Paths are stored relative to the repo root because Git runs filters from there,
# which keeps the same command string valid wherever the repo is cloned.

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$repo_root" || exit 1

find configs -type f -name 'clean_*' -print0 | while IFS= read -r -d '' filter_path; do
	[ -x "$filter_path" ] || continue

	filter_name="$(basename "$filter_path")"
	filter_name="${filter_name#clean_}"

	git config "filter.$filter_name.clean" "$filter_path"
	git config "filter.$filter_name.smudge" cat

	echo "  filter.$filter_name -> $filter_path"
done
