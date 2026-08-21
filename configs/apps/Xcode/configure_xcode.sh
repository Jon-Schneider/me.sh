#!/bin/bash
set -euo pipefail

echo "Configuring Xcode..."

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Configure Xcode to display build duration, not finish time
defaults write com.apple.dt.Xcode ShowBuildOperationDuration YES

# Configure keyboard shortcuts
# This file cannot be symlinked because Xcode writes a copy when updated
mkdir -p ~/Library/Developer/Xcode/UserData/KeyBindings
cp -v $current_dir/Default.idekeybindings ~/Library/Developer/Xcode/UserData/KeyBindings/Default.idekeybindings