#!/usr/bin/env python3
"""Fallback hunk picker for scripted/no-tty `me up` runs; interactive runs use git add -p.

Reads a unified diff on stdin, shows each hunk, and writes only the accepted
hunks (with the original file headers) to stdout. Prompts read from /dev/tty so
this works even when stdin is a pipe; with no tty it prints instructions and
selects nothing. Setting ABSORB_ANSWERS (e.g. "y n q") answers prompts in order
instead of reading the tty, for scripted runs and tests.
"""
import os
import sys


def parse_diff(text):
    """Split a unified diff into (header, [hunks]) where header holds all
    lines up to the first @@."""
    lines = text.splitlines(keepends=True)
    starts = [k for k, line in enumerate(lines) if line.startswith("@@")]
    if not starts:
        return text, []
    header = "".join(lines[: starts[0]])
    bounds = starts + [len(lines)]
    hunks = [
        "".join(lines[bounds[i]: bounds[i + 1]]) for i in range(len(starts))
    ]
    return header, hunks


def hunks_to_text(header, hunks):
    return lambda: header + "".join("".join(h) for h in hunks)


def main():
    text = sys.stdin.read()
    header, hunks = parse_diff(text)
    if not hunks:
        sys.stdout.write(text)
        return 0

    scripted = os.environ.get("ABSORB_ANSWERS")
    if scripted is not None:
        answers = iter(scripted.split())
        prompt_in = prompt_out = None
    else:
        try:
            prompt_in = open("/dev/tty")
        except OSError:
            sys.stderr.write(
                "No tty available for interactive selection; nothing absorbed.\n"
                "Full drift diff:\n" + text
            )
            return 0
        prompt_out = open("/dev/tty", "w")

    try:
        keep = []
        apply_all = False
        for index, hunk in enumerate(hunks, 1):
            if not apply_all:
                if scripted is not None:
                    answer = next(answers, "q").lower()
                    sys.stderr.write(f"Hunk {index}/{len(hunks)}: answer '{answer}'\n")
                else:
                    prompt_out.write(f"Hunk {index}/{len(hunks)}\n" + hunk)
                    prompt_out.write("[y]es / [n]o / [a]ll remaining / [q]uit? ")
                    prompt_out.flush()
                    answer = prompt_in.readline().strip().lower()
                if answer == "a":
                    apply_all = True
                elif answer == "q":
                    break
                elif answer != "y":
                    continue
            keep.append(hunk)
    finally:
        if prompt_in:
            prompt_in.close()
        if prompt_out:
            prompt_out.close()

    sys.stdout.write(header + "".join(keep))
    return 0


if __name__ == "__main__":
    sys.exit(main())
