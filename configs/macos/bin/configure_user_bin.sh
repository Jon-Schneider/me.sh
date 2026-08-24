#!/bin/bash
set -euo pipefail

echo "Configuring User bin..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir -p ~/bin
ln -sfn $current_dir/get_finder_selected_item_paths ~/bin/get_finder_selected_item_paths
ln -sfn $current_dir/git_rebase_bbedit ~/bin/git_rebase_bbedit
ln -sfn $current_dir/starship-github-pr ~/bin/starship-github-pr
ln -sfn $current_dir/starship-github-pr-refresh ~/bin/starship-github-pr-refresh
