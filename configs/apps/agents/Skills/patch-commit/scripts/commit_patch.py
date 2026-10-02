#!/usr/bin/env python3
"""Serialize reviewed patch commits in a shared Git worktree."""

from __future__ import annotations

import argparse
import fcntl
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time


HOOK_NAMES = ("pre-commit", "prepare-commit-msg", "commit-msg", "post-commit")
HOOK_STATE = "PATCH_COMMIT_HOOK_STATE"
cancelled = False


class TransactionError(Exception):
    pass


class Git:
    def __init__(self, repo: Path, lock_fd: int | None = None):
        self.repo = repo
        self.lock_fd = lock_fd

    def run(self, *args: str, data: bytes | None = None, env: dict | None = None,
            check: bool = True) -> subprocess.CompletedProcess:
        result = subprocess.run(
            ["git", "-C", str(self.repo), *args],
            input=data,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env={**os.environ, **(env or {})},
            pass_fds=() if self.lock_fd is None else (self.lock_fd,),
        )
        if check and result.returncode:
            detail = (result.stderr or result.stdout).decode(errors="replace").strip()
            raise TransactionError(detail or f"git {args[0]} exited {result.returncode}")
        return result

    def value(self, *args: str, env: dict | None = None) -> str:
        return self.run(*args, env=env).stdout.decode().strip()

    def head(self) -> str:
        return self.value("rev-parse", "--verify", "HEAD")

    def branch(self) -> str:
        result = self.run("symbolic-ref", "--quiet", "HEAD", check=False)
        if result.returncode not in (0, 1):
            raise TransactionError(result.stderr.decode(errors="replace").strip())
        return result.stdout.decode().strip()


def request_cancellation(signum: int, frame: object) -> None:
    global cancelled
    cancelled = True


def check_cancellation() -> None:
    if cancelled:
        raise TransactionError("Cancelled.")


def acquire_lock(lock, timeout: float) -> None:
    deadline = time.monotonic() + timeout
    announced = False
    while True:
        check_cancellation()
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            return
        except BlockingIOError:
            if not announced:
                print("Waiting for the patch-commit transaction lock...", file=sys.stderr, flush=True)
                announced = True
            if time.monotonic() >= deadline:
                raise TransactionError(f"Timed out after {timeout:g}s waiting for the transaction lock.")
            time.sleep(min(0.1, max(0, deadline - time.monotonic())))


def changed_paths(git: Git, before: str, after: str) -> set[bytes]:
    output = git.run("diff-tree", "--no-commit-id", "--name-only", "--no-renames", "-r", "-z", before, after).stdout
    return set(output.rstrip(b"\0").split(b"\0")) if output else set()


def assert_snapshot(git: Git, head: str, branch: str, tree: str) -> None:
    if git.head() != head or git.branch() != branch:
        raise TransactionError("HEAD or the current branch changed during the transaction; inspect before retrying.")
    if git.value("write-tree") != tree:
        raise TransactionError("The staged tree changed unexpectedly; inspect the index before retrying.")


def guarded_hook(name: str) -> int:
    state = json.loads(os.environ[HOOK_STATE])
    original = Path(state["hooks"]) / name
    if original.is_file() and os.access(original, os.X_OK):
        result = subprocess.run([str(original), *sys.argv[1:]], pass_fds=(state["lock_fd"],))
        if result.returncode:
            return result.returncode if result.returncode > 0 else 128 - result.returncode
    if name != "post-commit":
        git = Git(Path(state["repo"]), state["lock_fd"])
        assert_snapshot(git, state["head"], state["branch"], state["tree"])
    return 0


def install_hook_guards(git: Git, directory: Path, head: str, branch: str, tree: str) -> dict:
    original_hooks = git.value("rev-parse", "--path-format=absolute", "--git-path", "hooks")
    for name in HOOK_NAMES:
        (directory / name).symlink_to(Path(__file__).resolve())
    return {HOOK_STATE: json.dumps({
        "hooks": original_hooks,
        "repo": str(git.repo),
        "head": head,
        "branch": branch,
        "tree": tree,
        "lock_fd": git.lock_fd,
    })}


def rollback(git: Git, patch: bytes, head: str, branch: str, expected_tree: str) -> None:
    try:
        assert_snapshot(git, head, branch, expected_tree)
        git.run("apply", "--cached", "--reverse", "--whitespace=nowarn", "-", data=patch)
        assert_snapshot(git, head, branch, git.value("rev-parse", f"{head}^{{tree}}"))
        print("Removed this transaction's staging; worktree files were left intact.", file=sys.stderr)
    except TransactionError as error:
        print(f"Cleanup left the index for inspection: {error}", file=sys.stderr)


def transact(git: Git, git_dir: Path, branch: str, base: str, patch: bytes, message: bytes) -> None:
    check_cancellation()
    if git.branch() != branch:
        raise TransactionError("The current branch changed while waiting; review again before retrying.")
    for marker in ("MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply", "sequencer"):
        if (git_dir / marker).exists():
            raise TransactionError(f"An active Git operation ({marker}) must finish before patch-commit.")

    head = git.head()
    head_tree = git.value("rev-parse", f"{head}^{{tree}}")
    if git.run("ls-files", "--unmerged").stdout:
        raise TransactionError("The index has unresolved conflicts; left untouched.")
    if git.value("write-tree") != head_tree:
        raise TransactionError("The index already contains staged changes; left untouched.")
    base = git.value("rev-parse", "--verify", f"{base}^{{commit}}")
    ancestor = git.run("merge-base", "--is-ancestor", base, head, check=False)
    if ancestor.returncode:
        raise TransactionError("The patch base is not an ancestor of HEAD; rebuild and review the patch.")

    with tempfile.TemporaryDirectory(prefix="patch-commit-") as temporary:
        directory = Path(temporary)
        preview_env = {"GIT_INDEX_FILE": str(directory / "index")}
        git.run("read-tree", base, env=preview_env)
        git.run("apply", "--cached", "--whitespace=nowarn", "-", data=patch, env=preview_env)
        base_tree = git.value("write-tree", env=preview_env)
        touched = changed_paths(git, base, base_tree)
        if not touched:
            raise TransactionError("The patch contains no changes.")
        overlap = touched & changed_paths(git, base, head)
        if overlap:
            paths = ", ".join(repr(os.fsdecode(path)) for path in sorted(overlap))
            raise TransactionError(f"Patch files changed since the captured base: {paths}. Rebuild and review the patch.")

        git.run("read-tree", head, env=preview_env)
        git.run("apply", "--cached", "--whitespace=nowarn", "-", data=patch, env=preview_env)
        expected_tree = git.value("write-tree", env=preview_env)
        hooks = directory / "hooks"
        hooks.mkdir()
        hook_env = install_hook_guards(git, hooks, head, branch, expected_tree)
        check_cancellation()
        assert_snapshot(git, head, branch, head_tree)
        git.run("apply", "--cached", "--whitespace=nowarn", "-", data=patch)
        try:
            assert_snapshot(git, head, branch, expected_tree)
            check_cancellation()
            result = git.run("-c", f"core.hooksPath={hooks}", "commit", "--file=-", data=message, env=hook_env)
            committed = git.head()
            if git.value("rev-parse", f"{committed}^{{tree}}") != expected_tree or git.value("rev-parse", f"{committed}^") != head:
                raise TransactionError(f"Commit {committed} was created with unexpected contents or parent; inspect it. No history was reverted.")
            assert_snapshot(git, committed, branch, expected_tree)
            sys.stdout.buffer.write(result.stdout)
            sys.stderr.buffer.write(result.stderr)
            print(f"Committed: {committed}", flush=True)
        except (TransactionError, OSError):
            rollback(git, patch, head, branch, expected_tree)
            raise


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="Worktree directory (default: current directory)")
    parser.add_argument("--patch", type=Path, required=True, help="Reviewed Git patch, including binary data when needed")
    parser.add_argument("--base", required=True, help="Full HEAD commit ID captured before preparing the patch")
    messages = parser.add_mutually_exclusive_group(required=True)
    messages.add_argument("--message", help="Commit message")
    messages.add_argument("--message-file", type=Path, help="File containing the commit message")
    parser.add_argument("--timeout", type=float, default=300, help="Maximum lock wait in seconds (default: 300)")
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or args.timeout < 0:
        parser.error("--timeout must be finite and nonnegative")
    if not re.fullmatch(r"[0-9a-fA-F]{40}|[0-9a-fA-F]{64}", args.base):
        parser.error("--base must be a full captured commit ID, not a moving ref such as HEAD")
    return args


def main() -> int:
    if HOOK_STATE in os.environ and Path(sys.argv[0]).name in HOOK_NAMES:
        return guarded_hook(Path(sys.argv[0]).name)
    args = parse_args()
    if "GIT_INDEX_FILE" in os.environ:
        raise TransactionError("Alternate indexes (GIT_INDEX_FILE) are unsupported; use the shared worktree index.")
    patch = args.patch.read_bytes()
    message = args.message_file.read_bytes() if args.message_file else args.message.encode()
    if not patch.strip() or not message.strip():
        raise TransactionError("The patch and commit message must both be nonempty.")

    git = Git(args.repo.resolve())
    git.repo = Path(git.value("rev-parse", "--show-toplevel")).resolve()
    git_dir = Path(git.value("rev-parse", "--absolute-git-dir")).resolve()
    branch = git.branch()
    signal.signal(signal.SIGINT, request_cancellation)
    signal.signal(signal.SIGTERM, request_cancellation)
    # Keep this inode: unlinking a flock file can allow two independent holders.
    with (git_dir / "patch-commit.lock").open("a+b") as lock:
        acquire_lock(lock, args.timeout)
        git.lock_fd = lock.fileno()
        transact(git, git_dir, branch, args.base, patch, message)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (TransactionError, OSError) as error:
        print(f"patch-commit: {error}", file=sys.stderr)
        sys.exit(130 if cancelled else 1)
