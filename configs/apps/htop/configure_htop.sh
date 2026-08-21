#!/bin/bash
set -euo pipefail

echo "Configuring htop..."
mkdir -p ~/.config/htop 2> /dev/null # Redirect stderr to suppress dir already exists log
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ln -sfn $current_dir/htoprc ~/.config/htop/htoprc