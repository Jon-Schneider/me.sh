#!/usr/bin/env python3
"""Even out Herdr split panes.

Herdr halves the source pane on split and collapses the containing split
on close without redistributing space, so three panes end up 50/25/25.
This script wraps pane split/close and then rebalances every split in
the focused tab so leaves sharing an axis get equal shares, preserving
the existing pane arrangement (no panes are created or killed here).

Usage:
  even_panes.py split <right|down> [--no-focus]   Split the focused pane, even out
  even_panes.py close                Close the focused pane, even out what remains
  even_panes.py even                 Just even out the focused tab
"""

from __future__ import annotations

import json
import os
import socket
import sys
import time

POLL_INTERVAL_S = 0.05
POLL_TIMEOUT_S = 3.0
RATIO_EPSILON = 0.002
API_TIMEOUT_S = 2.0


def socket_path() -> str:
    env = os.environ.get("HERDR_SOCKET")
    if env:
        return env
    cfg = os.environ.get("HERDR_CONFIG_PATH")
    base = os.path.dirname(cfg) if cfg else os.path.expanduser("~/.config/herdr")
    return os.path.join(base, "herdr.sock")


def api(sock_path: str, method: str, **params):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.settimeout(API_TIMEOUT_S)
        s.connect(sock_path)
        f = s.makefile("rwb")
        f.write((json.dumps({"id": "even", "method": method, "params": params}) + "\n").encode())
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


def leaf_count(node: dict) -> int:
    if node["type"] == "pane":
        return 1
    return leaf_count(node["first"]) + leaf_count(node["second"])


def axis_weight(node: dict, axis: str) -> int:
    """Leaf count a subtree spreads across along an axis ("right" or "down").

    Splits of the same axis divide their region further; anything else
    (a pane or an opposite-axis split group) occupies one full slot.
    """
    if node["type"] == "pane":
        return 1
    if node["direction"] == axis:
        return axis_weight(node["first"], axis) + axis_weight(node["second"], axis)
    return 1


def desired_ratios(node: dict, path: list[bool], out: list[tuple[list[bool], float]]) -> None:
    """Even ratio for every split node, addressed by first/second path."""
    if node["type"] != "split":
        return
    w1 = axis_weight(node["first"], node["direction"])
    w2 = axis_weight(node["second"], node["direction"])
    out.append((path, round(w1 / (w1 + w2), 6)))
    desired_ratios(node["first"], path + [False], out)
    desired_ratios(node["second"], path + [True], out)


def current_ratios(node: dict, path: list[bool], out: dict[tuple[bool, ...], float]) -> None:
    if node["type"] != "split":
        return
    out[tuple(path)] = node["ratio"]
    current_ratios(node["first"], path + [False], out)
    current_ratios(node["second"], path + [True], out)


def export_layout(sock: str, tab_id: str) -> dict | None:
    try:
        return api(sock, "layout.export", tab_id=tab_id).get("layout")
    except RuntimeError as error:
        # Tab gone (e.g. its last pane was closed): nothing to rebalance.
        print(f"even_panes: {error}", file=sys.stderr)
        return None


def wait_for_panes(sock: str, tab_id: str, expect: int, compare) -> dict | None:
    deadline = time.monotonic() + POLL_TIMEOUT_S
    layout = None
    while time.monotonic() < deadline:
        layout = export_layout(sock, tab_id)
        if layout is None:
            return None
        count = leaf_count(layout["root"])
        if compare(count, expect):
            return layout
        time.sleep(POLL_INTERVAL_S)
    return layout


def even_tab(sock: str, tab_id: str) -> None:
    layout = export_layout(sock, tab_id)
    if layout is None:
        return
    if layout.get("zoomed"):
        print("even_panes: tab is zoomed, skipping")
        return
    root = layout["root"]
    if root["type"] == "pane":
        return

    targets: list[tuple[list[bool], float]] = []
    desired_ratios(root, [], targets)
    current: dict[tuple[bool, ...], float] = {}
    current_ratios(root, [], current)

    for path, ratio in targets:
        if abs(current.get(tuple(path), -1.0) - ratio) <= RATIO_EPSILON:
            continue
        api(sock, "layout.set_split_ratio", tab_id=tab_id, path=path, ratio=ratio)


def focused_pane(sock: str) -> dict:
    pane = api(sock, "pane.current").get("pane")
    if not pane:
        raise RuntimeError("no focused pane")
    return pane


def do_split(sock: str, direction: str, focus: bool = True) -> None:
    if direction not in {"right", "down"}:
        raise RuntimeError(f"unsupported split direction: {direction}")
    pane = focused_pane(sock)
    tab_id = pane["tab_id"]
    before = leaf_count(export_layout(sock, tab_id)["root"])
    api(sock, "pane.split", target_pane_id=pane["pane_id"], direction=direction, focus=focus)
    wait_for_panes(sock, tab_id, before + 1, lambda n, e: n >= e)
    even_tab(sock, tab_id)


def do_close(sock: str) -> None:
    pane = focused_pane(sock)
    tab_id = pane["tab_id"]
    before = leaf_count(export_layout(sock, tab_id)["root"])
    api(sock, "pane.close", pane_id=pane["pane_id"])
    layout = wait_for_panes(sock, tab_id, before - 1, lambda n, e: n <= e)
    if layout is not None:
        even_tab(sock, tab_id)


def main(argv: list[str]) -> int:
    sock = socket_path()
    command = argv[1] if len(argv) > 1 else "even"
    try:
        if command == "split":
            if len(argv) < 3:
                raise RuntimeError("usage: even_panes.py split <right|down> [--no-focus]")
            do_split(sock, argv[2], focus="--no-focus" not in argv[3:])
        elif command == "close":
            do_close(sock)
        elif command == "even":
            even_tab(sock, focused_pane(sock)["tab_id"])
        else:
            raise RuntimeError(f"unknown command: {command}")
    except RuntimeError as error:
        print(f"even_panes: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"even_panes: cannot reach Herdr server socket: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
