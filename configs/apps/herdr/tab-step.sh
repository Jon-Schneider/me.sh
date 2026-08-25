#!/bin/bash
set -euo pipefail

case "${1:-}" in
  next) step=1 ;;
  previous) step=-1 ;;
  *) echo "usage: tab-step.sh <next|previous>" >&2; exit 64 ;;
esac

herdr_bin="${HERDR_BIN_PATH:-herdr}"
current_tab="${HERDR_ACTIVE_TAB_ID:?}"
target=$(
  {
    "$herdr_bin" workspace list
    "$herdr_bin" tab list
  } | jq -s -e -r --arg current "$current_tab" --argjson step "$step" '
    .[0].result.workspaces as $workspaces
    | .[1].result.tabs as $tabs
    | [
        $workspaces | sort_by(.number)[] as $workspace
        | $tabs
        | map(select(.workspace_id == $workspace.workspace_id))
        | sort_by(.number)[]
        | .tab_id
      ] as $tab_ids
    | ($tab_ids | index($current)) as $index
    | if $index == null or ($tab_ids | length) == 0
      then error("active tab missing from Herdr state")
      else $tab_ids[(($index + $step) % ($tab_ids | length))]
      end
  '
)

"$herdr_bin" tab focus "$target"
