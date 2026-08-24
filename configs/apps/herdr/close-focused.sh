#!/bin/bash
# Cmd+W cascade for Herdr custom keybinding ([[keys.command]] key = "ctrl+w").
# TUI apps that own Ctrl+W themselves (micro binds it to Quit, xlent to clear)
# receive the raw key instead; otherwise close by preference: the focused split
# pane; if the active tab has no splits, the active tab; if that was the
# workspace's only tab, the workspace itself.
#
# Custom command keybindings run with HERDR_ACTIVE_WORKSPACE_ID,
# HERDR_ACTIVE_TAB_ID, and HERDR_ACTIVE_PANE_ID set to the focused pane.
set -euo pipefail

ws="${HERDR_ACTIVE_WORKSPACE_ID:?}"
tab="${HERDR_ACTIVE_TAB_ID:?}"
pane="${HERDR_ACTIVE_PANE_ID:?}"

foreground_apps=$(herdr pane process-info --pane "$pane" |
  jq -r '.result.process_info.foreground_processes[]?.name // empty')

if grep -qx -e micro -e xlent <<<"$foreground_apps"; then
  herdr pane send-text "$pane" $'\x17'
  exit 0
fi

info=$(herdr workspace get "$ws" | jq '.result.workspace')
panes_in_tab=$(herdr pane list --workspace "$ws" |
  jq --arg t "$tab" '[.result.panes[] | select(.tab_id == $t)] | length')

if (( panes_in_tab > 1 )); then
  herdr pane close "$pane"
else
  tabs=$(jq -r '.tab_count' <<<"$info")
  if (( tabs > 1 )); then
    herdr tab close "$tab"
  else
    herdr workspace close "$ws"
  fi
fi
