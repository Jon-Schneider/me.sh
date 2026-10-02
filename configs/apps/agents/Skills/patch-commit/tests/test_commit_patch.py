from __future__ import annotations

import fcntl
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "commit_patch.py"


class PatchCommitTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="patch-commit-test-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.repo = self.directory / "repo"
        self.repo.mkdir()
        self.env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        self.env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Patch Commit Test")
        self.git("config", "user.email", "patch-commit@example.com")
        self.git("config", "commit.gpgsign", "false")
        self.write("a.txt", "one\ntwo\nthree\n")
        self.write("b.txt", "other\n")
        self.git("add", "a.txt", "b.txt")
        self.git("commit", "-qm", "Initial")
        self.base = self.git("rev-parse", "HEAD").stdout.decode().strip()

    def git(self, *args, data=None, check=True, repo=None):
        return subprocess.run(
            ["git", "-C", str(repo or self.repo), *args], input=data,
            capture_output=True, check=check, env=self.env,
        )

    def write(self, name, contents):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(contents, bytes):
            path.write_bytes(contents)
        else:
            path.write_text(contents)
        return path

    def patch(self, *paths, base=None):
        output = self.git("diff", "--binary", "--full-index", "--no-ext-diff", "--no-textconv", base or self.base, "--", *paths).stdout
        path = self.directory / f"patch-{time.monotonic_ns()}.diff"
        path.write_bytes(output)
        return path

    def command(self, patch, base=None, repo=None, extra=()):
        return [sys.executable, str(SCRIPT), "--repo", str(repo or self.repo),
                "--patch", str(patch), "--base", base or self.base,
                "--message", "Reviewed patch", *extra]

    def commit(self, patch, **kwargs):
        return subprocess.run(self.command(patch, **kwargs), capture_output=True, env=self.env, timeout=15)

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stderr.decode())

    def assert_rejected(self, result, reason):
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(reason, result.stderr.decode())

    def assert_head_unchanged(self):
        self.assertEqual(self.git("rev-parse", "HEAD").stdout.decode().strip(), self.base)

    def assert_index_clean(self):
        self.assertEqual(self.git("diff", "--cached").stdout, b"")

    def hook(self, name, body, directory=None):
        directory = directory or self.repo / ".git" / "hooks"
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / name
        path.write_text(f"#!{sys.executable}\n" + body)
        path.chmod(0o755)
        return path

    def wait_until(self, condition):
        deadline = time.monotonic() + 10
        while not condition():
            if time.monotonic() > deadline:
                self.fail("Timed out waiting for a subprocess checkpoint")
            time.sleep(0.02)

    def gated_hook(self, exit_code=0):
        started = self.directory / "hook-started"
        release = self.directory / "hook-release"
        self.hook("pre-commit", f"""from pathlib import Path
import sys
import time
Path({str(started)!r}).touch()
deadline = time.monotonic() + 10
while not Path({str(release)!r}).exists() and time.monotonic() < deadline:
    time.sleep(0.02)
sys.exit({exit_code})
""")
        return started, release

    def start(self, patch, **kwargs):
        process = subprocess.Popen(self.command(patch, **kwargs), stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=self.env)
        self.addCleanup(self.stop, process)
        return process

    @staticmethod
    def stop(process):
        if process.poll() is None:
            process.terminate()
        process.communicate(timeout=15)

    def test_commits_frozen_patch_and_preserves_other_edits(self):
        self.write("a.txt", "mine\ntwo\nthree\n")
        patch = self.patch("a.txt")
        self.write("a.txt", "mine\ntwo\nsomeone else\n")
        self.write("b.txt", "someone else's file\n")
        self.assert_success(self.commit(patch))
        self.assertEqual(self.git("show", "HEAD:a.txt").stdout, b"mine\ntwo\nthree\n")
        self.assertEqual(self.git("show", "HEAD:b.txt").stdout, b"other\n")
        self.assertEqual((self.repo / "a.txt").read_text(), "mine\ntwo\nsomeone else\n")
        self.assertEqual((self.repo / "b.txt").read_text(), "someone else's file\n")
        self.assert_index_clean()

    def test_refuses_and_preserves_preexisting_staging(self):
        self.write("a.txt", "mine\n")
        patch = self.patch("a.txt")
        self.write("b.txt", "someone else's staging\n")
        self.git("add", "b.txt")
        before = self.git("diff", "--cached", "--binary").stdout
        self.assert_rejected(self.commit(patch), "already contains staged changes")
        self.assertEqual(self.git("diff", "--cached", "--binary").stdout, before)
        self.assert_head_unchanged()

    def test_two_agents_serialize_from_different_subdirectories(self):
        self.write("a.txt", "agent A\n")
        first_patch = self.patch("a.txt")
        self.write("b.txt", "agent B\n")
        second_patch = self.patch("b.txt")
        started, release = self.gated_hook()
        first = self.start(first_patch)
        self.wait_until(started.exists)
        subdirectory = self.repo / "nested"
        subdirectory.mkdir()
        log = self.directory / "second.stderr"
        with log.open("wb") as stderr:
            second = subprocess.Popen(self.command(second_patch, repo=subdirectory), stdout=subprocess.PIPE, stderr=stderr, env=self.env)
            self.addCleanup(self.stop, second)
            self.wait_until(lambda: b"Waiting" in log.read_bytes())
            self.assertEqual(self.git("diff", "--cached", "--name-only").stdout, b"a.txt\n")
            self.assertIsNone(second.poll())
            release.touch()
            first_stdout, first_stderr = first.communicate(timeout=15)
            self.assertEqual(first.returncode, 0, first_stderr.decode())
            second.communicate(timeout=15)
            self.assertEqual(second.returncode, 0, log.read_text())
        self.assertEqual(log.read_bytes().count(b"Waiting"), 1)
        self.assertEqual(self.git("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD^").stdout, b"a.txt\n")
        self.assertEqual(self.git("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD").stdout, b"b.txt\n")
        self.assert_index_clean()

    def test_rejects_overlapping_patch_even_if_it_could_still_apply(self):
        self.write("a.txt", "mine\ntwo\nthree\n")
        patch = self.patch("a.txt")
        self.write("a.txt", "one\ntwo\nother agent\n")
        self.git("add", "a.txt")
        self.git("commit", "-qm", "Other agent")
        current = self.git("rev-parse", "HEAD").stdout
        self.assert_rejected(self.commit(patch), "changed since the captured base")
        self.assertEqual(self.git("rev-parse", "HEAD").stdout, current)
        self.assert_index_clean()

    def test_hook_failure_reverses_only_transaction_staging(self):
        self.write("a.txt", "mine\n")
        patch = self.patch("a.txt")
        self.hook("pre-commit", "import sys\nprint('Hook failed', file=sys.stderr)\nsys.exit(1)\n")
        result = self.commit(patch)
        self.assert_rejected(result, "Hook failed")
        self.assertIn("Removed this transaction's staging", result.stderr.decode())
        self.assert_head_unchanged()
        self.assert_index_clean()
        self.assertEqual((self.repo / "a.txt").read_text(), "mine\n")

    def test_guards_each_hook_against_staging_extra_work(self):
        for name in ("pre-commit", "prepare-commit-msg", "commit-msg"):
            with self.subTest(hook=name):
                self.write("a.txt", "mine\n")
                patch = self.patch("a.txt")
                self.write("b.txt", "extra\n")
                hook = self.hook(name, "import subprocess\nsubprocess.run(['git', 'add', 'b.txt'], check=True)\n")
                result = self.commit(patch)
                self.assert_rejected(result, "staged tree changed unexpectedly")
                self.assertIn("Cleanup left the index for inspection", result.stderr.decode())
                self.assert_head_unchanged()
                self.assertEqual(self.git("diff", "--cached", "--name-only").stdout, b"a.txt\nb.txt\n")
                hook.unlink()
                self.git("reset", "-q", "HEAD", "--", "a.txt", "b.txt")

    def test_preserves_configured_hooks_arguments_and_commit_message(self):
        hooks = self.repo / "custom hooks"
        self.git("config", "core.hooksPath", "custom hooks")
        events = self.directory / "hook-events"
        for name in ("pre-commit", "prepare-commit-msg", "commit-msg", "post-commit"):
            self.hook(name, f"""import sys
from pathlib import Path
with Path({str(events)!r}).open('a') as log:
    log.write({name!r} + ':' + str(len(sys.argv) - 1) + '\\n')
""", hooks)
        self.write("a.txt", "mine\n")
        patch = self.patch("a.txt")
        message = self.directory / "message.txt"
        message.write_text("Subject\n\nBody with `literal` text and $(literal).\n")
        command = self.command(patch)
        command = command[:-2] + ["--message-file", str(message)]
        self.assert_success(subprocess.run(command, capture_output=True, env=self.env, timeout=15))
        self.assertEqual(events.read_text(), "pre-commit:0\nprepare-commit-msg:2\ncommit-msg:1\npost-commit:0\n")
        self.assertEqual(self.git("log", "-1", "--format=%B").stdout.decode().strip(), message.read_text().strip())
        self.assertEqual(self.git("config", "core.hooksPath").stdout, b"custom hooks\n")

    def test_new_binary_deletion_mode_and_rename_patches(self):
        self.git("mv", "b.txt", "renamed.txt")
        self.git("reset", "-q", "HEAD", "--", "b.txt", "renamed.txt")
        self.write("binary.bin", b"\x00\x01\xff")
        (self.repo / "a.txt").chmod(0o755)
        patch = self.patch("a.txt", "b.txt")
        for path in ("renamed.txt", "binary.bin"):
            addition = self.git("diff", "--no-index", "--binary", "--", "/dev/null", path, check=False)
            self.assertEqual(addition.returncode, 1)
            with patch.open("ab") as output:
                output.write(addition.stdout)
        self.assert_success(self.commit(patch))
        self.assertEqual(self.git("show", "HEAD:binary.bin").stdout, b"\x00\x01\xff")
        self.assertEqual(self.git("show", "HEAD:renamed.txt").stdout, b"other\n")
        self.assertNotEqual(self.git("cat-file", "-e", "HEAD:b.txt", check=False).returncode, 0)
        self.assertTrue(self.git("ls-tree", "HEAD", "a.txt").stdout.startswith(b"100755"))
        self.assert_index_clean()

    def test_failed_binary_commit_can_be_reversed(self):
        self.write("a.txt", b"\x00new binary\xff")
        patch = self.patch("a.txt")
        self.hook("commit-msg", "import sys\nsys.exit(1)\n")
        self.assert_rejected(self.commit(patch), "Removed this transaction's staging")
        self.assert_index_clean()
        self.assert_head_unchanged()
        self.assertEqual((self.repo / "a.txt").read_bytes(), b"\x00new binary\xff")

    def test_timeout_does_not_touch_index(self):
        self.write("a.txt", "mine\n")
        patch = self.patch("a.txt")
        with (self.repo / ".git" / "patch-commit.lock").open("a+b") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            self.assert_rejected(self.commit(patch, extra=("--timeout", "0.1")), "Timed out")
        self.assert_index_clean()
        self.assert_head_unchanged()
        self.assert_success(self.commit(patch, extra=("--timeout", "0")))

    def test_cancellation_during_failed_hook_waits_then_cleans_up(self):
        self.write("a.txt", "mine\n")
        patch = self.patch("a.txt")
        started, release = self.gated_hook(exit_code=1)
        process = self.start(patch)
        self.wait_until(started.exists)
        process.send_signal(signal.SIGTERM)
        time.sleep(0.1)
        self.assertIsNone(process.poll())
        release.touch()
        stdout, stderr = process.communicate(timeout=15)
        self.assertEqual(process.returncode, 130, stderr.decode())
        self.assert_head_unchanged()
        self.assert_index_clean()
        self.assertEqual((self.repo / "a.txt").read_text(), "mine\n")

    def test_killed_parent_leaves_lock_with_running_git(self):
        self.write("a.txt", "mine\n")
        patch = self.patch("a.txt")
        started, release = self.gated_hook()
        first = self.start(patch)
        self.wait_until(started.exists)
        first.kill()
        self.assert_rejected(self.commit(patch, extra=("--timeout", "0.1")), "Timed out")
        release.touch()
        first.communicate(timeout=15)

        def lock_released():
            with (self.repo / ".git" / "patch-commit.lock").open("a+b") as lock:
                try:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    return True
                except BlockingIOError:
                    return False

        self.wait_until(lock_released)
        self.assertEqual(self.git("show", "HEAD:a.txt").stdout, b"mine\n")
        self.assert_index_clean()

    def test_linked_worktree_resolves_its_metadata_directory(self):
        linked = self.directory / "linked worktree"
        self.git("worktree", "add", "-qb", "test-linked", str(linked))
        (linked / "a.txt").write_text("linked\n")
        patch = self.directory / "linked.patch"
        patch.write_bytes(self.git("diff", "--binary", self.base, "--", "a.txt", repo=linked).stdout)
        self.assert_success(self.commit(patch, repo=linked))
        git_dir = Path(self.git("rev-parse", "--absolute-git-dir", repo=linked).stdout.decode().strip())
        self.assertTrue((git_dir / "patch-commit.lock").exists())
        self.assert_head_unchanged()
        self.assertEqual(self.git("show", "HEAD:a.txt", repo=linked).stdout, b"linked\n")

    def test_invalid_patch_is_atomic(self):
        self.write("a.txt", "mine\n")
        patch = self.patch("a.txt")
        with patch.open("ab") as output:
            output.write(b"diff --git a/missing b/missing\n--- a/missing\n+++ b/missing\n@@ -1 +1 @@\n-old\n+new\n")
        self.assert_rejected(self.commit(patch), "missing")
        self.assert_index_clean()
        self.assert_head_unchanged()

    def test_refuses_active_git_operations(self):
        self.write("a.txt", "mine\n")
        patch = self.patch("a.txt")
        for name in ("MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply", "sequencer"):
            with self.subTest(operation=name):
                marker = self.repo / ".git" / name
                marker.touch()
                self.assert_rejected(self.commit(patch), "active Git operation")
                marker.unlink()
                self.assert_index_clean()
                self.assert_head_unchanged()

    def test_refuses_alternate_index_and_moving_base(self):
        self.write("a.txt", "mine\n")
        patch = self.patch("a.txt")
        result = subprocess.run(self.command(patch), capture_output=True,
                                env={**self.env, "GIT_INDEX_FILE": str(self.directory / "alternate")}, timeout=15)
        self.assert_rejected(result, "Alternate indexes")
        self.assert_rejected(self.commit(patch, base="HEAD"), "full captured commit ID")
        self.assert_index_clean()
        self.assert_head_unchanged()


if __name__ == "__main__":
    unittest.main()
