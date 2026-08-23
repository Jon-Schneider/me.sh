#!/usr/bin/env python3
"""Active-cwd plugin handler: mirror each space's focused-pane cwd into the sidebar.

Event-driven, no daemon: herdr spawns this script on pane events and once
at startup — same shape as even_on_event.py. Herdr tracks each pane's
working directory (foreground_cwd in pane.list) but 0.7.x fires no plugin
event when it changes, so cd coverage comes from a zsh chpwd hook that
spawns this script directly; focus/create/exit/move events do the rest:

  workspace.list  → per-space worktree info
  pane.list       → every pane, grouped here by workspace_id

The value is reported via workspace.report_metadata as tokens consumed by
[ui.sidebar.spaces] rows in config.toml:

  $active_cwd   ~-substituted path of the space's focused pane, e.g.
                ~/Developer/jsc/me.sh
  $active_repo  "Repo (worktree)" label for worktree-backed spaces; null
                for plain checkouts, which drops it from the row

Every space carries its own row persistently; a space with no known cwd yet
reports nothing, and rows whose tokens are all null simply don't render.

Handlers must be short-lived: herdr caps concurrent plugin commands (32)
and hard-drops spawns beyond the cap. v1 blocked on an exclusive lock while
sleeping out a defer window, so bursts serialized into minutes-long queues
that pinned all 32 slots — herdr then dropped new spawns outright and the
sidebar stopped updating. v2 takes a non-blocking lock instead: if another
instance is already reconciling, this one exits immediately (~30ms). The
winner sleeps one short settle to absorb same-instant bursts, then
reconciles ALL workspaces, retrying briefly while a fresh pane's shell is
still booting (no cwd yet). Desired state is always recomputed from live
server state and diffs are idempotent, so dropped or duplicate spawns are
harmless — the next successful run converges everything, and losers cost
one python startup each.
"""

from __future__ import annotations

import fcntl
import json
import os
import socket
import sys
import time

SETTLE_S = 0.04  # absorb same-instant event bursts once the lock is ours
MAX_PASSES = 4  # reconcile passes; stop early when nothing is still booting
PASS_GAP_S = 0.15  # grace between passes while a fresh pane's shell starts up
SOURCE = "me.active-cwd"
STATE_VERSION = 2
TOKEN_NAMES = ("active_cwd", "active_repo")
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
    return {"version": STATE_VERSION, "reported": {}}


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


def desired_tokens(sock: str, workspaces: list | None = None) -> tuple[dict[str, dict], list[str]]:
    """Per-workspace tokens, plus ids of workspaces whose panes exist but
    have no usable cwd yet (fresh panes whose shells haven't started)."""
    workspaces = workspaces if workspaces is not None else api(sock, "workspace.list")["workspaces"]
    panes = api(sock, "pane.list")["panes"]

    by_ws: dict[str, list] = {}
    for p in panes:
        by_ws.setdefault(p.get("workspace_id"), []).append(p)

    out: dict[str, dict] = {}
    booting: list[str] = []
    for ws in workspaces:
        wid = ws["workspace_id"]
        cands = by_ws.get(wid, [])
        if not cands:
            continue
        ordered = [p for p in cands if p.get("focused")] + [
            p for p in cands if not p.get("focused")
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
            booting.append(wid)  # shell not up yet; leave previous tokens untouched
            continue
        out[wid] = {"active_cwd": tilde(cwd), "active_repo": repo_token(ws, cwd)}
    return out, booting


def reconcile_once(sock: str, state_path: str) -> tuple[int, int]:
    """Report token diffs for all workspaces; returns (changes, booting)."""
    state = load_state(state_path)
    workspaces = api(sock, "workspace.list")["workspaces"]
    live_ids = {ws["workspace_id"] for ws in workspaces}

    changed = 0
    reported = state.setdefault("reported", {})
    # Spaces that vanished: drop our bookkeeping (their metadata died with them).
    for stale_id in [wid for wid in reported if wid not in live_ids]:
        del reported[stale_id]
        changed += 1

    tokens, booting = desired_tokens(sock, workspaces)
    for wid, ws_tokens in tokens.items():
        if reported.get(wid) != ws_tokens:
            payload = {name: None for name in TOKEN_NAMES}
            payload.update(ws_tokens)
            api(
                sock,
                "workspace.report_metadata",
                workspace_id=wid,
                source=SOURCE,
                tokens=payload,
            )
            reported[wid] = ws_tokens
            changed += 1

    if changed:
        save_state(state_path, state)
        log(f"reconciled {changed} workspace(s): {json.dumps(reported)}")
    return changed, len(booting)


def main() -> int:
    sock = socket_path()
    state_dir_path = state_dir()
    state_path = os.path.join(state_dir_path, "state.json")
    lock_path = state_path + ".lock"
    os.makedirs(state_dir_path, exist_ok=True)

    with open(lock_path, "w") as lock_file:
        try:
            fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            return 0  # another instance is reconciling right now; it sees this event too

        time.sleep(SETTLE_S)
        # A just-created split pane has no cwd until its shell comes up and
        # herdr's tracking sees it; keep reconciling briefly so its row lands
        # without waiting for the next event. Bounded, so the worst case
        # occupies one process slot for ~MAX_PASSES * PASS_GAP_S.
        for _ in range(MAX_PASSES):
            _, booting = reconcile_once(sock, state_path)
            if booting == 0:
                break
            time.sleep(PASS_GAP_S)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
