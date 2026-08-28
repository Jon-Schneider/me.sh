#!/bin/sh
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"

initialize_state || exit 1

if caffeinate_is_running; then
    assertion=active
    pid=$(read_pid_file "$CAFFEINATE_PID_FILE" 2>/dev/null || printf '%s' '?')
else
    assertion=inactive
    pid='-'
fi

if timer_is_running; then
    grace=active
else
    grace=none
fi

if agents=$(read_agents); then
    if agents_are_working "$agents"; then
        working=yes
    else
        working=no
    fi
else
    working=unknown
fi

state=$(cat "$ASSERTION_STATE_FILE" 2>/dev/null || printf '%s' unknown)

printf 'Caffeinate: %s\n' "$assertion"
printf 'PID: %s\n' "$pid"
printf 'Agents working: %s\n' "$working"
printf 'Grace timer: %s\n' "$grace"
printf 'UI state: %s\n' "$state"
printf 'Session: %s\n' "$SESSION_KEY"
