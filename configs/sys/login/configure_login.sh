#!/bin/bash
set -euo pipefail

echo "Configuring Login Script..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
plist_name="com.user.loginscript.plist"
label="com.user.loginscript"

mkdir -p ~/bin
ln -sfn "$current_dir/login.sh" ~/bin/login.sh
mkdir -p ~/Library/LaunchAgents
sudo rm -f ~/Library/LaunchAgents/"$plist_name" # Remove any root-owned copy left by previous versions of this script
cp -v "$current_dir/$plist_name" ~/Library/LaunchAgents # Unfortunately it doesn't appear plists can be linked (ln)
launchctl bootout gui/"$(id -u)"/"$label" 2> /dev/null || true # Unload the service if it is already loaded
launchctl bootstrap gui/"$(id -u)" ~/Library/LaunchAgents/"$plist_name"
