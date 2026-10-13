"""Exercise shortcut entrypoints with a session socket and an unusable CLI."""

import json
import os
from pathlib import Path
import socketserver
import subprocess
import tempfile
import threading
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ShortcutsTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="herdr-keys-", dir="/tmp")
        self.path = str(Path(self.directory.name) / "herdr.sock")
        self.calls = []
        self.apps = []
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
            return {"process_info": {"foreground_processes": [{"name": name} for name in self.apps]}}
        if method == "workspace.get":
            return {"workspace": {"tab_count": self.tab_count}}
        if method == "pane.list":
            return {"panes": [{"tab_id": "w1:t1"} for _ in range(self.pane_count)]}
        return {}

    def run_shortcut(self, name, *args, **env):
        environment = dict(os.environ, HERDR_SOCKET_PATH=self.path,
                           HERDR_BIN_PATH="/missing/herdr", PATH="/missing",
                           HERDR_ACTIVE_WORKSPACE_ID="w1", HERDR_ACTIVE_TAB_ID="w1:t1",
                           HERDR_ACTIVE_PANE_ID="w1:p1")
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


if __name__ == "__main__":
    unittest.main()
