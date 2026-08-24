#!/bin/bash
set -euo pipefail

echo "Configuring System Keyboard Shortcuts..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
plist_name="com.local.KeyRemapping.plist"
label="com.local.KeyRemapping"

mkdir -p ~/Library/LaunchAgents
sudo rm -f ~/Library/LaunchAgents/"$plist_name" # Remove any root-owned copy left by previous versions of this script
cp -v "$current_dir/$plist_name" ~/Library/LaunchAgents # Unfortunately it doesn't appear plists can be linked (ln)
launchctl bootout gui/"$(id -u)"/"$label" 2> /dev/null || true # Unload the service if it is already loaded
launchctl bootstrap gui/"$(id -u)" ~/Library/LaunchAgents/"$plist_name"
