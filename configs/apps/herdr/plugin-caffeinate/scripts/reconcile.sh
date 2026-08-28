#!/bin/sh
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

initialize_state || exit 1
# Armed before acquiring: release_lock only removes a lock this pid owns, so a
# signal arriving mid-acquisition cannot leak one.
trap 'release_lock' EXIT HUP INT TERM
acquire_lock || exit 1

# Query under the lock so an older event cannot apply a stale snapshot after a
# newer event has already reconciled.
if ! agents=$(read_agents); then
    # Unknown is not idle. Preserve the current assertion state.
    exit 0
fi

if agents_are_working "$agents"; then
    cancel_idle_timer || exit 1
    start_caffeinate || exit 1
else
    if caffeinate_is_running; then
        write_assertion_state awake || exit 1
        start_idle_timer || exit 1
    else
        # Clean stale bookkeeping if the assertion disappeared independently.
        cancel_idle_timer || exit 1
        rm -f "$CAFFEINATE_PID_FILE"
        write_assertion_state sleepable || exit 1
    fi
fi

release_lock
trap - EXIT HUP INT TERM
