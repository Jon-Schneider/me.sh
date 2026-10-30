"""Retry a stopped foreground Codex session 30 seconds after a known error."""

from __future__ import annotations

import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from herdr_api import api

PLUGIN_ID = "me.codex-retry"
DELAY = 30
POLL_SECONDS = 2
RETRYABLE_ERROR = re.compile(
    r"^[^\w\n›•\"'`]*Selected\s+model\s+is\s+at\s+capacity\."
    r"\s+Please\s+try\s+a\s+different\s+model\."
    # JSON is common in tool output, so require Codex's error marker here.
    r'|^[ \t]*■[ \t]*\{\s*"detail"\s*:\s*"Bad Request"\s*\}[ \t]*$',
    re.MULTILINE | re.IGNORECASE,
)
COMPOSER = re.compile(r"^[ \t]*›[ \t]*(.*?)[ \t]*$", re.MULTILINE)
SUBAGENT_COMPLETED = re.compile(
    r"^[ \t]*•[ \t]+Completed[ \t]+`/root(?:/[a-z0-9_]+)+`[ \t]*$",
    re.MULTILINE,
)


def retryable_error(text):
    """Require the last response to be the error and an empty Codex composer.

    Ignore the decoration before the error; whitespace includes terminal wraps.
    Anchoring at a line start excludes ordinary quoted errors and tool output.
    """
    matches = list(RETRYABLE_ERROR.finditer(text))
    if not matches:
        return False
    end = matches[-1].end()
    composers = list(COMPOSER.finditer(text[end:]))
    if not composers:
        return False
    composer = composers[-1]
    if composer.group(1) not in ("", "Ask Codex to do anything"):
        return False
    # A blank first line can still contain a typed continuation. The composer
    # is separated from the footer by a blank line in Codex's screen output.
    if not composer.group(1):
        following = text[end + composer.end():].splitlines()
        if len(following) > 1 and following[1].strip():
            return False
    tail = text[end:end + composer.start()]
    # Subagents can finish after the parent turn fails. Their completion
    # notices do not mean the parent resumed; actual responses still do.
    tail = SUBAGENT_COMPLETED.sub("", tail)
    # A new response, submitted prompt, error, or ongoing turn supersedes it.
    return not re.search(r"(?m)^[ \t]*[•›■]|\bWorking\s*\(", tail)


def identity(agent):
    session = agent.get("agent_session") or {}
    if (agent.get("agent") != "codex"
            or agent.get("agent_status") not in ("idle", "done")
            or session.get("agent") != "codex" or session.get("kind") != "id"
            or not session.get("value") or not agent.get("terminal_id")):
        return None
    # state_change_seq survives focus/seen changes but changes on a new turn.
    return [agent["terminal_id"], session["value"], agent["state_change_seq"]]


def foreground_codex(info):
    processes = info.get("foreground_processes") or []
    return any(Path(p.get("name") or "").name == "codex" for p in processes)


def state_dir():
    # A separate lock and history per server prevents named sessions colliding.
    socket_path = os.environ["HERDR_SOCKET_PATH"]
    key = hashlib.sha256(socket_path.encode()).hexdigest()[:16]
    root = Path(os.environ["HERDR_PLUGIN_STATE_DIR"])
    path = root / "sessions" / key
    path.mkdir(parents=True, exist_ok=True)
    return path


def save(path, value):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


class Monitor:
    def __init__(self, path, call=api, clock=time.monotonic):
        self.path, self.call, self.clock = path, call, clock
        self.pending = {}
        try:
            self.attempted = json.loads((path / "attempted.json").read_text())
        except FileNotFoundError:
            self.attempted = {}

    def screen_has_error(self, pane):
        return retryable_error(self.call(
            "pane.read", pane_id=pane, source="detection", lines=80
        )["read"]["text"])

    def step(self):
        agents = self.call("agent.list")["agents"]
        live = {a["pane_id"] for a in agents}
        self.attempted = {p: v for p, v in self.attempted.items() if p in live}
        pending = {}
        for agent in agents:
            pane = agent["pane_id"]
            token = identity(agent)
            if token is None or self.attempted.get(pane) == token:
                continue
            try:
                if not self.screen_has_error(pane):
                    continue
                old = self.pending.get(pane)
                candidate = old if old and old["identity"] == token else {
                    "identity": token, "since": self.clock()
                }
                if self.clock() - candidate["since"] < DELAY:
                    pending[pane] = candidate
                    continue
                # Read everything again at submission time. Never send to a
                # replacement agent, a shell, a suspended Codex, or a dialog.
                info = self.call("pane.process_info", pane_id=pane)["process_info"]
                if not foreground_codex(info):
                    continue
                if not self.screen_has_error(pane):
                    continue
                fresh = self.call("agent.get", target=pane)["agent"]
                if identity(fresh) != token:
                    continue
                # Persist before writing: a lost socket reply is ambiguous and
                # must never cause the same failure to receive a second go.
                self.attempted[pane] = token
                save(self.path / "attempted.json", self.attempted)
                self.call("agent.prompt", target=pane, text="go")
                print(time.strftime("%Y-%m-%dT%H:%M:%S"), pane,
                      "sent go after retryable Codex error", flush=True)
            except (OSError, ValueError, KeyError, RuntimeError) as error:
                # Unknown state cancels this timer; a later healthy observation
                # must start a fresh 30 seconds. Other panes remain independent.
                print(pane, str(error), file=sys.stderr, flush=True)
        self.pending = pending
        save(self.path / "status.json", {
            "pid": os.getpid(), "updated_at": time.time(),
            "pending": {p: {"session": v["identity"][1],
                            "seconds_remaining": max(0, DELAY - (self.clock() - v["since"]))}
                        for p, v in pending.items()},
            "attempted": self.attempted,
        })


def watch(path):
    with (path / "watcher.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        endpoint = Path(os.environ["HERDR_SOCKET_PATH"])
        socket_id = (endpoint.stat().st_dev, endpoint.stat().st_ino)
        monitor = Monitor(path)
        while True:
            try:
                stat = endpoint.stat()
                if (stat.st_dev, stat.st_ino) != socket_id:
                    return
                plugins = api("plugin.list", plugin_id=PLUGIN_ID)["plugins"]
                if not any(p["plugin_id"] == PLUGIN_ID and p["enabled"] for p in plugins):
                    return
                monitor.step()
            except (OSError, ValueError, KeyError, RuntimeError) as error:
                # The server owns the lifecycle. A later pane event or startup
                # relaunches the watcher if the connection disappears.
                print(str(error), file=sys.stderr, flush=True)
                return
            time.sleep(POLL_SECONDS)


def main():
    path = state_dir()
    if sys.argv[1:] == ["--watch"]:
        watch(path)
    elif sys.argv[1:] == ["--status"]:
        status = path / "status.json"
        print(status.read_text() if status.exists() else "Watcher has not run yet.")
    elif not sys.argv[1:]:
        # Herdr's event commands are short-lived. One detached worker per socket
        # handles timers and checks for errors even if no status event arrives.
        with (path / "watcher.lock").open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return
        with (path / "watcher.log").open("ab", buffering=0) as log:
            subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--watch"],
                             stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                             start_new_session=True, close_fds=True)
    else:
        raise SystemExit("usage: retry.py [--status]")


if __name__ == "__main__":
    main()
