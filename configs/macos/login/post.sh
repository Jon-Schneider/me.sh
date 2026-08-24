#!/bin/bash
set -euo pipefail

label="com.user.loginscript"
agent="$HOME/Library/LaunchAgents/com.user.loginscript.plist"

launchctl bootout gui/"$(id -u)"/"$label" 2> /dev/null || true
launchctl bootstrap gui/"$(id -u)" "$agent"
