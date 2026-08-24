#!/bin/bash
set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../.." && pwd )"
source "$repo_root/lib/common.sh"
load_homebrew

message "Installing global npm utilities..."
npm install --global trash-cli
