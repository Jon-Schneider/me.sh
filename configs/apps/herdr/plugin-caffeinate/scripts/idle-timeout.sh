#!/bin/sh
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

initialize_state || exit 1
my_generation=${1:-}
case "$my_generation" in
    ''|*[!0-9]*) exit 1 ;;
esac

sleep "$IDLE_GRACE_SECONDS"

trap 'release_lock' EXIT HUP INT TERM
acquire_lock || exit 1

current=$(current_generation)
if [ "$my_generation" != "$current" ]; then
    clear_own_timer_pid "$$"
    exit 0
fi

# One authoritative check at the end of the grace period.
if ! agents=$(read_agents); then
    # Failure is not proof of idleness. Keep the assertion and wait for a future
    # Herdr event/manual reconcile to decide again.
    clear_own_timer_pid "$$"
    write_assertion_state awake || true
    exit 0
fi

clear_own_timer_pid "$$"
if agents_are_working "$agents"; then
    start_caffeinate || exit 1
    write_assertion_state awake || exit 1
else
    stop_caffeinate || exit 1
fi

release_lock
trap - EXIT HUP INT TERM
