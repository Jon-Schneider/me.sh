#!/usr/bin/env python3
"""Split kept hunks by destination: base vs local fragment.

Reads a unified diff (the kept hunks from `me up`) on stdin, prompts once
per hunk, and writes two patch files preserving the original headers.
Default is base, matching historical `me up` behavior.

Scripted runs: ABSORB_DESTS="b l s ..." answers in order, restarted per
file by the caller. Each hunk consumes one token: b/base, l/local,
s/skip. Unknown or missing tokens default to base, except explicit `s`.
"""
import os
import sys

_RESET = "\033[0m"
_BOLD = "\033[1m"
_RED = "\033[31m"
_GREEN = "\033[32m"
_CYAN = "\033[36m"


def _color_enabled():
    if os.environ.get("NO_COLOR"):
        return False
    if os.environ.get("TERM") == "dumb":
        return False
    return True


def colorize_hunk(hunk):
    if not _color_enabled():
        return hunk
    out = []
    for line in hunk.splitlines(keepends=True):
        body = line.rstrip("\n")
        nl = "\n" if line.endswith("\n") else ""
        if body.startswith("@@"):
            out.append(f"{_BOLD}{_CYAN}{body}{_RESET}{nl}")
        elif body.startswith("+") and not body.startswith("+++"):
            out.append(f"{_GREEN}{body}{_RESET}{nl}")
        elif body.startswith("-") and not body.startswith("---"):
            out.append(f"{_RED}{body}{_RESET}{nl}")
        else:
            out.append(line)
    return "".join(out)


def destination_prompt(index, total):
    if not _color_enabled():
        return f"Hunk {index}/{total}\n", "[b]ase / [l]ocal fragment / [s]kip (default: base)? "
    head = f"{_BOLD}Hunk {index}/{total}{_RESET}\n"
    return head, "[b]ase / [l]ocal fragment / [s]kip (default: base)? "


def parse_diff(text):
    lines = text.splitlines(keepends=True)
    starts = [k for k, line in enumerate(lines) if line.startswith("@@")]
    if not starts:
        return text, []
    header = "".join(lines[: starts[0]])
    bounds = starts + [len(lines)]
    hunks = ["".join(lines[bounds[i] : bounds[i + 1]]) for i in range(len(starts))]
    return header, hunks


def main():
    if len(sys.argv) != 3:
        print("usage: absorb_destinations.py BASE_PATCH LOCAL_PATCH", file=sys.stderr)
        return 1
    base_out, local_out = sys.argv[1:3]
    text = sys.stdin.read()
    header, hunks = parse_diff(text)
    if not hunks:
        open(base_out, "w").write("")
        open(local_out, "w").write("")
        return 0

    scripted = os.environ.get("ABSORB_DESTS")
    if scripted is not None:
        answers = iter(scripted.split())
        prompt_in = prompt_out = None
    else:
        try:
            prompt_in = open("/dev/tty")
            prompt_out = open("/dev/tty", "w")
        except OSError:
            sys.stderr.write("No tty for destination choice; keeping all in base.\n")
            open(base_out, "w").write(text)
            open(local_out, "w").write("")
            return 0

    base, local = [], []
    try:
        for index, hunk in enumerate(hunks, 1):
            if scripted is not None:
                answer = next(answers, "b").lower()
                sys.stderr.write(f"Hunk {index}/{len(hunks)} destination: '{answer}'\n")
            else:
                head, prompt = destination_prompt(index, len(hunks))
                prompt_out.write(head + colorize_hunk(hunk))
                prompt_out.write(prompt)
                prompt_out.flush()
                answer = (prompt_in.readline() or "").strip().lower() or "b"
            if answer in ("l", "local"):
                local.append(hunk)
            elif answer in ("s", "skip", "q"):
                continue
            else:
                base.append(hunk)
    finally:
        if prompt_in:
            prompt_in.close()
        if prompt_out:
            prompt_out.close()

    open(base_out, "w").write(header + "".join(base) if base else "")
    open(local_out, "w").write(header + "".join(local) if local else "")
    return 0


if __name__ == "__main__":
    sys.exit(main())
