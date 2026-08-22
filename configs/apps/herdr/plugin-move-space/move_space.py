#!/usr/bin/env python3
"""Space Mover plugin entrypoint: move the focused space left/right.

Registered as plugin actions (move-left / move-right) and bound to
Shift+Left / Shift+Right through [keys.command] in config.toml:

    herdr plugin action invoke move-left
    herdr plugin action invoke move-right

Inside tmux those keys never reach Herdr (tmux consumes them), so
configs/apps/tmux/tmux-app-key detects a Herdr-owned pane and invokes the
same actions via the herdr CLI.

The focused space swaps one slot sideways in the sidebar order. Spaces
belonging to the same worktree repo (parent checkout + linked worktrees)
form a contiguous block and move together, matching native drag behavior.
Sidebar edges are no-ops.
"""

from __future__ import annotations

import fcntl
import json
import os
import socket
import sys

API_TIMEOUT_S = 2.0
LOCK_PATH = os.path.expanduser("~/.config/herdr/space-mover.lock")


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def socket_path() -> str:
    return os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser(
        "~/.config/herdr/herdr.sock"
    )


def api(sock_path: str, method: str, **params):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.settimeout(API_TIMEOUT_S)
        s.connect(sock_path)
        f = s.makefile("rwb")
        f.write((json.dumps({"id": "space-mover", "method": method, "params": params}) + "\n").encode())
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


def blocks_in_order(workspaces: list[dict]) -> list[list[str]]:
    """Group sidebar order into movable blocks.

    Adjacent spaces sharing a worktree repo_key form one block; plain spaces
    are singleton blocks.
    """
    blocks: list[tuple[str | None, list[str]]] = []
    for ws in workspaces:
        repo_key = (ws.get("worktree") or {}).get("repo_key")
        if repo_key and blocks and blocks[-1][0] == repo_key:
            blocks[-1][1].append(ws["workspace_id"])
        else:
            blocks.append((repo_key, [ws["workspace_id"]]))
    return [ids for _, ids in blocks]


def move_space(sock_path: str, direction: str) -> int:
    result = api(sock_path, "workspace.list")
    workspaces = result.get("workspaces", [])
    ids = [ws["workspace_id"] for ws in workspaces]
    focused = next(
        (ws["workspace_id"] for ws in workspaces if ws.get("focused")), None
    )
    if not focused:
        log("space-mover: Herdr has no focused workspace")
        return 1

    blocks = blocks_in_order(workspaces)
    block_index = next(
        (i for i, block in enumerate(blocks) if focused in block), None
    )
    if block_index is None:
        log(f"space-mover: focused workspace {focused} missing from list")
        return 1

    target_index = block_index - 1 if direction == "left" else block_index + 1
    if not 0 <= target_index < len(blocks):
        return 0  # already at the edge: nothing to do

    target_blocks = list(blocks)
    target_blocks[block_index], target_blocks[target_index] = (
        target_blocks[target_index],
        target_blocks[block_index],
    )

    # Realize the swapped order with minimal workspace.move calls.
    current = list(ids)
    for position, wanted in enumerate(wid for block in target_blocks for wid in block):
        at = current.index(wanted)
        if at == position:
            continue
        api(sock_path, "workspace.move", workspace_id=wanted, insert_index=position)
        current.pop(at)
        current.insert(position, wanted)

    label = next(ws.get("label") for ws in workspaces if ws["workspace_id"] == focused)
    log(f"space-mover: moved '{label}' {direction}")
    return 0


def main() -> int:
    direction = sys.argv[1] if len(sys.argv) > 1 else ""
    if direction not in ("left", "right"):
        log("usage: move_space.py <left|right>")
        return 64

    sock_path = socket_path()
    if not os.path.exists(sock_path):
        log(f"space-mover: no Herdr server socket at {sock_path}")
        return 1

    # Invocations are fire-and-forget; key repeat outruns them. Serialize so
    # held-down Shift+Arrow swaps step by step instead of interleaving.
    os.makedirs(os.path.dirname(LOCK_PATH), exist_ok=True)
    with open(LOCK_PATH, "w") as lock_file:
        fcntl.flock(lock_file, fcntl.LOCK_EX)
        try:
            return move_space(sock_path, direction)
        except (RuntimeError, OSError, ValueError, KeyError) as error:
            log(f"space-mover: {error}")
            return 1


if __name__ == "__main__":
    raise SystemExit(main())
