#!/usr/bin/env python3
"""Active-tab-title plugin handler: mirror the focused pane's title into its tab.

Event-driven, no daemon — same shape as active_cwd_on_event.py. Herdr shows
agent/pane labels only on split-pane borders, so a single-pane tab hides the
title entirely; this renames tabs to their driving pane's label (pane.label,
else the tab number, so a stale pane title never lingers).

Driving pane per tab: the focused pane if the tab holds it, else the only
pane of a single-pane tab, else skip (multi-pane background tabs are
ambiguous). Every event re-syncs the focused tab plus every tab we already
manage, which covers the close-the-focused-pane case: herdr may fire no
pane.focused for the replacement, but the tab stays managed so its label
still converges on pane.exited.

Only the focused tab is taken over; background tabs are only corrected once
managed. Manual tab renames win until the driving pane changes: state tracks
the last label we set per tab, so "current != what we set and != what we
want" means the user renamed it.

Handlers must be short-lived (herdr caps concurrent plugin commands at 32):
non-blocking lock, one reconcile pass, exit. All state diffs are idempotent,
so dropped or duplicate spawns are harmless.
"""

from __future__ import annotations

import fcntl
import json
import os
import socket
import sys
import time

SOURCE = "me.active-tab-title"
STATE_VERSION = 2


def log(message: str) -> None:
    print(time.strftime("%Y-%m-%dT%H:%M:%S"), message, flush=True)


def socket_path() -> str:
    return os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser(
        "~/.config/herdr/herdr.sock"
    )


def state_path() -> str:
    base = os.environ.get("HERDR_PLUGIN_STATE_DIR") or "/tmp"
    return os.path.join(base, "active-tab-title-state.json")


def load_state(path: str) -> dict:
    try:
        with open(path) as f:
            state = json.load(f)
        if state.get("version") == STATE_VERSION:
            return state
    except (OSError, ValueError):
        pass
    return {"version": STATE_VERSION, "tabs": {}}


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


def pane_title(pane: dict | None) -> str | None:
    if pane is None:
        return None
    return pane.get("label") or None


def driving_pane(panes: list, tab_id: str) -> dict | None:
    in_tab = [p for p in panes if p.get("tab_id") == tab_id]
    focused = next((p for p in in_tab if p.get("focused")), None)
    if focused:
        return focused
    if len(in_tab) == 1:
        return in_tab[0]
    return None


def sync_tab(sock: str, state_file: str, state: dict, tab: dict, panes: list) -> bool:
    """Converge one tab's label; returns True if state changed."""
    tab_id = tab["tab_id"]
    book = state["tabs"]
    entry = book.get(tab_id)
    driver = driving_pane(panes, tab_id)

    if entry is not None and entry.get("manual"):
        if driver and driver["pane_id"] != entry["manual"]:
            entry["manual"] = None  # driving pane moved on; resume mirroring
        else:
            return False

    current = tab.get("label")
    desired = pane_title(driver)

    if desired is None:
        # No pane label: if we own the label, fall back to the tab number so a
        # stale pane title never lingers. Unmanaged tabs (never taken over) are
        # left alone — that covers user-named tabs with plain shells.
        if entry is None:
            return False
        default = str(tab.get("number") or "1")
        if current != default and current == entry.get("set"):
            api(sock, "tab.rename", tab_id=tab_id, label=default)
            log(f"{tab_id}: released ({current!r} -> {default!r})")
        elif current != default:
            log(f"{tab_id}: released ({current!r}; left as-is)")
        del book[tab_id]
        return True

    if entry is None:
        entry = book[tab_id] = {"set": None, "manual": None}

    if current == desired:
        if entry.get("set") != desired:
            entry["set"] = desired
            return True
        return False

    if entry.get("set") is not None and current != entry.get("set"):
        # We owned the label but it changed under us: manual rename.
        entry["manual"] = driver["pane_id"] if driver else None
        if entry["manual"] is None:
            del book[tab_id]
        log(f"{tab_id}: manual rename {current!r}; backing off")
        return True

    api(sock, "tab.rename", tab_id=tab_id, label=desired)
    entry["set"] = desired
    log(f"{tab_id}: {current!r} -> {desired!r}")
    return True


def main() -> int:
    sock = socket_path()
    state_file = state_path()
    lock_path = state_file + ".lock"
    os.makedirs(os.path.dirname(state_file), exist_ok=True)

    with open(lock_path, "w") as lock_file:
        try:
            fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            return 0  # another instance is reconciling; it sees this event too
        try:
            panes = api(sock, "pane.list")["panes"]
            tabs = {t["tab_id"]: t for t in api(sock, "tab.list")["tabs"]}
            state = load_state(state_file)

            focused = next((p for p in panes if p.get("focused")), None)
            focused_tab_id = focused["tab_id"] if focused else None
            changed = False

            if focused_tab_id in tabs:
                changed |= sync_tab(sock, state_file, state, tabs[focused_tab_id], panes)

            # Keep every already-managed tab correct — covers the focused pane
            # being closed (replacement may never get a pane.focused event)
            # and background single-pane tabs driven by pane.exited.
            for tab_id in list(state["tabs"]):
                if tab_id == focused_tab_id:
                    continue
                tab = tabs.get(tab_id)
                if tab is None:
                    del state["tabs"][tab_id]  # tab is gone
                    changed = True
                    continue
                changed |= sync_tab(sock, state_file, state, tab, panes)

            # Direct trigger (pt <pane_id>): take over the reporting pane's
            # background single-pane tab even if unmanaged — no ambiguity
            # about which pane owns the title.
            wanted = sys.argv[1] if len(sys.argv) > 1 else None
            if wanted and wanted != (focused["pane_id"] if focused else None):
                pane = next((p for p in panes if p["pane_id"] == wanted), None)
                if pane:
                    tab = tabs.get(pane["tab_id"])
                    if tab and tab != tabs.get(focused_tab_id) and tab.get("pane_count") == 1:
                        changed |= sync_tab(sock, state_file, state, tab, panes)

            if changed:
                save_state(state_file, state)
        except Exception as exc:
            log(f"error: {exc}")
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
