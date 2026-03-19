#!/usr/bin/env python3
"""
Run Claude Code in print mode for an iterative review loop.

This wrapper keeps the CLI invocation stable and returns a small, structured
payload that is easy for a subagent to pass back to the main agent.
"""

from __future__ import annotations

import argparse
import shlex
import subprocess
import sys
import textwrap
import uuid
from pathlib import Path


def scope_context(args: argparse.Namespace) -> str:
    return args.scope_context.strip()


def build_initial_prompt(args: argparse.Namespace) -> str:
    current_scope = scope_context(args)
    scope_details = []
    if args.base_branch:
        scope_details.append(f"Base branch: `{args.base_branch}`.")
    if args.commit:
        scope_details.append(f"Commit: `{args.commit}`.")

    body = [
        "Review the requested code changes in this repository.",
        "",
        "Scope:",
        current_scope,
    ]

    if scope_details:
        body.extend(["", *scope_details])

    body.extend(
        [
        "",
        "Instructions:",
        "- Inspect only the requested scope.",
        "- Focus on actionable issues: correctness, regressions, risky edge cases, missing tests, and maintainability problems.",
        "- Prefer concise findings ordered by severity.",
        "- Include file paths and line numbers when you can.",
        "- Do not edit files, do not make commits, and keep commands read-only.",
        "- If there are no actionable findings, say that explicitly.",
        ]
    )

    if args.user_request:
        body.extend(["", "User request:", args.user_request.strip()])

    for extra in args.extra_instruction:
        body.extend(["", "Additional instruction:", extra.strip()])

    return "\n".join(body).strip()


def build_resume_prompt(args: argparse.Namespace) -> str:
    current_scope = scope_context(args)
    body = [
        "I've addressed your prior review feedback. Re-review the current state of the requested changes.",
        "",
        "Scope:",
        current_scope,
        "",
        "Instructions:",
        "- Focus on remaining actionable issues only.",
        "- Do not repeat findings that are already resolved.",
        "- Treat style-only disagreements as non-blocking and say so explicitly.",
        "- Include file paths and line numbers when you can.",
        "- If the review is now clean, say that explicitly.",
    ]

    if args.summary:
        body.extend(["", "Changes since the previous round:", args.summary.strip()])

    if args.user_request:
        body.extend(["", "User request:", args.user_request.strip()])

    for extra in args.extra_instruction:
        body.extend(["", "Additional instruction:", extra.strip()])

    return "\n".join(body).strip()


def build_command(args: argparse.Namespace, prompt: str, session_id: str) -> list[str]:
    command = ["claude"]

    if args.mode == "initial":
        command.extend(["--session-id", session_id])
    else:
        command.extend(["--resume", session_id])

    command.extend(["-p", "--output-format", "text"])

    if args.model:
        command.extend(["--model", args.model])

    if args.permission_mode:
        command.extend(["--permission-mode", args.permission_mode])

    for extra_arg in args.claude_arg:
        command.append(extra_arg)

    command.append(prompt)
    return command


def validate_args(args: argparse.Namespace) -> None:
    repo_root = Path(args.repo_root).expanduser().resolve()
    if not repo_root.exists():
        raise SystemExit(f"ERROR: repo root does not exist: {repo_root}")
    if not repo_root.is_dir():
        raise SystemExit(f"ERROR: repo root is not a directory: {repo_root}")
    args.repo_root = str(repo_root)

    if args.mode == "initial":
        if not args.scope_context:
            raise SystemExit("ERROR: --scope-context is required for initial mode")
        if args.scope in {"base", "both"} and not args.base_branch:
            raise SystemExit("ERROR: --base-branch is required for scope 'base' or 'both'")
        if args.scope == "commit" and not args.commit:
            raise SystemExit("ERROR: --commit is required for scope 'commit'")
    else:
        if not args.session_id:
            raise SystemExit("ERROR: --session-id is required for resume mode")
        if not args.scope_context:
            raise SystemExit("ERROR: --scope-context is required for resume mode")


def run_command(command: list[str], repo_root: str) -> tuple[int, str, str]:
    completed = subprocess.run(
        command,
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    return completed.returncode, completed.stdout.strip(), completed.stderr.strip()


def format_dry_run(command: list[str], prompt: str) -> str:
    wrapped_prompt = textwrap.indent(prompt, "  ")
    return "\n".join(
        [
            f"[DRY RUN] Command: {shlex.join(command)}",
            "[DRY RUN] Prompt:",
            wrapped_prompt,
        ]
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Claude Code review calls with a persistent session."
    )
    subparsers = parser.add_subparsers(dest="mode", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--repo-root", required=True, help="Repository root to run Claude in")
    common.add_argument("--user-request", default="", help="Original user request or review focus")
    common.add_argument(
        "--extra-instruction",
        action="append",
        default=[],
        help="Extra instruction to append to the Claude prompt (repeatable)",
    )
    common.add_argument(
        "--scope-context",
        default="",
        help="Human-readable description of the review scope",
    )
    common.add_argument("--model", default="", help="Optional Claude model alias or full name")
    common.add_argument(
        "--permission-mode",
        default="",
        help="Claude permission mode to use",
    )
    common.add_argument(
        "--claude-arg",
        action="append",
        default=[],
        help="Extra raw Claude CLI argument to append (repeatable)",
    )
    common.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the command and prompt instead of invoking Claude",
    )

    initial = subparsers.add_parser("initial", parents=[common])
    initial.add_argument(
        "--scope",
        required=True,
        choices=["uncommitted", "base", "both", "commit", "files"],
        help="Review scope",
    )
    initial.add_argument("--base-branch", default="", help="Base branch for branch review")
    initial.add_argument("--commit", default="", help="Commit SHA for commit review")
    initial.add_argument(
        "--session-id",
        default="",
        help="Optional explicit Claude session id for the initial review",
    )

    resume = subparsers.add_parser("resume", parents=[common])
    resume.add_argument("--session-id", required=True, help="Existing Claude session id")
    resume.add_argument(
        "--summary",
        default="",
        help="Short summary of what changed since the last review round",
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()
    validate_args(args)

    session_id = args.session_id or str(uuid.uuid4())
    prompt = build_initial_prompt(args) if args.mode == "initial" else build_resume_prompt(args)
    command = build_command(args, prompt, session_id)

    if args.dry_run:
        review = format_dry_run(command, prompt)
        print(f"SESSION_ID: {session_id}")
        print("REVIEW:")
        print(review)
        return 0

    exit_code, stdout, stderr = run_command(command, args.repo_root)
    if exit_code != 0:
        message = stderr or stdout or f"claude exited with status {exit_code}"
        print(f"ERROR: {message}")
        return exit_code
    if not stdout:
        message = stderr or "claude returned no review text"
        print(f"ERROR: {message}")
        return 1

    print(f"SESSION_ID: {session_id}")
    print("REVIEW:")
    print(stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
