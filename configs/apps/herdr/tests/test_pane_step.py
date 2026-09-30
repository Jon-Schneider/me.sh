"""Integration checks. Set HERDR_TEST_SOCKET to an empty, disposable session."""

import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


spec = importlib.util.spec_from_file_location("pane_step", Path(__file__).parents[1] / "pane-step.py")
pane_step = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pane_step)


@unittest.skipUnless(os.environ.get("HERDR_TEST_SOCKET"), "requires a disposable Herdr session")
class PaneStepTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.api = staticmethod(pane_step.API(os.environ["HERDR_TEST_SOCKET"]))
        if cls.api("workspace.list")["workspaces"]:
            raise RuntimeError("test session must start empty")
        cls.root = tempfile.TemporaryDirectory(prefix="pane-step-projects-")
        cls.project = str(Path(cls.root.name) / "project")
        cls.other = str(Path(cls.root.name) / "other")
        Path(cls.project).mkdir()
        Path(cls.other).mkdir()
        subprocess.run(["git", "init", "-q", cls.project], check=True)
        subprocess.run([
            "git", "-C", cls.project, "-c", "user.name=Pane tests",
            "-c", "user.email=pane-tests@example.invalid", "commit", "-qm", "initial", "--allow-empty",
        ], check=True)
        cls.worktree = str(Path(cls.root.name) / "linked")
        subprocess.run(["git", "-C", cls.project, "worktree", "add", "-qb", "linked", cls.worktree], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.root.cleanup()

    def tearDown(self):
        # All workspaces in this dedicated session were created by these tests.
        for workspace in self.api("workspace.list")["workspaces"]:
            self.api("workspace.close", workspace_id=workspace["workspace_id"])

    def workspace(self, cwd=None, label="project", focus=True):
        return self.api("workspace.create", cwd=cwd or self.project, label=label, focus=focus)

    def focus(self, pane):
        self.api("pane.focus", pane_id=pane["pane_id"])

    def focused(self):
        return next(p for p in self.api("pane.list")["panes"] if p["focused"])

    def layout(self, pane):
        return self.api("pane.layout", pane_id=pane["pane_id"])["layout"]

    def test_swap_and_follow_focus(self):
        source = self.workspace()["root_pane"]
        target = self.api("pane.split", pane_id=source["pane_id"], direction="right", focus=False)["pane"]
        pane_step.move(self.api, "right")
        self.assertEqual(self.focused()["pane_id"], source["pane_id"])
        positions = {p["pane_id"]: p["rect"]["x"] for p in self.layout(source)["panes"]}
        self.assertGreater(positions[source["pane_id"]], positions[target["pane_id"]])
        pane_step.move(self.api, "left")
        positions = {p["pane_id"]: p["rect"]["x"] for p in self.layout(source)["panes"]}
        self.assertLess(positions[source["pane_id"]], positions[target["pane_id"]])

    def test_single_pane_tab_moves_into_next_tab_from_left(self):
        created = self.workspace()
        source = created["root_pane"]
        target = self.api("tab.create", workspace_id=source["workspace_id"], focus=False)["root_pane"]
        pane_step.move(self.api, "right")
        moved = self.focused()
        self.assertEqual(moved["terminal_id"], source["terminal_id"])
        self.assertEqual(moved["tab_id"], target["tab_id"])
        self.assertEqual(len(self.api("tab.list")["tabs"]), 1)
        positions = {p["pane_id"]: p["rect"]["x"] for p in self.layout(moved)["panes"]}
        self.assertLess(positions[moved["pane_id"]], positions[target["pane_id"]])

    def test_single_pane_tab_moves_into_previous_tab_from_right(self):
        target = self.workspace()["root_pane"]
        source = self.api("tab.create", workspace_id=target["workspace_id"], focus=True)["root_pane"]
        pane_step.move(self.api, "left")
        moved = self.focused()
        self.assertEqual(moved["tab_id"], target["tab_id"])
        positions = {p["pane_id"]: p["rect"]["x"] for p in self.layout(moved)["panes"]}
        self.assertGreater(positions[moved["pane_id"]], positions[target["pane_id"]])

    def test_same_project_workspaces_skip_unrelated_project(self):
        source = self.workspace()["root_pane"]
        unrelated = self.workspace(self.other, label="project", focus=False)["root_pane"]
        target = self.workspace(focus=False)["root_pane"]
        pane_step.move(self.api, "right")
        moved = self.focused()
        self.assertEqual(moved["workspace_id"], target["workspace_id"])
        self.assertEqual(moved["terminal_id"], source["terminal_id"])
        self.assertNotEqual(moved["pane_id"], source["pane_id"])
        self.assertEqual(len(self.api("pane.list")["panes"]), 3)
        self.assertEqual(self.api("pane.get", pane_id=unrelated["pane_id"])["pane"]["terminal_id"], unrelated["terminal_id"])
        self.assertNotIn(source["workspace_id"], [w["workspace_id"] for w in self.api("workspace.list")["workspaces"]])

    def test_linked_worktree_and_subdirectory_are_same_project(self):
        subdir = Path(self.project) / "subdirectory"
        subdir.mkdir(exist_ok=True)
        source = self.workspace(str(subdir))["root_pane"]
        target = self.workspace(self.worktree, focus=False)["root_pane"]
        pane_step.move(self.api, "right")
        self.assertEqual(self.focused()["workspace_id"], target["workspace_id"])
        self.assertEqual(self.focused()["terminal_id"], source["terminal_id"])

    def test_native_worktree_group_uses_sidebar_order(self):
        parent = self.api("worktree.open", cwd=self.project, path=self.project, focus=False)["root_pane"]
        linked = self.api("worktree.open", cwd=self.project, path=self.worktree, focus=False)["root_pane"]
        # Raw storage can place a child first; Herdr displays its parent first.
        self.api("workspace.move", workspace_id=linked["workspace_id"], insert_index=0)
        self.focus(parent)
        pane_step.move(self.api, "right")
        self.assertEqual(self.focused()["workspace_id"], linked["workspace_id"])
        self.assertEqual(self.focused()["terminal_id"], parent["terminal_id"])

    def check_edge(self, direction, single=False):
        before = self.workspace(self.other, label="before", focus=False)["workspace"]
        source = self.workspace()["root_pane"]
        after = self.workspace(self.other, label="after", focus=False)["workspace"]
        if not single:
            self.api("pane.split", pane_id=source["pane_id"], direction="down", focus=False)
        pane_step.move(self.api, direction)
        moved = self.focused()
        ids = [w["workspace_id"] for w in self.api("workspace.list")["workspaces"]]
        middle = [moved["workspace_id"]]
        if not single:
            if direction == "left":
                middle.append(source["workspace_id"])
            else:
                middle.insert(0, source["workspace_id"])
        self.assertEqual(ids, [before["workspace_id"], *middle, after["workspace_id"]])
        self.assertEqual(moved["terminal_id"], source["terminal_id"])
        self.assertEqual(len(self.api("pane.list")["panes"]), 3 if single else 4)
        self.assertEqual(pane_step.workspace_project(self.api("workspace.get", workspace_id=moved["workspace_id"])["workspace"], [moved]), pane_step.directory_project(self.project))

    def test_create_space_before_project(self):
        self.check_edge("left")

    def test_create_space_after_project(self):
        self.check_edge("right")

    def test_only_pane_creates_space_before(self):
        self.check_edge("left", single=True)

    def test_only_pane_creates_space_after(self):
        self.check_edge("right", single=True)

    def test_repeat_follows_new_pane_id(self):
        source = self.workspace()["root_pane"]
        self.api("pane.split", pane_id=source["pane_id"], direction="down", focus=False)
        pane_step.move(self.api, "right")
        first = self.focused()
        self.assertNotEqual(first["pane_id"], source["pane_id"])
        pane_step.move(self.api, "left")
        self.assertEqual(self.focused()["terminal_id"], source["terminal_id"])
        self.assertEqual(self.focused()["workspace_id"], source["workspace_id"])

    def test_script_repeated_presses_ignore_stale_invocation_ids(self):
        source = self.workspace()["root_pane"]
        self.api("pane.split", pane_id=source["pane_id"], direction="down", focus=False)
        env = dict(os.environ, HERDR_SOCKET_PATH=os.environ["HERDR_TEST_SOCKET"],
                   HERDR_ACTIVE_PANE_ID=source["pane_id"], HERDR_ACTIVE_TAB_ID=source["tab_id"])
        for direction in ("right", "left"):
            subprocess.run(["/usr/bin/python3", str(Path(pane_step.__file__)), direction],
                           env=env, check=True, capture_output=True, text=True)
        self.assertEqual(self.focused()["terminal_id"], source["terminal_id"])
        self.assertEqual(self.focused()["workspace_id"], source["workspace_id"])

    def test_zoomed_source_and_target(self):
        source = self.workspace()["root_pane"]
        target = self.workspace(focus=False)["root_pane"]
        self.api("pane.zoom", pane_id=source["pane_id"], mode="on")
        self.api("pane.zoom", pane_id=target["pane_id"], mode="on")
        self.focus(source)
        pane_step.move(self.api, "right")
        self.assertEqual(self.focused()["workspace_id"], target["workspace_id"])
        self.assertFalse(self.layout(self.focused())["zoomed"])


if __name__ == "__main__":
    unittest.main()
