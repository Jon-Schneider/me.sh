#!/bin/bash
set -euo pipefail

echo "Configuring herdr..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
plugin_id="me.even-panes"

mkdir -p ~/.config/herdr

ln -sfn "$current_dir/config.toml" ~/.config/herdr/config.toml
ln -sfn "$current_dir/even_panes.py" ~/.config/herdr/even_panes.py

# Even-panes plugin: herdr runs it on pane created/closed/moved events and at
# startup, evening out split panes tmux-style. Re-link to pick up changes.
if command -v herdr > /dev/null; then
  herdr plugin unlink "$plugin_id" 2> /dev/null || true
  herdr plugin link "$current_dir/plugin"
  herdr config check && herdr server reload-config || true
fi

# Legacy cleanup: remove the pre-plugin launchd watcher if present.
if [ -f ~/Library/LaunchAgents/com.user.herdr-even-panes.plist ]; then
  launchctl bootout gui/"$(id -u)"/com.user.herdr-even-panes 2> /dev/null || true
  rm ~/Library/LaunchAgents/com.user.herdr-even-panes.plist
fi
