#!/bin/bash
set -euo pipefail

echo "Configuring Ghostty..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir -p ~/.config/ghostty/themes

ln -sfn $current_dir/config ~/.config/ghostty/config
ln -sfn $current_dir/themes/jon ~/.config/ghostty/themes/jon