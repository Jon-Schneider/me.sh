#!/usr/bin/env python3
"""Active-cwd plugin handler: mirror the focused pane's cwd into the sidebar.

Herdr spawns this script on pane/focus events and once at startup — same
shape as even_on_event.py, no daemon. Herdr tracks each pane's working
directory via shell OSC 7 and includes foreground_cwd in every pane.updated
event, so cd inside a focused pane reaches us like any other change:

  workspace.list  → focused space (+ its worktree info)
  pane.list       → that space's focused pane; fallback any pane

The value is reported via workspace.report_metadata as tokens consumed by
[ui.sidebar.spaces] rows in config.toml:

  $active_cwd   ~-substituted path, e.g. ~/Developer/jsc/me.sh
  $active_repo  "Repo (worktree)" for worktree-backed spaces; null for
                plain checkouts, which drops it from the row

Only the focused space ever carries tokens: when focus moves, previously
marked spaces are cleared so their extra row disappears.

pane.updated fires per revision bump (scroll, title, output), so bursts are
coalesced two ways: a short settle sleep up front, then an exclusive lock on
the state file — queued invocations recompute after the winner finishes and
exit silently when nothing changed. Reports are diffed against state, so a
no-op run costs two local socket reads.
"""

from __future__ import annotations

import fcntl
import json
import os
import socket
import sys
import time

SETTLE_S = 0.03
DEFER_S = 0.15  # min gap between handled runs; latecomers wait out the gap
SOURCE = "me.active-cwd"
STATE_VERSION = 1
WORKTREES_ROOT = os.path.expanduser(
    os.environ.get("HERDR_WORKTREES_ROOT") or "~/.herdr/worktrees"
)


def log(message: str) -> None:
    print(time.strftime("%Y-%m-%dT%H:%M:%S"), message, flush=True)


def socket_path() -> str:
    return os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser(
        "~/.config/herdr/herdr.sock"
    )


def state_dir() -> str:
    return os.environ.get("HERDR_PLUGIN_STATE_DIR") or "/tmp"


def load_state(path: str) -> dict:
    try:
        with open(path) as f:
            state = json.load(f)
        if state.get("version") == STATE_VERSION:
            return state
    except (OSError, ValueError):
        pass
    return {"version": STATE_VERSION, "reported": {}, "handled_at": 0.0}


def save_state(path: str, state: dict) -> None:
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, path)


def api(sock_path: str, method: str, **params):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.settimeout(2.0)
        s.connect(sock_path)
        f = s.makefile("rwb")
        f.write((json.dumps({"id": SOURCE, "method": method, "params": params}) + "\n").encode())
        f.flush()
        line = f.readline()
    finally:
        s.close()
    if not line:
        raise RuntimeError(f"{method}: empty response")
    resp = json.loads(line)
    if "error" in resp:
        raise RuntimeError(f"{method}: {resp['error'].get('message', resp['error'])}")
    return resp.get("result", {})


def tilde(path: str) -> str:
    home = os.path.expanduser("~")
    if path == home:
        return "~"
    if path.startswith(home + "/"):
        return "~" + path[len(home):]
    return path


def repo_token(workspace: dict, cwd: str | None) -> str | None:
    """'Repo (worktree)' label for worktree-backed spaces, else None.

    Prefers herdr's native per-workspace worktree metadata; falls back to a
    path check under the worktrees root (~/.herdr/worktrees/<Repo>/<Name>).
    """
    wt = workspace.get("worktree") or {}
    if wt:
        repo = wt.get("repo_key") or os.path.basename(wt.get("path", "").rstrip("/")) or None
        if not repo:
            return None
        label = wt.get("label")
        if label and label != repo:
            return f"{repo} ({label})"
        return repo

    if cwd:
        try:
            rel = os.path.relpath(cwd, WORKTREES_ROOT)
        except ValueError:
            return None
        parts = rel.split(os.sep)
        if len(parts) >= 2 and parts[0] not in ("..", "."):
            return f"{parts[0]} ({parts[1]})"
    return None


def desired_tokens(sock: str) -> tuple[str, dict | None]:
    """Tokens for the focused workspace, plus its id."""
    workspaces = api(sock, "workspace.list")["workspaces"]
    focused_ws = next((ws for ws in workspaces if ws.get("focused")), None)
    if focused_ws is None:
        return "", None
    wid = focused_ws["workspace_id"]

    panes = api(sock, "pane.list", workspace_id=wid)["panes"]
    ordered = [p for p in panes if p.get("focused")] + [
        p for p in panes if not p.get("focused")
    ]
    cwd = next(
        (
            p.get("foreground_cwd") or p.get("cwd")
            for p in ordered
            if p.get("foreground_cwd") or p.get("cwd")
        ),
        None,
    )
    if not cwd:
        return wid, None
    return wid, {"active_cwd": tilde(cwd), "active_repo": repo_token(focused_ws, cwd)}


def report(sock: str, workspace_id: str, tokens: dict | None) -> None:
    payload = {name: None for name in ("active_cwd", "active_repo")}
    if tokens:
        payload.update(tokens)
    api(
        sock,
        "workspace.report_metadata",
        workspace_id=workspace_id,
        source=SOURCE,
        tokens=payload,
    )


def main() -> int:
    time.sleep(SETTLE_S)

    sock = socket_path()
    state_dir_path = state_dir()
    state_path = os.path.join(state_dir_path, "state.json")
    lock_path = state_path + ".lock"
    os.makedirs(state_dir_path, exist_ok=True)

    with open(lock_path, "w") as lock_file:
        fcntl.flock(lock_file, fcntl.LOCK_EX)

        # Coalesce bursts: wait out the remaining gap, then compute once.
        state = load_state(state_path)
        since_last = time.monotonic() - state.get("handled_at", 0.0)
        if since_last < DEFER_S:
            time.sleep(DEFER_S - since_last)

        wid, tokens = desired_tokens(sock)

        changed = []

        # Focus moved / spaces closed: clear tokens we left behind.
        live_ids = {ws["workspace_id"] for ws in api(sock, "workspace.list")["workspaces"]}
        for stale_id in list(state.get("reported", {})):
            if stale_id != wid or stale_id not in live_ids:
                report(sock, stale_id, None)
                del state["reported"][stale_id]
                changed.append(f"cleared {stale_id}")

        if wid and state.get("reported", {}).get(wid) != tokens:
            report(sock, wid, tokens)
            state.setdefault("reported", {})[wid] = tokens
            changed.append(f"{wid}: {json.dumps(tokens)}")

        state["handled_at"] = time.monotonic()
        save_state(state_path, state)

        if changed:
            log("; ".join(changed))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
