# me.caffeinate

A small macOS-only Herdr 0.8.2+ plugin that prevents idle system sleep while any Herdr agent is `working`.

It is event-driven: Herdr lifecycle/status events trigger reconciliation, and there is no continuous agent polling. When the final working agent stops, the plugin keeps the wake assertion for 30 seconds before checking Herdr once more and releasing it.

## Behavior

- First working agent → starts one `/usr/bin/caffeinate -i`
- Additional working agents share that assertion
- Last working agent stops → starts a 30-second grace period
- New work during grace → cancels the pending release
- Grace expires → one final `herdr agent list`; release only if still idle
- Herdr query failure → preserve the current assertion rather than guessing idle
- Display sleep remains enabled
- No sudo, `pmset`, LaunchAgent, or resident polling monitor

Runtime state is scoped by `HERDR_SOCKET_PATH`, so multiple named Herdr sessions cannot release one another's assertions.

## Install

`configs/apps/herdr/post.sh` links this directory in place, alongside the other
`me.*` plugins in this repo. To pick up manifest changes by hand:

```bash
herdr plugin link ~/Developer/jsc/me.sh/configs/apps/herdr/plugin-caffeinate
```

Script edits need no re-link; only the manifest is read at link time.

## Actions

```bash
herdr plugin action invoke status --plugin me.caffeinate
herdr plugin action invoke reconcile --plugin me.caffeinate
herdr plugin action invoke status-hook --plugin me.caffeinate
```

`status` shows the current session's assertion, grace timer, and Herdr working state.

`reconcile` forces one immediate reconciliation.

`status-hook` prints the optional Herdr tab-bar configuration described below.

## Optional persistent ☕ indicator

Herdr plugins cannot currently register a native persistent status segment, but Herdr's `ui.tab_bar_right` supports command entries. The plugin includes a tiny status helper that reads only the plugin's local assertion state; it does **not** query Herdr agent state.

Run:

```bash
herdr plugin action invoke status-hook --plugin me.caffeinate
```

It prints one entry to add to your existing `[ui]` configuration, for example:

```toml
[ui]
tab_bar_right = [
  { type = "command", command = "'/path/to/plugin/bin/status-indicator' '/path/to/plugin/state'", interval_seconds = 5, timeout_seconds = 1 },
]
```

If the assertion is alive, the helper prints:

```text
☕
```

Otherwise it prints nothing, so Herdr hides the segment.

The indicator remains visible during the 30-second grace period because the Mac is still being held awake during that time.

The indicator is entirely optional; the wake behavior works without it.

## State model

```text
                       working detected
              ┌──────────────────────────┐
              │                          │
              ▼                          │
        ┌─────────────┐                  │
        │   WORKING   │                  │
        │ caffeinate  │                  │
        │     ☕      │                  │
        └──────┬──────┘                  │
               │                         │
       no working agents                 │
               ▼                         │
        ┌─────────────┐  work resumes    │
        │    GRACE    │──────────────────┘
        │ caffeinate  │
        │     ☕      │
        └──────┬──────┘
               │
          30 seconds
               │
        final agent check
               │
               ▼
        ┌─────────────┐
        │  SLEEPABLE  │
        │ no assertion│
        └─────────────┘
```

## Failure behavior

The plugin treats an unsuccessful Herdr query as unknown, not idle. It never releases an existing assertion because `herdr agent list` failed.

There is deliberately no supervisor polling the Herdr server. If Herdr itself crashes while the assertion is held, the `caffeinate` process can remain alive until Herdr starts again and a startup/pane event reconciles state, or until it is manually stopped. This favors accidental extra wakefulness over sleeping during potentially active work.

## Tests

Run:

```bash
./tests/run.sh
```

The test suite uses fake Herdr and caffeinate processes, so it can run without macOS. On macOS, manual verification can additionally use:

```bash
pgrep -af caffeinate
pmset -g assertions
```
