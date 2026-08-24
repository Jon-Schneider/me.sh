#!/usr/bin/env python3
"""Merge an overlay fragment into a config document.

Usage: deep_merge.py TARGET FRAGMENT [TARGET_FORMAT]

Each side is parsed by its own suffix (.json, .yml/.yaml, .toml; YAML and TOML
via yq), the fragment is deep-merged into the target -- dicts recurse, arrays
concatenate with exact duplicates dropped, scalars replace -- and TARGET is
rewritten in its own format. Temp targets without a suffix must pass
TARGET_FORMAT explicitly.
"""

import json
import subprocess
import sys
from pathlib import Path

FORMATS = {".json": "json", ".yaml": "yaml", ".yml": "yaml", ".toml": "toml"}


def fail(msg):
    print(f"deep_merge: {msg}", file=sys.stderr)
    sys.exit(1)


def parse(path, fmt=None):
    if fmt is None:
        fmt = FORMATS.get(path.suffix)
    if fmt not in FORMATS.values():
        fail(f"unsupported config format: {path}")
    if fmt == "json":
        return json.loads(path.read_text())
    proc = subprocess.run(
        ["yq", f"--input-format={fmt}", "-o=json", ".", str(path)],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        fail(f"yq could not parse {path}: {proc.stderr.strip()}")
    return json.loads(proc.stdout)


def emit(doc, fmt):
    if fmt == "json":
        return json.dumps(doc, indent=2) + "\n"
    proc = subprocess.run(
        ["yq", "--input-format=json", f"--output-format={fmt}", "."],
        input=json.dumps(doc), capture_output=True, text=True,
    )
    if proc.returncode != 0:
        fail(f"yq could not emit {fmt}: {proc.stderr.strip()}")
    return proc.stdout


def merge(base, override):
    if isinstance(base, dict) and isinstance(override, dict):
        merged = dict(base)
        for key, value in override.items():
            merged[key] = merge(base[key], value) if key in base else value
        return merged
    if isinstance(base, list) and isinstance(override, list):
        return base + [item for item in override if item not in base]
    return override


def main():
    if len(sys.argv) not in (3, 4):
        fail("usage: deep_merge.py TARGET FRAGMENT [TARGET_FORMAT]")
    target, fragment = (Path(arg) for arg in sys.argv[1:3])
    target_fmt = sys.argv[3] if len(sys.argv) == 4 else FORMATS.get(target.suffix)
    if target_fmt not in FORMATS.values():
        fail(f"unknown target format: {target_fmt!r} ({target})")
    base = parse(target, target_fmt)
    overlay = parse(fragment)
    if base is None:
        fail(f"target document is empty: {target}")
    if overlay is None:
        fail(f"fragment is empty, refusing to wipe target: {fragment}")
    Path(target).write_text(emit(merge(base, overlay), target_fmt))


if __name__ == "__main__":
    main()
