#!/usr/bin/env python3
"""Compute the minimal merge fragment taking BASELINE to DESIRED.

Respects deep_merge semantics: dicts recurse, arrays concatenate with exact
duplicates dropped, scalars replace. Anything unrepresentable as a merge
(key deletions, array removals/reorders/in-place edits) exits 1 so the
caller can route those hunks to the base file instead.

Usage: fragment_extract.py BASELINE DESIRED [--format json|yaml|toml]
Baseline/desired are often extensionless temp files, hence --format.
Fragment is always emitted as JSON on stdout; deep_merge parses fragments
by their own suffix, so a .json fragment merges into any base format.
"""
import json
import subprocess
import sys
from pathlib import Path

FORMATS = ("json", "yaml", "toml")

MISSING = object()


class Unrepresentable(Exception):
    pass


def parse(path, fmt):
    if fmt == "json":
        return json.loads(Path(path).read_text())
    proc = subprocess.run(
        ["yq", f"--input-format={fmt}", "-o=json", ".", str(path)],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        print(f"fragment_extract: yq could not parse {path}: {proc.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
    return json.loads(proc.stdout)


def diff(base, want):
    if isinstance(base, dict) and isinstance(want, dict):
        out = {}
        for key in base:
            if key not in want:
                raise Unrepresentable(f"deleted key: {key}")
        for key, value in want.items():
            if key not in base:
                out[key] = value
            else:
                sub = diff(base[key], value)
                if sub is not MISSING:
                    out[key] = sub
        return out if out else MISSING
    if isinstance(base, list) and isinstance(want, list):
        added = [item for item in want if item not in base]
        if base + added != want:
            raise Unrepresentable("array reorder/removal/edit needs base")
        return added if added else MISSING
    if base == want:
        return MISSING
    return want


def main():
    args = sys.argv[1:]
    fmt = "json"
    positional = []
    i = 0
    while i < len(args):
        if args[i] == "--format" and i + 1 < len(args):
            fmt = args[i + 1]
            i += 2
        else:
            positional.append(args[i])
            i += 1
    if len(positional) != 2 or fmt not in FORMATS:
        print("usage: fragment_extract.py BASELINE DESIRED [--format json|yaml|toml]", file=sys.stderr)
        return 1
    base = parse(positional[0], fmt)
    want = parse(positional[1], fmt)
    try:
        frag = diff(base, want)
    except Unrepresentable as exc:
        print(f"fragment_extract: {exc}; route these hunks to base", file=sys.stderr)
        return 1
    if frag is MISSING:
        frag = {}
    print(json.dumps(frag, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
