#!/bin/sh

PLUGIN_ID=me.caffeinate
IDLE_GRACE_SECONDS=${HERDR_CAFFEINATE_IDLE_GRACE_SECONDS:-30}
CAFFEINATE_BIN=${CAFFEINATE_BIN:-/usr/bin/caffeinate}
HERDR_BIN_PATH=${HERDR_BIN_PATH:-herdr}
LOCK_WAIT_ATTEMPTS=${HERDR_CAFFEINATE_LOCK_WAIT_ATTEMPTS:-500}

COMMON_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=${HERDR_PLUGIN_ROOT:-$(CDPATH= cd -- "$COMMON_DIR/.." && pwd)}
IDLE_SCRIPT="$PLUGIN_ROOT/scripts/idle-timeout.sh"

initialize_state() {
    if [ -z "${HERDR_PLUGIN_STATE_DIR:-}" ]; then
        echo "me.caffeinate: HERDR_PLUGIN_STATE_DIR is not set" >&2
        return 1
    fi
    if [ -z "${HERDR_SOCKET_PATH:-}" ]; then
        echo "me.caffeinate: HERDR_SOCKET_PATH is not set" >&2
        return 1
    fi

    SESSION_KEY=$(printf '%s' "$HERDR_SOCKET_PATH" | cksum | awk '{print $1}')
    SESSION_DIR="$HERDR_PLUGIN_STATE_DIR/sessions/$SESSION_KEY"
    CAFFEINATE_PID_FILE="$SESSION_DIR/caffeinate.pid"
    TIMER_PID_FILE="$SESSION_DIR/idle-timer.pid"
    GENERATION_FILE="$SESSION_DIR/idle-generation"
    ASSERTION_STATE_FILE="$SESSION_DIR/assertion-state"
    LOCK_FILE="$SESSION_DIR/lock"

    mkdir -p "$SESSION_DIR" || return 1
    return 0
}

atomic_write() {
    file=$1
    value=$2
    tmp="${file}.tmp.$$"
    if ! ( umask 077; printf '%s\n' "$value" > "$tmp" ); then
        rm -f "$tmp"
        return 1
    fi
    if ! mv -f "$tmp" "$file"; then
        rm -f "$tmp"
        return 1
    fi
}

# sh has no locals: every helper here uses a distinct variable name so callers
# holding a value in `pid` or `command` are not clobbered by a later call.
read_pid_file() {
    pid_file=$1
    [ -f "$pid_file" ] || return 1
    stored_pid=$(cat "$pid_file" 2>/dev/null) || return 1
    case "$stored_pid" in
        ''|*[!0-9]*) return 1 ;;
    esac
    printf '%s\n' "$stored_pid"
}

process_command() {
    ps -p "$1" -o command= 2>/dev/null
}

pid_is_alive() {
    candidate_pid=$1
    kill -0 "$candidate_pid" 2>/dev/null || return 1
    candidate_state=$(ps -p "$candidate_pid" -o state= 2>/dev/null || true)
    case "$candidate_state" in
        ''|*Z*) return 1 ;;
        *) return 0 ;;
    esac
}

caffeinate_is_running() {
    caffeinate_pid=$(read_pid_file "$CAFFEINATE_PID_FILE") || return 1
    pid_is_alive "$caffeinate_pid" || return 1
    caffeinate_cmd=$(process_command "$caffeinate_pid") || return 1
    case "$caffeinate_cmd" in
        *"$CAFFEINATE_BIN"*"-i"*) return 0 ;;
        *) return 1 ;;
    esac
}

timer_is_running() {
    timer_pid=$(read_pid_file "$TIMER_PID_FILE") || return 1
    pid_is_alive "$timer_pid" || return 1
    timer_cmd=$(process_command "$timer_pid") || return 1
    case "$timer_cmd" in
        *"$IDLE_SCRIPT"*) return 0 ;;
        *) return 1 ;;
    esac
}

write_assertion_state() {
    atomic_write "$ASSERTION_STATE_FILE" "$1"
}

start_caffeinate() {
    if caffeinate_is_running; then
        write_assertion_state awake
        return 0
    fi

    rm -f "$CAFFEINATE_PID_FILE"
    "$CAFFEINATE_BIN" -i </dev/null >/dev/null 2>&1 &
    started_pid=$!
    if ! atomic_write "$CAFFEINATE_PID_FILE" "$started_pid"; then
        kill "$started_pid" 2>/dev/null || true
        return 1
    fi

    # Catch immediate exec/startup failures without introducing a resident monitor.
    sleep 0.05
    if ! caffeinate_is_running; then
        rm -f "$CAFFEINATE_PID_FILE"
        return 1
    fi

    write_assertion_state awake
}

stop_caffeinate() {
    if caffeinate_is_running; then
        doomed_pid=$(read_pid_file "$CAFFEINATE_PID_FILE") || doomed_pid=''
        if [ -n "$doomed_pid" ]; then
            if ! kill "$doomed_pid" 2>/dev/null; then
                write_assertion_state awake || true
                return 1
            fi

            attempts=0
            while pid_is_alive "$doomed_pid" && [ "$attempts" -lt 50 ]; do
                attempts=$((attempts + 1))
                sleep 0.01
            done
            if pid_is_alive "$doomed_pid"; then
                write_assertion_state awake || true
                return 1
            fi
        fi
    fi
    rm -f "$CAFFEINATE_PID_FILE"
    write_assertion_state sleepable
}

current_generation() {
    if [ -f "$GENERATION_FILE" ]; then
        generation=$(cat "$GENERATION_FILE" 2>/dev/null || true)
        case "$generation" in
            ''|*[!0-9]*) generation=0 ;;
        esac
    else
        generation=0
    fi
    printf '%s\n' "$generation"
}

bump_generation() {
    generation=$(current_generation)
    generation=$((generation + 1))
    atomic_write "$GENERATION_FILE" "$generation" || return 1
    printf '%s\n' "$generation"
}

cancel_idle_timer() {
    # Invalidate first so a timer racing with cancellation cannot act as current.
    bump_generation >/dev/null || return 1

    if timer_is_running; then
        # The timer belongs to an earlier reconcile process, so it cannot be
        # reaped here; the generation bump above already made it a no-op.
        doomed_pid=$(read_pid_file "$TIMER_PID_FILE") || doomed_pid=''
        if [ -n "$doomed_pid" ]; then
            kill "$doomed_pid" 2>/dev/null || true
        fi
    fi
    rm -f "$TIMER_PID_FILE"
}

start_idle_timer() {
    if timer_is_running; then
        return 0
    fi

    rm -f "$TIMER_PID_FILE"
    generation=$(bump_generation) || return 1
    sh "$IDLE_SCRIPT" "$generation" </dev/null >/dev/null 2>&1 &
    started_pid=$!
    if ! atomic_write "$TIMER_PID_FILE" "$started_pid"; then
        kill "$started_pid" 2>/dev/null || true
        return 1
    fi
}

clear_own_timer_pid() {
    expected=$1
    actual=$(read_pid_file "$TIMER_PID_FILE" 2>/dev/null || true)
    if [ "$actual" = "$expected" ]; then
        rm -f "$TIMER_PID_FILE"
    fi
}

acquire_lock() {
    attempts=0
    while [ "$attempts" -lt "$LOCK_WAIT_ATTEMPTS" ]; do
        if ( set -C; umask 077; printf '%s\n' "$$" > "$LOCK_FILE" ) 2>/dev/null; then
            return 0
        fi

        owner=$(read_pid_file "$LOCK_FILE" 2>/dev/null || true)
        if [ -n "$owner" ] && ! pid_is_alive "$owner"; then
            rm -f "$LOCK_FILE"
        fi

        attempts=$((attempts + 1))
        sleep 0.01
    done
    return 1
}

release_lock() {
    owner=$(read_pid_file "$LOCK_FILE" 2>/dev/null || true)
    if [ "$owner" = "$$" ]; then
        rm -f "$LOCK_FILE"
    fi
}

# A zero exit carrying something other than an agent list (an error envelope,
# a truncated reply) counts as a failed query: only a body we recognize may be
# read as evidence that nothing is working.
read_agents() {
    agent_list=$("$HERDR_BIN_PATH" agent list 2>/dev/null) || return 1
    printf '%s\n' "$agent_list" | grep -q '"type"[[:space:]]*:[[:space:]]*"agent_list"' || return 1
    printf '%s\n' "$agent_list"
}

agents_are_working() {
    printf '%s\n' "$1" | grep -Eq '"agent_status"[[:space:]]*:[[:space:]]*"working"'
}
