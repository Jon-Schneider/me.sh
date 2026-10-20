import errno
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch


HELPER = Path(__file__).resolve().parents[1] / "delete-background.py"
spec = importlib.util.spec_from_file_location("ncdu_delete", HELPER)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class BackgroundDeleteTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ncdu-delete-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def staged(self):
        return list(self.root.glob(".ncdu-delete-*"))

    def run_worker(self, launch):
        result = subprocess.run(launch.call_args.args[0], capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_returns_before_worker_and_preserves_recreated_original(self):
        source = self.root / "large directory"
        source.mkdir()
        (source / "contents").write_text("old")
        # Hold the actual detached worker until after the helper has returned.
        worker = 'while [ ! -e "$1/../go" ]; do /bin/sleep 0.05; done\n' + helper.WORKER
        processes = []
        popen = subprocess.Popen

        def start_worker(*args, **kwargs):
            process = popen(*args, **kwargs)
            processes.append(process)
            return process

        with patch.object(helper, "WORKER", worker), patch.object(
            helper.subprocess, "Popen", side_effect=start_worker
        ) as launch:
            helper.delete_background(source)
        self.assertFalse(source.exists())
        staged = self.staged()[0]
        self.assertEqual((staged / "item/contents").read_text(), "old")
        self.assertTrue(launch.call_args.kwargs["start_new_session"])
        self.assertEqual(launch.call_args.kwargs["stdin"], subprocess.DEVNULL)
        self.assertEqual(launch.call_args.kwargs["stdout"], subprocess.DEVNULL)
        source.mkdir()
        (source / "contents").write_text("new")
        (self.root / "go").touch()
        # Wait for cleanup without waiting for unrelated subprocesses.
        deadline = time.monotonic() + 5
        while staged.exists() and time.monotonic() < deadline:
            time.sleep(0.02)
        self.assertFalse(staged.exists())
        self.assertEqual(processes[0].wait(timeout=5), 0)
        self.assertEqual((source / "contents").read_text(), "new")

    def test_shell_metacharacters_and_newlines_are_literal(self):
        for name in ("--recursive", "quote'\"; $(touch PWNED)\n雪"):
            with self.subTest(name=name):
                source = self.root / name
                source.write_text("delete me")
                with patch.object(helper.subprocess, "Popen") as launch:
                    helper.delete_background(source)
                self.assertFalse(source.exists())
                self.run_worker(launch)
                self.assertEqual(self.staged(), [])
        self.assertFalse((self.root / "PWNED").exists())

    def test_symlink_with_trailing_slash_does_not_delete_target(self):
        target = self.root / "target"
        target.mkdir()
        (target / "keep").write_text("safe")
        link = self.root / "link"
        link.symlink_to(target, target_is_directory=True)
        with patch.object(helper.subprocess, "Popen") as launch:
            helper.delete_background(str(link) + "/")
        self.run_worker(launch)
        self.assertEqual((target / "keep").read_text(), "safe")
        self.assertFalse(link.is_symlink())

    def test_broken_symlink_is_deleted(self):
        link = self.root / "broken"
        link.symlink_to(self.root / "missing")
        with patch.object(helper.subprocess, "Popen") as launch:
            helper.delete_background(link)
        self.run_worker(launch)
        self.assertFalse(link.is_symlink())

    def test_rejects_root_and_dot_entries(self):
        for path in ("", "/", "//", ".", "..", str(self.root) + "/.", str(self.root) + "/../"):
            with self.subTest(path=path), self.assertRaises(ValueError):
                helper.delete_background(path)
        self.assertEqual(self.staged(), [])

    def test_cross_filesystem_rename_failure_keeps_original(self):
        source = self.root / "mount"
        source.mkdir()
        (source / "keep").write_text("safe")
        with patch.object(helper.os, "rename", side_effect=OSError(errno.EXDEV, "cross-device")), patch.object(
            helper.subprocess, "Popen"
        ) as launch:
            with self.assertRaises(OSError):
                helper.delete_background(source)
        launch.assert_not_called()
        self.assertEqual((source / "keep").read_text(), "safe")
        self.assertEqual(self.staged(), [])

    def test_launch_failure_reports_retained_data(self):
        source = self.root / "directory"
        source.mkdir()
        (source / "keep").write_text("safe")
        with patch.object(helper.subprocess, "Popen", side_effect=OSError("launch failed")):
            with self.assertRaisesRegex(OSError, "data retained in"):
                helper.delete_background(source)
        self.assertEqual((self.staged()[0] / "item/keep").read_text(), "safe")

    @unittest.skipIf(os.geteuid() == 0, "root bypasses filesystem permissions")
    def test_delete_failure_retains_data_and_error_log(self):
        source = self.root / "directory"
        source.mkdir()
        (source / "keep").write_text("safe")
        with patch.object(helper.subprocess, "Popen") as launch:
            helper.delete_background(source)
        staged = self.staged()[0]
        (staged / "item").chmod(0o500)
        try:
            with (staged / "error.log").open("ab") as errors:
                result = subprocess.run(launch.call_args.args[0], stderr=errors)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((staged / "item/keep").read_text(), "safe")
            self.assertIn("Permission denied", (staged / "error.log").read_text())
        finally:
            (staged / "item").chmod(0o700)


if __name__ == "__main__":
    unittest.main()
