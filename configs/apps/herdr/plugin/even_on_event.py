#!/usr/bin/env python3
"""Even-panes plugin entrypoint: reconcile tab layouts after pane events.

Herdr spawns this script on pane.created / pane.closed / pane.moved events
and once at startup. State lives in HERDR_PLUGIN_STATE_DIR so consecutive
invocations can tell structural changes apart from manual resizes:

- First run (startup or first event): record every tab's tiled-pane count
  as the baseline WITHOUT touching layouts, so restored sessions keep
  their saved geometry.
- Every later run: any known tab whose pane membership changed gets its
  split tree evened out (equal shares per axis). Tabs seen for
  the first time already holding >=2 panes are evened too — they were
  created and split within one event burst.

Tabs whose pane membership is unchanged since the previous invocation are
counted from pane.list alone (no layout.export round-trip); the shortcut
only applies when the stored count agrees with the list length, so popup
panes can never poison it.

A short settle delay plus an exclusive lock on the state file coalesces
event bursts: the first invocation reconciles everything it observes and
later ones find nothing to do.
"""

from __future__ import annotations

import fcntl
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from even_panes import (  # noqa: E402
    RATIO_EPSILON,
    api,
    current_ratios,
    desired_ratios,
    leaf_count,
)

STATE_VERSION = 2
SETTLE_S = 0.04


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
    return {"version": STATE_VERSION, "scanned": False, "tabs": {}}


def save_state(path: str, state: dict) -> None:
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, path)


def even_tab(sock: str, tab_id: str) -> bool:
    """Equalize all splits in a tab; returns True if anything changed."""
    layout = api(sock, "layout.export", tab_id=tab_id)["layout"]
    root = layout["root"]
    if root["type"] == "pane" or layout.get("zoomed"):
        return False

    targets: list[tuple[list[bool], float]] = []
    desired_ratios(root, [], targets)
    current: dict[tuple[bool, ...], float] = {}
    current_ratios(root, [], current)

    changed = 0
    for path, ratio in targets:
        if abs(current.get(tuple(path), -1.0) - ratio) <= RATIO_EPSILON:
            continue
        api(sock, "layout.set_split_ratio", tab_id=tab_id, path=path, ratio=ratio)
        changed += 1
    if changed:
        log(f"evened {changed} split(s) in tab {tab_id}")
    return changed > 0


def scan_counts(sock: str, previous: dict) -> dict[str, dict]:
    """Current per-tab state: tiled-pane count + pane-id membership.

    Tabs whose membership matches the previous invocation AND whose stored
    count equals the list length reuse the stored count without exporting.
    """
    panes = api(sock, "pane.list")["panes"]
    members: dict[str, list[str]] = {}
    for pane in panes:
        members.setdefault(pane["tab_id"], []).append(pane["pane_id"])

    result: dict[str, dict] = {}
    for tab_id in sorted(members):
        ids = sorted(members[tab_id])
        old = previous.get(tab_id) or {}
        if old.get("members") == ids and old.get("count") == len(ids):
            result[tab_id] = {"members": ids, "count": old["count"]}
            continue
        try:
            layout = api(sock, "layout.export", tab_id=tab_id)["layout"]
            result[tab_id] = {
                "members": ids,
                "count": leaf_count(layout["root"]),
            }
        except (RuntimeError, KeyError):
            # Tab closed mid-scan or transient relayout: skip this round.
            continue
    return result


def main() -> int:
    time.sleep(SETTLE_S)  # let event bursts finish before reconciling

    sock = socket_path()
    state_path = os.path.join(state_dir(), "state.json")
    lock_path = state_path + ".lock"
    os.makedirs(state_dir(), exist_ok=True)

    with open(lock_path, "w") as lock_file:
        fcntl.flock(lock_file, fcntl.LOCK_EX)
        state = load_state(state_path)
        scanned = state.get("scanned", False)
        counts = scan_counts(sock, state.get("tabs", {}))

        if not scanned:
            # Baseline only: never flatten restored sessions on first sight.
            mode = "startup" if os.environ.get("HERDR_PLUGIN_EVENT") == "startup" else "first event"
            log(f"baselining {len(counts)} tab(s) ({mode})")
        else:
            previous: dict = state.get("tabs", {})
            for tab_id, info in counts.items():
                old = previous.get(tab_id)
                old_count = old.get("count") if old else None
                if old is None:
                    if info["count"] >= 2:
                        even_tab(sock, tab_id)
                elif old_count != info["count"] and info["count"] >= 2:
                    even_tab(sock, tab_id)

        save_state(state_path, {"version": STATE_VERSION, "scanned": True, "tabs": counts})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
