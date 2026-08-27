#!/usr/bin/env python3
"""Active-tab-title plugin handler: add agent status and mirror pane titles.

Event-driven, no daemon. Each agent pane contributes Herdr's monochrome symbol
to its tab: blocked ×, working ●, done ✓, idle ○, unknown ·. Split tabs show
one spaced symbol per agent in pane-list order.

The focused pane's label is mirrored into its tab title. Background single-pane
tabs use their only pane; background split tabs retain their last base title.
Manual tab renames become the new base title and retain the status symbol.

Handlers take a non-blocking lock, reconcile every tab once, and exit. State
diffs are idempotent, so dropped or duplicate spawns converge on the next event.
"""

from __future__ import annotations

import fcntl
import json
import os
import socket
import time

SOURCE = "me.active-tab-title"
STATE_VERSION = 3
STATUS_SYMBOLS = {
    "blocked": "×",
    "working": "●",
    "done": "✓",
    "idle": "○",
    "unknown": "·",
}
STATUS_SYMBOL_SET = frozenset((*STATUS_SYMBOLS.values(), "◐", "◒", "•"))


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


def strip_status_prefix(label: str) -> str:
    index = 0
    found_symbol = False
    while index < len(label):
        if label[index] in STATUS_SYMBOL_SET:
            found_symbol = True
        elif label[index] != " " or not found_symbol:
            break
        index += 1
    return label[index:] if found_symbol else label


def status_symbols(tab: dict, panes: list) -> str:
    return "  ".join(
        STATUS_SYMBOLS.get(pane.get("agent_status"), STATUS_SYMBOLS["unknown"])
        for pane in panes
        if pane.get("tab_id") == tab["tab_id"] and pane.get("agent")
    )


def driving_pane(panes: list, tab_id: str) -> dict | None:
    in_tab = [p for p in panes if p.get("tab_id") == tab_id]
    focused = next((p for p in in_tab if p.get("focused")), None)
    if focused:
        return focused
    if len(in_tab) == 1:
        return in_tab[0]
    return None


def sync_tab(sock: str, state: dict, tab: dict, panes: list) -> bool:
    """Converge one tab's label; returns True if state changed."""
    tab_id = tab["tab_id"]
    book = state["tabs"]
    entry = book.get(tab_id)
    driver = driving_pane(panes, tab_id)
    current = tab.get("label") or str(tab.get("number") or "1")
    symbols = status_symbols(tab, panes)
    title = pane_title(driver)

    if entry is None and not symbols and title is None:
        return False
    if entry is None:
        entry = book[tab_id] = {
            "base": title or strip_status_prefix(current),
            "driver": driver["pane_id"] if driver else None,
            "manual": None,
            "set": None,
        }

    changed = False
    if entry.get("set") is not None and current != entry["set"]:
        entry["base"] = strip_status_prefix(current)
        entry["manual"] = driver["pane_id"] if driver else True
        log(f"{tab_id}: manual base title {entry['base']!r}")
        changed = True

    previous_driver = entry.get("driver")
    current_driver = driver["pane_id"] if driver else None
    manual_driver = entry.get("manual")
    if manual_driver is True and driver:
        entry["manual"] = current_driver
    elif manual_driver and driver and current_driver != manual_driver:
        entry["manual"] = None

    if entry.get("manual") is None:
        if title is not None:
            entry["base"] = title
        elif driver and previous_driver and current_driver != previous_driver:
            entry["base"] = str(tab.get("number") or "1")
    entry["driver"] = current_driver

    base = entry.get("base") or str(tab.get("number") or "1")
    desired = f"{symbols} {base}" if symbols else base
    if current != desired:
        api(sock, "tab.rename", tab_id=tab_id, label=desired)
        log(f"{tab_id}: {current!r} -> {desired!r}")
        changed = True
    if entry.get("set") != desired:
        entry["set"] = desired
        changed = True

    if not symbols and title is None:
        del book[tab_id]
        changed = True
    return changed


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

            changed = False

            for tab in tabs.values():
                changed |= sync_tab(sock, state, tab, panes)

            for tab_id in set(state["tabs"]) - set(tabs):
                del state["tabs"][tab_id]
                changed = True

            if changed:
                save_state(state_file, state)
        except Exception as exc:
            log(f"error: {exc}")
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
