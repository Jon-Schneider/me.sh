#!/usr/bin/env python3
"""Move the focused pane sideways through tabs/spaces of the same project."""

from __future__ import annotations

import fcntl
import functools
import json
import os
from pathlib import Path
import runpy
import socket
import subprocess
import sys


# Share the tab walker's sidebar projection (parent checkout before worktrees).
tab_sequence = runpy.run_path(str(Path(__file__).with_name("herdr-tab-step")))[
    "tab_sequence"
]


class API:
    def __init__(self, path: str):
        self.path = path

    def __call__(self, method: str, **params) -> dict:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(5)
            sock.connect(self.path)
            with sock.makefile("rwb") as stream:
                request = {"id": "pane-step", "method": method, "params": params}
                stream.write((json.dumps(request) + "\n").encode())
                stream.flush()
                response = json.loads(stream.readline())
        if "error" in response:
            raise RuntimeError(f"{method}: {response['error']}")
        return response["result"]


@functools.lru_cache(maxsize=128)
def directory_project(cwd: str) -> tuple[str, str]:
    path = os.path.realpath(os.path.expanduser(cwd))
    result = subprocess.run(
        ["git", "-C", path, "rev-parse", "--git-common-dir"],
        capture_output=True, text=True, check=False, timeout=3,
    )
    if result.returncode == 0:
        # The common git directory joins subdirectories and linked worktrees,
        # including ordinary spaces that Herdr hasn't tagged as worktrees.
        common = os.path.realpath(os.path.join(path, result.stdout.strip()))
        return "git", common
    return "directory", path


def workspace_project(workspace: dict, panes: list[dict]) -> tuple[str, str]:
    worktree = workspace.get("worktree") or {}
    cwd = worktree.get("checkout_path") or worktree.get("repo_root")
    if not cwd:
        members = [p for p in panes if p["workspace_id"] == workspace["workspace_id"]]
        active = [p for p in members if p["tab_id"] == workspace["active_tab_id"]]
        pane = next((p for p in members if p.get("focused")), None)
        pane = pane or next(iter(active or members), {})
        cwd = pane.get("foreground_cwd") or pane.get("cwd")
    # Sidebar tokens are display text: active_cwd can be truncated and must
    # never serve as a filesystem path or project identity.
    if cwd:
        return directory_project(cwd)
    if worktree.get("repo_key"):
        return "repo", worktree["repo_key"]
    # Unknown directories must never merge unrelated projects by label.
    return "workspace", workspace["workspace_id"]


def entry_pane(layout: dict, direction: str) -> str:
    """Enter the previous tab on the right, or the next tab on the left."""
    panes = layout["panes"]
    if direction == "left":
        target = min(panes, key=lambda p: (-(p["rect"]["x"] + p["rect"]["width"]), p["rect"]["y"]))
    else:
        target = min(panes, key=lambda p: (p["rect"]["x"], p["rect"]["y"]))
    return target["pane_id"]


def move(api, direction: str) -> None:
    # Read live focus after acquiring the lock. Key-repeat commands inherit
    # invocation-time IDs, which become stale as earlier commands move panes.
    panes = api("pane.list")["panes"]
    source = next((p for p in panes if p.get("focused")), None)
    if source is None:
        raise RuntimeError("Herdr has no focused pane")
    pane_id = source["pane_id"]
    neighbor = api("pane.neighbor", pane_id=pane_id, direction=direction)["neighbor"]
    if neighbor["layout"]["zoomed"]:
        api("pane.zoom", pane_id=pane_id, mode="off")
        neighbor = api("pane.neighbor", pane_id=pane_id, direction=direction)["neighbor"]
    if neighbor.get("neighbor_pane_id"):
        api("pane.swap", source_pane_id=pane_id, target_pane_id=neighbor["neighbor_pane_id"])
        return

    workspaces = api("workspace.list")["workspaces"]
    current = next(w for w in workspaces if w["workspace_id"] == source["workspace_id"])
    project = workspace_project(current, panes)
    group = [w for w in workspaces if workspace_project(w, panes) == project]
    tabs = api("tab.list")["tabs"]
    sequence = tab_sequence(group, tabs)
    index = sequence.index(source["tab_id"]) + (-1 if direction == "left" else 1)

    if 0 <= index < len(sequence):
        target_tab = sequence[index]
        target_member = next(p for p in panes if p["tab_id"] == target_tab)
        layout = api("pane.layout", pane_id=target_member["pane_id"])["layout"]
        if layout["zoomed"]:
            api("pane.zoom", pane_id=target_member["pane_id"], mode="off")
            layout = api("pane.layout", pane_id=target_member["pane_id"])["layout"]
        target = entry_pane(layout, direction)
        result = api(
            "pane.move", pane_id=pane_id, focus=True,
            destination={"type": "tab", "tab_id": target_tab, "target_pane_id": target, "split": "right"},
        )["move_result"]
        if not result["changed"]:
            raise RuntimeError(f"pane move did not change layout: {result.get('reason')}")
        if direction == "right":
            # Herdr only inserts right/down. Swap the new right split into
            # the left slot to enter the next tab from its left edge.
            api("pane.swap", source_pane_id=result["pane"]["pane_id"], target_pane_id=target)
        return

    # Moving directly creates no placeholder shell, and also works when the
    # source is its tab's/workspace's last pane. Herdr closes empty containers.
    before = [w["workspace_id"] for w in workspaces]
    group_ids = {w["workspace_id"] for w in group}
    positions = [i for i, wid in enumerate(before) if wid in group_ids]
    boundary = min(positions) if direction == "left" else max(positions) + 1
    result = api(
        "pane.move", pane_id=pane_id, focus=True,
        destination={"type": "new_workspace", "label": current["label"]},
    )["move_result"]
    if not result["changed"]:
        raise RuntimeError(f"pane move did not change layout: {result.get('reason')}")
    created = result["pane"]["workspace_id"]
    remaining = api("workspace.list")["workspaces"]
    remaining_ids = {w["workspace_id"] for w in remaining}
    # Account for a source workspace disappearing during the move.
    insert_index = sum(wid in remaining_ids for wid in before[:boundary])
    api("workspace.move", workspace_id=created, insert_index=insert_index)


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in {"left", "right"}:
        print("usage: pane-step.py left|right", file=sys.stderr)
        return 64
    path = os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser("~/.config/herdr/herdr.sock")
    # One lock per session, shared by left/right, so held keys advance using
    # the result of the previous move instead of racing its topology changes.
    try:
        with open(path + ".pane-step.lock", "a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            move(API(path), sys.argv[1])
    except (OSError, RuntimeError, ValueError, KeyError, StopIteration, subprocess.TimeoutExpired) as error:
        print(f"pane-step: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
