#!/bin/bash
set -euo pipefail

echo "Configuring herdr..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p ~/.config/herdr

ln -sfn "$current_dir/config.toml" ~/.config/herdr/config.toml
ln -sfn "$current_dir/even_panes.py" ~/.config/herdr/even_panes.py

# Plugins are linked in place from this repo; re-link to pick up changes.
#
# - me.even-panes: runs on pane created/closed/moved events and at startup,
#   evening out split panes tmux-style.
# - me.active-cwd: event-driven handler that reports the focused pane's
#   working directory as workspace metadata ($active_repo / $active_cwd),
#   rendered by the [ui.sidebar.spaces] rows in config.toml like the tmux
#   status bar.
# - me.space-mover: move-left / move-right actions that shift the focused
#   space sideways in the sidebar. Bound to Shift+Left/Right via [keys.command]
#   in config.toml; inside tmux, tmux-app-key invokes the same actions.
if command -v herdr > /dev/null; then
  # Plugin ids live in each manifest; grep them out so the loop stays dumb.
  for plugin_dir in plugin plugin-move-space plugin-active-cwd; do
    plugin_id="$(sed -n 's/^id *= *"\(.*\)"/\1/p' "$current_dir/$plugin_dir/herdr-plugin.toml")"
    herdr plugin unlink "$plugin_id" 2> /dev/null || true
    herdr plugin link "$current_dir/$plugin_dir"
  done
  herdr config check && herdr server reload-config || true
fi

# Legacy cleanup: remove the pre-plugin launchd watcher if present.
if [ -f ~/Library/LaunchAgents/com.user.herdr-even-panes.plist ]; then
  launchctl bootout gui/"$(id -u)"/com.user.herdr-even-panes 2> /dev/null || true
  rm ~/Library/LaunchAgents/com.user.herdr-even-panes.plist
fi
