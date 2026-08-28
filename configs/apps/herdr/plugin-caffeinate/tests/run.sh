#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/me-caffeinate-tests.XXXXXX") || exit 1
PASS=0
FAIL=0
CASE_DIR=''

cleanup_case() {
    if [ -n "$CASE_DIR" ] && [ -d "$CASE_DIR" ]; then
        if [ -d "$CASE_DIR/plugin-state" ]; then
            find "$CASE_DIR/plugin-state" -name '*.pid' -type f 2>/dev/null | while IFS= read -r file; do
                pid=$(cat "$file" 2>/dev/null || true)
                case "$pid" in
                    ''|*[!0-9]*) continue ;;
                esac
                kill "$pid" 2>/dev/null || true
            done
        fi
        rm -rf "$CASE_DIR"
    fi
    CASE_DIR=''
}

cleanup_all() {
    cleanup_case
    rm -rf "$TMP_ROOT"
}
trap cleanup_all EXIT HUP INT TERM

fail() {
    echo "  FAIL: $*" >&2
    return 1
}

assert_eq() {
    expected=$1
    actual=$2
    message=${3:-"expected '$expected', got '$actual'"}
    [ "$expected" = "$actual" ] || fail "$message (expected '$expected', got '$actual')"
}

assert_file_eq() {
    file=$1
    expected=$2
    actual=$(cat "$file" 2>/dev/null || true)
    assert_eq "$expected" "$actual" "$file"
}

assert_alive() (
    check_pid=$1
    kill -0 "$check_pid" 2>/dev/null || fail "pid $check_pid is not alive"
    check_state=$(ps -p "$check_pid" -o state= 2>/dev/null || true)
    case "$check_state" in
        ''|*Z*) fail "pid $check_pid is not running (state=$check_state)" ;;
    esac
)

assert_dead() (
    check_pid=$1
    if ! kill -0 "$check_pid" 2>/dev/null; then
        exit 0
    fi
    check_state=$(ps -p "$check_pid" -o state= 2>/dev/null || true)
    case "$check_state" in
        ''|*Z*) exit 0 ;;
        *) fail "pid $check_pid is still running (state=$check_state)" ;;
    esac
)

assert_exists() {
    [ -e "$1" ] || fail "missing $1"
}

assert_not_exists() {
    [ ! -e "$1" ] || fail "unexpected $1"
}

make_mocks() {
    mkdir -p "$CASE_DIR/bin"

    cat > "$CASE_DIR/bin/herdr" <<'MOCK_HERDR'
#!/bin/sh
set -u
[ "${1:-}" = agent ] && [ "${2:-}" = list ] || exit 2
state=$(cat "$MOCK_HERDR_STATE_FILE" 2>/dev/null || printf '%s' fail)
case "$state" in
    fail)
        exit 1
        ;;
    none)
        printf '%s\n' '{"id":"test","result":{"type":"agent_list","agents":[]}}'
        ;;
    idle)
        printf '%s\n' '{"id":"test","result":{"type":"agent_list","agents":[{"agent_status":"idle","pane_id":"p1"}]}}'
        ;;
    one-working)
        printf '%s\n' '{"id":"test","result":{"type":"agent_list","agents":[{"agent_status":"working","pane_id":"p1"}]}}'
        ;;
    two-working)
        printf '%s\n' '{"id":"test","result":{"type":"agent_list","agents":[{"agent_status":"working","pane_id":"p1"},{"agent_status":"working","pane_id":"p2"}]}}'
        ;;
    one-working-one-idle)
        printf '%s\n' '{"id":"test","result":{"type":"agent_list","agents":[{"agent_status":"working","pane_id":"p1"},{"agent_status":"idle","pane_id":"p2"}]}}'
        ;;
    *)
        exit 2
        ;;
esac
MOCK_HERDR

    cat > "$CASE_DIR/bin/caffeinate" <<'MOCK_CAFFEINATE'
#!/usr/bin/env python3
import signal
import sys
import time

if sys.argv[1:] != ["-i"]:
    raise SystemExit(2)

def stop(_signum, _frame):
    raise SystemExit(0)

for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
    signal.signal(sig, stop)

while True:
    time.sleep(60)
MOCK_CAFFEINATE

    chmod +x "$CASE_DIR/bin/herdr" "$CASE_DIR/bin/caffeinate"
}

setup_case() {
    cleanup_case
    name=$1
    grace=${2:-30}
    CASE_DIR=$(mktemp -d "$TMP_ROOT/$name.XXXXXX") || exit 1
    make_mocks

    export HERDR_PLUGIN_ROOT="$ROOT"
    export HERDR_PLUGIN_STATE_DIR="$CASE_DIR/plugin-state"
    export HERDR_SOCKET_PATH="$CASE_DIR/herdr.sock"
    export HERDR_BIN_PATH="$CASE_DIR/bin/herdr"
    export CAFFEINATE_BIN="$CASE_DIR/bin/caffeinate"
    export MOCK_HERDR_STATE_FILE="$CASE_DIR/herdr-state"
    export HERDR_CAFFEINATE_IDLE_GRACE_SECONDS="$grace"
    export HERDR_CAFFEINATE_LOCK_WAIT_ATTEMPTS=500

    mkdir -p "$HERDR_PLUGIN_STATE_DIR"
    printf '%s\n' none > "$MOCK_HERDR_STATE_FILE"
    refresh_session_dir
}

refresh_session_dir() {
    key=$(printf '%s' "$HERDR_SOCKET_PATH" | cksum | awk '{print $1}')
    SESSION_DIR="$HERDR_PLUGIN_STATE_DIR/sessions/$key"
    CAFF_PID_FILE="$SESSION_DIR/caffeinate.pid"
    TIMER_PID_FILE="$SESSION_DIR/idle-timer.pid"
    GEN_FILE="$SESSION_DIR/idle-generation"
    STATE_FILE="$SESSION_DIR/assertion-state"
}

set_agents() {
    printf '%s\n' "$1" > "$MOCK_HERDR_STATE_FILE"
}

reconcile() {
    sh "$ROOT/scripts/reconcile.sh"
}

read_caff_pid() {
    cat "$CAFF_PID_FILE"
}

run_test() {
    name=$1
    shift
    printf 'TEST %s\n' "$name"
    if "$@"; then
        PASS=$((PASS + 1))
        echo "  ok"
    else
        FAIL=$((FAIL + 1))
        echo "  failed" >&2
    fi
    cleanup_case
}

test_start_and_duplicate() {
    setup_case start 10
    set_agents one-working
    reconcile || return 1
    assert_exists "$CAFF_PID_FILE" || return 1
    pid1=$(read_caff_pid)
    assert_alive "$pid1" || return 1
    assert_file_eq "$STATE_FILE" awake || return 1
    assert_not_exists "$TIMER_PID_FILE" || return 1

    reconcile || return 1
    pid2=$(read_caff_pid)
    assert_eq "$pid1" "$pid2" "duplicate event started another caffeinate" || return 1
}

test_multiple_agents() {
    setup_case multiple 10
    set_agents two-working
    reconcile || return 1
    pid=$(read_caff_pid)

    set_agents one-working-one-idle
    reconcile || return 1
    assert_alive "$pid" || return 1
    assert_not_exists "$TIMER_PID_FILE" || return 1

    set_agents idle
    reconcile || return 1
    assert_alive "$pid" || return 1
    assert_exists "$TIMER_PID_FILE" || return 1
    assert_file_eq "$STATE_FILE" awake || return 1
}

test_grace_release() {
    setup_case release 1
    set_agents one-working
    reconcile || return 1
    pid=$(read_caff_pid)

    set_agents idle
    reconcile || return 1
    assert_alive "$pid" || return 1
    assert_exists "$TIMER_PID_FILE" || return 1
    assert_file_eq "$STATE_FILE" awake || return 1

    sleep 1.4
    assert_dead "$pid" || return 1
    assert_not_exists "$TIMER_PID_FILE" || return 1
    assert_file_eq "$STATE_FILE" sleepable || return 1
}

test_resume_cancels_grace() {
    setup_case resume 2
    set_agents one-working
    reconcile || return 1
    pid=$(read_caff_pid)

    set_agents idle
    reconcile || return 1
    timer=$(cat "$TIMER_PID_FILE")
    assert_alive "$timer" || return 1

    sleep 0.3
    set_agents one-working
    reconcile || return 1
    assert_alive "$pid" || return 1
    assert_not_exists "$TIMER_PID_FILE" || return 1
    assert_file_eq "$STATE_FILE" awake || return 1

    sleep 2.2
    assert_alive "$pid" || return 1
}

test_stale_generation_cannot_release() {
    setup_case generation 10
    set_agents one-working
    reconcile || return 1
    pid=$(read_caff_pid)

    set_agents idle
    reconcile || return 1
    old_generation=$(cat "$GEN_FILE")

    set_agents one-working
    reconcile || return 1
    new_generation=$(cat "$GEN_FILE")
    [ "$new_generation" -gt "$old_generation" ] || return 1

    HERDR_CAFFEINATE_IDLE_GRACE_SECONDS=0 sh "$ROOT/scripts/idle-timeout.sh" "$old_generation" || return 1
    assert_alive "$pid" || return 1
    assert_file_eq "$STATE_FILE" awake || return 1
}

test_query_failure_preserves_assertion() {
    setup_case query-fail 10
    set_agents one-working
    reconcile || return 1
    pid=$(read_caff_pid)

    set_agents fail
    reconcile || return 1
    assert_alive "$pid" || return 1
    assert_file_eq "$STATE_FILE" awake || return 1
}

test_timeout_query_failure_preserves_assertion() {
    setup_case timeout-fail 1
    set_agents one-working
    reconcile || return 1
    pid=$(read_caff_pid)

    set_agents idle
    reconcile || return 1
    assert_exists "$TIMER_PID_FILE" || return 1
    set_agents fail

    sleep 1.4
    assert_alive "$pid" || return 1
    assert_not_exists "$TIMER_PID_FILE" || return 1
    assert_file_eq "$STATE_FILE" awake || return 1
}

test_stale_pid_replaced_safely() {
    setup_case stale-pid 10
    mkdir -p "$SESSION_DIR"
    # Our own test shell is alive but is not caffeinate; validation must reject it.
    printf '%s\n' "$$" > "$CAFF_PID_FILE"
    printf '%s\n' awake > "$STATE_FILE"

    set_agents one-working
    reconcile || return 1
    pid=$(read_caff_pid)
    [ "$pid" != "$$" ] || fail "unrelated pid was accepted as caffeinate" || return 1
    assert_alive "$pid" || return 1
}

test_status_indicator() {
    setup_case indicator 0
    set_agents one-working
    reconcile || return 1
    output=$("$ROOT/bin/status-indicator" "$HERDR_PLUGIN_STATE_DIR")
    assert_eq '☕' "$output" "indicator should show coffee" || return 1

    set_agents idle
    reconcile || return 1
    sleep 0.2
    output=$("$ROOT/bin/status-indicator" "$HERDR_PLUGIN_STATE_DIR")
    assert_eq '' "$output" "indicator should disappear after release" || return 1
}

test_session_isolation() {
    setup_case sessions 10
    state_a="$CASE_DIR/herdr-a"
    state_b="$CASE_DIR/herdr-b"
    socket_a="$CASE_DIR/a.sock"
    socket_b="$CASE_DIR/b.sock"

    export MOCK_HERDR_STATE_FILE="$state_a"
    export HERDR_SOCKET_PATH="$socket_a"
    printf '%s\n' one-working > "$state_a"
    refresh_session_dir
    reconcile || return 1
    dir_a=$SESSION_DIR
    pid_a=$(read_caff_pid)

    export MOCK_HERDR_STATE_FILE="$state_b"
    export HERDR_SOCKET_PATH="$socket_b"
    printf '%s\n' idle > "$state_b"
    refresh_session_dir
    reconcile || return 1
    dir_b=$SESSION_DIR

    [ "$dir_a" != "$dir_b" ] || fail "sessions share state directory" || return 1
    assert_alive "$pid_a" || return 1
    [ ! -f "$dir_b/caffeinate.pid" ] || fail "idle session created assertion" || return 1

    output=$("$ROOT/bin/status-indicator" "$HERDR_PLUGIN_STATE_DIR")
    assert_eq '☕' "$output" "aggregate indicator missed active session" || return 1
}

test_status_hook_is_small_helper() {
    setup_case hook 10
    set_agents one-working
    reconcile || return 1
    output=$(sh "$ROOT/scripts/status-hook.sh") || return 1
    printf '%s\n' "$output" | grep -q 'type = "command"' || return 1
    printf '%s\n' "$output" | grep -q 'bin/status-indicator' || return 1
    printf '%s\n' "$output" | grep -q "$HERDR_PLUGIN_STATE_DIR" || return 1
    if printf '%s\n' "$output" | grep -Eqi 'agent list|launchagent|daemon'; then
        fail "status hook contains more than a small local-state helper"
        return 1
    fi

    snippet=$(printf '%s\n' "$output" | grep '^{ type = "command"') || return 1
    printf '[ui]\ntab_bar_right = [\n%s\n]\n' "$snippet" > "$CASE_DIR/status.toml"
    python3 - "$CASE_DIR/status.toml" "$CASE_DIR/status-command" <<'PY_TOML'
import sys, tomllib
with open(sys.argv[1], 'rb') as f:
    config = tomllib.load(f)
entry = config['ui']['tab_bar_right'][0]
assert entry['type'] == 'command'
assert entry['interval_seconds'] == 5
assert entry['timeout_seconds'] == 1
with open(sys.argv[2], 'w', encoding='utf-8') as f:
    f.write(entry['command'])
PY_TOML
    status_command=$(cat "$CASE_DIR/status-command")
    status_output=$(sh -lc "$status_command") || return 1
    assert_eq '☕' "$status_output" "generated tab-bar command did not show coffee" || return 1

    # Also verify shell quoting for unusual but legal paths.
    quoted_root="$CASE_DIR/a'b"
    quoted_state="$CASE_DIR/s't"
    mkdir -p "$quoted_root/bin" "$quoted_state"
    HERDR_PLUGIN_ROOT="$quoted_root" HERDR_PLUGIN_STATE_DIR="$quoted_state" \
        sh "$ROOT/scripts/status-hook.sh" > "$CASE_DIR/quoted-hook.txt" || return 1
    quoted_snippet=$(grep '^{ type = "command"' "$CASE_DIR/quoted-hook.txt") || return 1
    printf '[ui]\ntab_bar_right = [\n%s\n]\n' "$quoted_snippet" > "$CASE_DIR/quoted.toml"
    python3 - "$CASE_DIR/quoted.toml" <<'PY_QUOTED'
import sys, tomllib
with open(sys.argv[1], 'rb') as f:
    tomllib.load(f)
PY_QUOTED
}

test_shell_syntax_and_manifest() {
    for file in "$ROOT"/scripts/*.sh "$ROOT/bin/status-indicator"; do
        sh -n "$file" || return 1
    done
    python3 - "$ROOT/herdr-plugin.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as f:
    data = tomllib.load(f)
assert data['id'] == 'me.caffeinate'
assert data['platforms'] == ['macos']
assert data['min_herdr_version'] == '0.8.2'
events = {e['on'] for e in data['events']}
required = {'pane.agent_status_changed', 'pane.agent_detected', 'pane.exited', 'pane.closed', 'pane.created'}
assert required <= events
actions = {a['id'] for a in data['actions']}
assert actions == {'status', 'reconcile', 'status-hook'}
PY
}

run_test 'start + duplicate events' test_start_and_duplicate
run_test 'multiple agents' test_multiple_agents
run_test '30-second grace semantics' test_grace_release
run_test 'resume cancels grace' test_resume_cancels_grace
run_test 'stale timer generation' test_stale_generation_cannot_release
run_test 'query failure preserves assertion' test_query_failure_preserves_assertion
run_test 'timeout query failure preserves assertion' test_timeout_query_failure_preserves_assertion
run_test 'stale pid safety' test_stale_pid_replaced_safely
run_test 'coffee indicator' test_status_indicator
run_test 'session isolation' test_session_isolation
run_test 'status hookup stays small' test_status_hook_is_small_helper
run_test 'shell syntax + manifest' test_shell_syntax_and_manifest

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
