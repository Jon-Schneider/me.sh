#!/bin/bash
set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$repo_root/lib/common.sh"

"$repo_root/me" bootstrap

# Bootstrap runs in a child process, so load the newly installed Homebrew into
# this process before starting config units that depend on it.
load_homebrew
"$repo_root/me" all
