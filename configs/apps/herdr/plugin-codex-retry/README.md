# Codex Capacity Retry

Local Herdr plug-in `me.codex-retry`. When an idle Codex pane shows
“Selected model is at capacity. Please try a different model.”, wait 30 seconds
and submit the literal prompt `go` to that pane. The square/error icon is
optional, and the message can wrap across lines. Detection runs every two
seconds, so submission normally occurs 30–32 seconds after the error appears.

Each pane has its own timer. Before sending, the plug-in rechecks the error,
empty prompt, session identity, lifecycle sequence, and foreground process.
Working, blocked, unknown, closed, suspended, or replaced agents receive no
input. Resuming the agent or typing another prompt cancels the pending retry.
Other errors and normal completions do not trigger it.

One retry is allowed per stopped turn. A new turn that fails again starts a
fresh 30-second timer, with no overall attempt limit. Attempts are recorded
before submission so a lost API reply or watcher restart cannot duplicate a
prompt for the same failure. There is a small unavoidable race between the
last state check and Herdr accepting the prompt; Herdr rejects blocked agents
itself but has no atomic conditional-prompt API.

Startup and pane events ensure a single background watcher per Herdr socket.
It stops when the plug-in is disabled/unlinked or the server socket disappears
or is replaced. It uses Python's standard library and the adjacent
`../herdr_api.py`; no Codex hooks or Codex database access are needed.

`../post.sh` links the plug-in during normal setup. To activate manually:

```sh
herdr plugin link ~/Developer/jsc/me.sh/configs/apps/herdr/plugin-codex-retry
herdr config check
herdr server reload-config
herdr plugin action invoke me.codex-retry.start
```

To inspect or disable it:

```sh
herdr plugin action invoke me.codex-retry.status
herdr plugin disable me.codex-retry
```

Watcher logs, pending timers, and submission history live under
`$HERDR_PLUGIN_STATE_DIR/sessions/<socket-hash>/` (`watcher.log`, `status.json`,
and `attempted.json`). Herdr supplies the state directory to the plug-in.

Run the timer, cancellation, deduplication, and socket integration tests:

```sh
/usr/bin/python3 -m unittest discover -s configs/apps/herdr/plugin-codex-retry/tests
```
