# Herdr Caffeinate Plugin — Implementation Plan

## Goal

Build a macOS-only Herdr plugin that prevents **idle system sleep** while any Herdr-managed agent is actively `working`.

The plugin should:

- be driven by Herdr lifecycle/status events
- avoid continuous Herdr polling
- support multiple simultaneous agents and multiple Herdr sessions
- keep the Mac awake for 30 seconds after the final agent stops working
- cancel pending release immediately if new work begins
- allow display sleep normally
- expose an optional persistent `☕` in Herdr's right-side tab-bar status area using one small command helper
- fail conservatively: uncertainty should preserve an existing wake assertion


## Core behavior

```text
any agent working
        ↓
   caffeinate -i
        ↓
       ☕
        ↓
last agent stops working
        ↓
30-second grace period
        ↓
final Herdr state check
    ↓              ↓
still idle      working again
    ↓              ↓
release          keep awake
```

The `☕` represents the actual sleep assertion, so it remains visible during the 30-second grace period.

## Herdr hooks

Register:

- startup
- `pane.agent_status_changed`
- `pane.agent_detected`
- `pane.exited`
- `pane.closed`
- `pane.created` as a cheap recovery trigger

Every hook runs the same `reconcile.sh` path.

Events are only triggers. They do not increment/decrement an internal working-agent count.

## Reconciliation

On each hook:

1. Acquire the session lock.
2. Run `HERDR_BIN_PATH agent list`.
3. If the query fails, leave wake state unchanged.
4. If any agent is `working`:
   - invalidate/cancel the grace timer
   - ensure one `caffeinate -i` process exists
   - publish `assertion-state = awake`
5. If no agent is working:
   - if caffeinate is active, ensure one 30-second grace timer exists
   - otherwise publish `assertion-state = sleepable`
6. Release the lock.

The Herdr query happens under the lock so an older event cannot apply stale state after a newer event has already reconciled.

## Multiple Herdr sessions

`HERDR_PLUGIN_STATE_DIR` is global to the plugin while Herdr agent state is per server/socket. Therefore runtime state must be session-scoped.

Compute a stable key from `HERDR_SOCKET_PATH` and use:

```text
$HERDR_PLUGIN_STATE_DIR/sessions/<socket-key>/
```

Each session owns its own:

```text
caffeinate.pid
idle-timer.pid
idle-generation
assertion-state
lock
```

If two named Herdr sessions both have working agents, each may hold its own caffeinate assertion. Releasing one does not affect the other.

## Grace timer

When the final working agent stops:

1. Keep caffeinate active.
2. Increment `idle-generation`.
3. Launch one `idle-timeout.sh <generation>` process.
4. Store its PID.

The timer sleeps for 30 seconds without holding the lock.

When it wakes:

1. Acquire the session lock.
2. Verify its generation is still current.
3. Run one final `herdr agent list`.
4. If any agent is working, keep caffeinate.
5. If none are working, stop caffeinate and publish `sleepable`.
6. If the query fails, preserve caffeinate and wait for a future Herdr event/manual reconcile.

Generation invalidation prevents a stale timer from releasing a newer assertion.

## Process safety

Never trust PID files alone.

For caffeinate and the grace timer:

- require a numeric PID
- check `kill -0`
- inspect `ps -p PID -o command=`
- verify the command matches the expected process before killing it

This avoids acting on an unrelated recycled PID.

## Locking

Use a small per-session lock file acquired with POSIX shell noclobber semantics.

State-changing operations are serialized, but the 30-second sleep itself is never inside the critical section.

## Wake mechanism

Use:

```bash
/usr/bin/caffeinate -i
```

This prevents idle system sleep while allowing display sleep. It requires no sudo and does not modify `pmset` settings.

## Optional `☕` status hookup

Do not mutate `~/.config/herdr/config.toml` automatically.

Provide a `status-hook` plugin action that prints one `ui.tab_bar_right` command entry. The entry invokes a tiny `bin/status-indicator` helper with the concrete plugin state root.

The helper:

- scans session-scoped assertion state
- verifies at least one corresponding caffeinate PID is alive
- prints `☕` if so
- otherwise prints nothing
- never calls `herdr agent list`

Example shape:

```toml
[ui]
tab_bar_right = [
  { type = "command", command = "'/path/to/plugin/bin/status-indicator' '/path/to/state'", interval_seconds = 5, timeout_seconds = 1 },
]
```

If this cannot remain a single small Herdr config helper, omit the indicator rather than adding another service or configuration layer.

## Plugin actions

Provide:

- `status` — show current session assertion/grace/agent state
- `reconcile` — force one reconciliation
- `status-hook` — print the optional tab-bar config entry

## Repository layout

```text
herdr-caffeinate/
├── herdr-plugin.toml
├── README.md
├── PLAN.md
├── bin/
│   └── status-indicator
├── scripts/
│   ├── common.sh
│   ├── reconcile.sh
│   ├── idle-timeout.sh
│   ├── status.sh
│   └── status-hook.sh
└── tests/
    └── run.sh
```

## Tests

Automate at least:

1. first working agent starts one caffeinate process
2. duplicate working events do not start duplicates
3. additional agents share the assertion
4. last agent becoming idle starts one grace timer
5. assertion remains alive during grace
6. grace expiration releases assertion after a final idle check
7. work resuming during grace cancels release
8. stale timer generation cannot release assertion
9. Herdr query failure while active preserves the assertion
10. Herdr query failure at grace timeout preserves the assertion
11. stale PID files are cleaned safely
12. optional status indicator shows `☕` only for a live assertion
13. separate Herdr sessions have isolated runtime state
14. manifest parses and shell scripts pass syntax checks

## Definition of done

- Wake behavior is event-driven.
- No continuous Herdr polling exists.
- Exactly one assertion exists per active Herdr session.
- The final idle transition has a 30-second grace period.
- Resumed work cannot be released by an old timer.
- Herdr query failures never cause an unsafe release.
- Display sleep remains allowed.
- No sudo, `pmset`, or LaunchAgent.
- Optional `☕` hookup requires only one small `tab_bar_right` command entry.
