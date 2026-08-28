#!/bin/bash
set -euo pipefail

# Plugins are linked in place from this repo; re-link to pick up changes.
#
# - me.even-panes: runs on pane created/closed/moved events and at startup,
#   evening out split panes.
# - me.active-cwd: event-driven handler that reports each space's
#   focused-pane working directory as workspace metadata ($active_repo /
#   $active_cwd), rendered by the [ui.sidebar.spaces] rows in config.toml
#   as workspace metadata. Herdr 0.7.x fires no plugin event when a
#   pane's cwd changes, so .zshrc also spawns this same handler from a
#   chpwd hook to cover bare `cd`.
# - me.space-mover: move-left / move-right actions that shift the focused
#   space sideways in the sidebar. Bound to Shift+Left/Right via [keys.command]
#   in config.toml.
# - me.active-tab-title: prefixes tabs with one monochrome status symbol per
#   agent pane, and mirrors the focused pane's label.
# - me.caffeinate: holds a `caffeinate -i` assertion while any agent is
#   working, released 30s after the last one stops. The ☕ it publishes is
#   rendered by the tab_bar_right command entry in config.toml.
if command -v herdr > /dev/null; then
  if ! herdr plugin list --plugin jhochenbaum.hunkdiff |
    grep -Fq -- '- jhochenbaum.hunkdiff ('; then
    herdr plugin install jhochenbaum/herdr-hunk-diff --yes
  fi

  # The caffeinate plugin was briefly linked under its upstream id before being
  # renamed to me.caffeinate; the loop below only unlinks current ids.
  herdr plugin unlink herdr-caffeinate 2> /dev/null || true

  # Plugin ids live in each manifest; extract them so the loop stays dumb.
  for plugin_dir in plugin plugin-move-space plugin-active-cwd plugin-active-tab-title plugin-caffeinate; do
    plugin_id="$(sed -n 's/^id *= *"\(.*\)"/\1/p' "$ME_UNIT_DIR/$plugin_dir/herdr-plugin.toml")"
    herdr plugin unlink "$plugin_id" 2> /dev/null || true
    herdr plugin link "$ME_UNIT_DIR/$plugin_dir"
  done
  herdr config check && herdr server reload-config || true
fi

# Legacy cleanup: remove the pre-plugin launchd watcher if present.
legacy_agent="$HOME/Library/LaunchAgents/com.user.herdr-even-panes.plist"
if [[ -f "$legacy_agent" ]]; then
  launchctl bootout gui/"$(id -u)"/com.user.herdr-even-panes 2> /dev/null || true
  rm "$legacy_agent"
fi
