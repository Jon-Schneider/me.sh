#!/usr/bin/env python3
"""Zoom-toggle action: toggle pane zoom and immediately resync tab titles.

Herdr's `prefix+z` (and bare Cmd+Z) maps to `pane.zoom --toggle`, which does
not fire any plugin event when the focused pane is unchanged. Without this
action, the me.active-tab-title handler would only learn about the new zoom
state on the next unrelated event, leaving the ⛶ marker stale on a `--toggle`
unzoom that didn't shift focus.

Wrapping the zoom in an explicit action lets us chain the sync in the same
process: toggle the zoom, then run the standard reconcile so the tab title
converges to ⛶ (zoomed) or the per-pane status dots (unzoomed) within one
handler invocation.

Usage: invoked as a Herdr plugin action ("zoom-toggle"); never run by hand.
"""

from __future__ import annotations

import json
import os
import socket
import sys

SOURCE = "me.active-tab-title.zoom-toggle"


def socket_path() -> str:
    return os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser(
        "~/.config/herdr/herdr.sock"
    )


def api(sock_path: str, method: str, **params) -> dict:
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


def main() -> int:
    sock = socket_path()
    try:
        snapshot = api(sock, "session.snapshot")["snapshot"]
        focused_pane = snapshot.get("focused_pane_id")
        if not focused_pane:
            print("zoom-toggle: no focused pane", file=sys.stderr)
            return 1
        api(sock, "pane.zoom", pane_id=focused_pane, mode="toggle")
    except Exception as exc:
        print(f"zoom-toggle: {exc}", file=sys.stderr)
        return 1

    # Resync tab titles in-process so the ⛶ marker reflects the new zoom
    # state without waiting for the next unrelated event. The handler takes
    # the same non-blocking lock the event-driven path uses; if another
    # handler is already mid-sync it returns 0 and the next event will
    # converge.
    try:
        import active_tab_title_on_event

        return active_tab_title_on_event.main()
    except Exception as exc:
        print(f"zoom-toggle: resync failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
