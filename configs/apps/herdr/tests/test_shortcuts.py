"""Exercise shortcut entrypoints with a session socket and an unusable CLI."""

import json
import fcntl
import os
from pathlib import Path
import pty
import select
import socketserver
import struct
import subprocess
import tempfile
import termios
import threading
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ShortcutsTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="herdr-keys-", dir="/tmp")
        self.path = str(Path(self.directory.name) / "herdr.sock")
        self.calls = []
        self.apps = []
        self.agent = None
        self.process_info = None
        self.terminal_id = "term-original"
        self.pane_titles = {}
        self.tab_count = 1
        self.pane_count = 1
        self.fail_method = None
        self.workspaces = [
            {"workspace_id": "w1", "active_tab_id": "w1:t1", "focused": True},
            {"workspace_id": "w2", "active_tab_id": "w2:t1", "focused": False},
        ]
        self.tabs = [
            {"workspace_id": "w1", "tab_id": "w1:t1", "focused": True},
            {"workspace_id": "w1", "tab_id": "w1:t2", "focused": False},
            {"workspace_id": "w2", "tab_id": "w2:t1", "focused": False},
        ]
        fixture = self

        class Handler(socketserver.StreamRequestHandler):
            def handle(self):
                request = json.loads(self.rfile.readline())
                method = request["method"]
                fixture.calls.append((method, request["params"]))
                response = {"id": request["id"]}
                if method == fixture.fail_method:
                    response["error"] = {"code": "test_failure", "message": "query failed"}
                else:
                    response["result"] = fixture.result(method)
                self.wfile.write((json.dumps(response) + "\n").encode())

        self.server = socketserver.UnixStreamServer(self.path, Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, kwargs={"poll_interval": 0.01})
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.directory.cleanup()

    def result(self, method):
        if method == "workspace.list":
            return {"workspaces": self.workspaces}
        if method == "tab.list":
            return {"tabs": self.tabs}
        if method == "pane.process_info":
            return {"process_info": self.process_info if self.process_info is not None else {
                "shell_pid": 10,
                "foreground_processes": ([{"name": name, "pid": 20 + i} for i, name in enumerate(self.apps)]
                                         or [{"name": "zsh", "pid": 10}]),
            }}
        if method == "pane.get":
            return {"pane": {"pane_id": "w1:p1", "terminal_id": self.terminal_id,
                             "workspace_id": "w1", "tab_id": "w1:t1", "agent": self.agent,
                             **self.pane_titles}}
        if method == "workspace.get":
            return {"workspace": {"tab_count": self.tab_count}}
        if method == "pane.list":
            return {"panes": [{"pane_id": "w1:p" + str(i + 1), "tab_id": "w1:t1"}
                              for i in range(self.pane_count)]}
        return {}

    def run_shortcut(self, name, *args, **env):
        environment = dict(os.environ, HERDR_SOCKET_PATH=self.path,
                           HERDR_BIN_PATH="/missing/herdr", PATH="/missing",
                           HERDR_ACTIVE_WORKSPACE_ID="w1", HERDR_ACTIVE_TAB_ID="w1:t1",
                           HERDR_ACTIVE_PANE_ID="w1:p1", HERDR_PLUGIN_CONTEXT_JSON="")
        environment.update(env)
        return subprocess.run(["/usr/bin/python3", str(ROOT / name), *args],
                              env=environment, capture_output=True, text=True, timeout=5)

    def successful(self, name, *args, **env):
        result = self.run_shortcut(name, *args, **env)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_tab_steps_cross_workspaces_and_wrap_without_cli(self):
        for direction, current, target in [
            ("next", "w1:t1", "w1:t2"),
            ("next", "w1:t2", "w2:t1"),
            ("next", "w2:t1", "w1:t1"),
            ("previous", "w1:t1", "w2:t1"),
        ]:
            with self.subTest(direction=direction, current=current):
                self.successful("herdr-tab-step", direction, HERDR_ACTIVE_TAB_ID=current)
                self.assertEqual(self.calls[-1], ("tab.focus", {"tab_id": target}))

    def test_tab_walk_follows_grouped_sidebar(self):
        self.workspaces = [
            {"workspace_id": "w2", "worktree": {"repo_key": "repo", "is_linked_worktree": True}},
            {"workspace_id": "w3"},
            {"workspace_id": "w1", "worktree": {"repo_key": "repo", "is_linked_worktree": False}},
        ]
        self.tabs.append({"workspace_id": "w3", "tab_id": "w3:t1"})
        self.successful("herdr-tab-step", "next", HERDR_ACTIVE_TAB_ID="w2:t1")
        self.assertEqual(self.calls[-1], ("tab.focus", {"tab_id": "w3:t1"}))

    def test_shell_copy_sends_no_interrupt(self):
        self.successful("herdr-app-key", "copy")
        self.assertEqual([method for method, _ in self.calls], ["pane.process_info"])

    def test_option_splits_target_the_original_pane_and_keep_focus(self):
        for direction in ["right", "down"]:
            with self.subTest(direction=direction):
                self.successful("split-focused.py", direction)
                self.assertEqual(self.calls[-1], ("pane.split", {
                    "target_pane_id": "w1:p1", "direction": direction, "focus": False,
                }))

    def test_invalid_split_does_not_create_a_pane(self):
        result = self.run_shortcut("split-focused.py", "left")
        self.assertEqual(result.returncode, 64)
        self.assertEqual(self.calls, [])

    def test_deployed_symlink_finds_socket_helper(self):
        link = Path(self.directory.name) / "herdr-app-key"
        link.symlink_to(ROOT / "herdr-app-key")
        result = subprocess.run([str(link), "copy"],
                                env=dict(os.environ, HERDR_SOCKET_PATH=self.path,
                                         HERDR_BIN_PATH="/missing/herdr", PATH="/missing",
                                         HERDR_ACTIVE_PANE_ID="w1:p1"),
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([method for method, _ in self.calls], ["pane.process_info"])

    def test_editor_and_codex_keys_are_forwarded(self):
        for app, action, key in [("xlent", "save", "ctrl+s"),
                                 ("micro", "copy", "ctrl+c"),
                                 ("codex", "copy", "ctrl+c"),
                                 ("xlent", "left", "shift+left")]:
            with self.subTest(app=app, action=action):
                self.apps = [app]
                self.successful("herdr-app-key", action)
                self.assertEqual(self.calls[-1], ("pane.send_keys", {"pane_id": "w1:p1", "keys": [key]}))

    def test_app_fallbacks_use_plugins_and_workspace_navigation(self):
        for action, method, params in [
            ("save", "plugin.action.invoke", {"action_id": "jhochenbaum.hunkdiff.send-review", "plugin_id": "jhochenbaum.hunkdiff"}),
            ("left", "plugin.action.invoke", {"action_id": "move-left", "plugin_id": "me.space-mover"}),
            ("up", "workspace.focus", {"workspace_id": "w2"}),
            ("down", "workspace.focus", {"workspace_id": "w2"}),
        ]:
            with self.subTest(action=action):
                self.successful("herdr-app-key", action)
                self.assertEqual(self.calls[-1], (method, params))

    def test_close_passes_through_to_editors(self):
        self.apps = ["micro"]
        self.successful("close-focused.sh")
        self.assertEqual(self.calls[-1], ("pane.send_text", {"pane_id": "w1:p1", "text": "\x17"}))
        self.assertFalse(any(method.endswith(".close") for method, _ in self.calls))

    def test_close_cascade(self):
        for panes, tabs, method, params in [
            (2, 1, "pane.close", {"pane_id": "w1:p1"}),
            (1, 2, "tab.close", {"tab_id": "w1:t1"}),
            (1, 1, "workspace.close", {"workspace_id": "w1"}),
        ]:
            with self.subTest(panes=panes, tabs=tabs):
                self.pane_count, self.tab_count = panes, tabs
                self.successful("close-focused.sh")
                self.assertEqual(self.calls[-1], (method, params))

    def test_failed_query_does_not_close_anything(self):
        self.fail_method = "workspace.get"
        result = self.run_shortcut("close-focused.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("query failed", result.stderr)
        self.assertFalse(any(method.endswith(".close") for method, _ in self.calls))

    def test_busy_jobs_open_popup_without_closing(self):
        for app in ["codex", "claude", "pi", "python3", "bash", "zsh"]:
            with self.subTest(app=app):
                self.calls.clear()
                self.apps = [app]
                self.successful("close-focused.sh")
                self.assertEqual(self.calls[-1], ("plugin.pane.open", {
                    "plugin_id": "me.confirm-close", "entrypoint": "confirm",
                    "placement": "popup", "env": {
                        "ME_CONFIRM_PANE_ID": "w1:p1", "ME_CONFIRM_TERMINAL_ID": "term-original",
                        "ME_CONFIRM_JOB": app,
                        "ME_CONFIRM_TITLE": "w1:p1",
                    },
                }))
                self.assertFalse(any(method.endswith(".close") for method, _ in self.calls))

    def test_retained_agent_prompts_with_shell_in_foreground(self):
        self.agent = "codex"
        self.successful("close-focused.sh")
        self.assertEqual(self.calls[-1][1]["env"]["ME_CONFIRM_JOB"], "codex")

    def test_popup_title_prefers_label_then_terminal_title(self):
        self.apps = ["codex"]
        for titles, expected in [
            ({"label": "Fix close confirmation", "terminal_title_stripped": "Codex"}, "Fix close confirmation"),
            ({"title": "Build scripts", "terminal_title_stripped": "Codex"}, "Build scripts"),
            ({"label": None, "terminal_title_stripped": "Run tests", "terminal_title": "● Run tests"}, "Run tests"),
            ({"terminal_title": "Server logs"}, "Server logs"),
            ({}, "w1:p1"),
        ]:
            with self.subTest(titles=titles):
                self.pane_titles = titles
                self.successful("close-focused.sh")
                self.assertEqual(self.calls[-1][1]["env"]["ME_CONFIRM_TITLE"], expected)

    def test_missing_process_metadata_prompts(self):
        self.process_info = {}
        self.successful("close-focused.sh")
        self.assertEqual(self.calls[-1][1]["env"]["ME_CONFIRM_JOB"], "an unknown process")

    def test_plugin_context_wins_over_inherited_pane(self):
        self.successful("plugin-confirm-close/close.py", HERDR_ACTIVE_PANE_ID="w2:p2",
                        HERDR_PLUGIN_CONTEXT_JSON='{"focused_pane_id":"w1:p1"}')
        self.assertEqual(self.calls[0], ("pane.process_info", {"pane_id": "w1:p1"}))

    def run_prompt(self, key, **extra_env):
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 10, 66, 0, 0))
        environment = dict(os.environ, TERM="xterm-256color", HERDR_SOCKET_PATH=self.path,
                           ME_CONFIRM_PANE_ID="w1:p1", ME_CONFIRM_TERMINAL_ID="term-original",
                           ME_CONFIRM_JOB="python3", HERDR_ACTIVE_PANE_ID="w2:p2")
        environment.update(extra_env)
        process = subprocess.Popen(["/usr/bin/python3", str(ROOT / "plugin-confirm-close/close.py"), "--prompt"],
                                   stdin=slave, stdout=slave, stderr=slave, env=environment)
        os.close(slave)
        output = b""
        try:
            deadline = time.monotonic() + 3
            while b"y close" not in output and time.monotonic() < deadline:
                if select.select([master], [], [], 0.05)[0]:
                    try:
                        output += os.read(master, 65536)
                    except OSError:
                        break
            self.assertIn(b"y close", output, output.decode(errors="replace"))
            os.write(master, key)
            # macOS waits for PTY output to drain when curses restores its
            # terminal mode. Keep consuming the screen while the child exits.
            deadline = time.monotonic() + 3
            while process.poll() is None and time.monotonic() < deadline:
                if select.select([master], [], [], 0.05)[0]:
                    try:
                        output += os.read(master, 65536)
                    except OSError:
                        break
            process.wait(timeout=3)
            return process.returncode, output
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)

    def test_popup_cancel_keys_never_close(self):
        for key in [b"n", b"\x1b", b"\x17", b"q"]:
            with self.subTest(key=key):
                self.calls.clear()
                code, _ = self.run_prompt(key)
                self.assertEqual(code, 0)
                self.assertEqual(self.calls, [])

    def test_popup_displays_title_and_clips_long_unicode_titles(self):
        for title, expected in [("Fix close confirmation", b"Fix close confirmation"),
                                ("Pane\nTitle\x07", b"Pane Title"),
                                ("界" * 100, "界".encode())]:
            with self.subTest(title=title):
                code, output = self.run_prompt(b"n", ME_CONFIRM_TITLE=title)
                self.assertEqual(code, 0)
                self.assertIn(expected, output)
                self.assertIn(b"python3 is still running.", output)
                self.assertEqual(self.calls, [])

    def test_popup_return_and_keypad_enter_confirm(self):
        for key in [b"\r", b"\n", b"\x1bOM"]:
            with self.subTest(key=key):
                self.calls.clear()
                code, _ = self.run_prompt(key)
                self.assertEqual(code, 0)
                self.assertEqual(self.calls[-1], ("workspace.close", {"workspace_id": "w1"}))

    def test_popup_arrows_select_buttons_before_enter(self):
        for keys, closes in [
            (b"\x1bOC\r", False),             # Right selects Cancel.
            (b"\x1bOD\r", False),             # Left wraps to Cancel.
            (b"\x1bOC\x1bOD\r", True),       # Right then Left selects Confirm.
            (b"\x1bOD\x1bOC\x1bOM", True),   # Both directions; keypad Enter.
            (b"\x1bOCy", True),               # Y bypasses Cancel selection.
            (b"\x1bOC\x1bODn", False),        # N bypasses Confirm selection.
            (b"\x1bOC\x1bOD\x1b", False),    # Escape bypasses Confirm selection.
        ]:
            with self.subTest(keys=keys):
                self.calls.clear()
                code, output = self.run_prompt(keys)
                self.assertEqual(code, 0)
                self.assertIn(b"  Confirm  ", output)
                self.assertIn(b"  Cancel  ", output)
                self.assertEqual(any(method.endswith(".close") for method, _ in self.calls), closes)

    def test_popup_yes_closes_original_target_using_cascade(self):
        for panes, tabs, method, params in [
            (2, 1, "pane.close", {"pane_id": "w1:p1"}),
            (1, 2, "tab.close", {"tab_id": "w1:t1"}),
            (1, 1, "workspace.close", {"workspace_id": "w1"}),
        ]:
            with self.subTest(panes=panes, tabs=tabs):
                self.calls.clear()
                self.pane_count, self.tab_count = panes, tabs
                code, _ = self.run_prompt(b"y")
                self.assertEqual(code, 0)
                self.assertEqual(self.calls[-1], (method, params))

    def test_popup_yes_does_not_close_replaced_terminal(self):
        self.terminal_id = "term-replaced"
        code, _ = self.run_prompt(b"y")
        self.assertNotEqual(code, 0)
        self.assertFalse(any(method.endswith(".close") for method, _ in self.calls))

    def test_popup_launch_failure_does_not_close(self):
        self.apps = ["python3"]
        self.fail_method = "plugin.pane.open"
        result = self.run_shortcut("close-focused.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(method.endswith(".close") for method, _ in self.calls))


if __name__ == "__main__":
    unittest.main()
