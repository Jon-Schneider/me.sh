#!/usr/bin/env python3
"""Rename an ncdu selection on its filesystem, then delete it detached."""

import os
import subprocess
import sys
import tempfile


# Arguments are passed separately, never interpolated into shell code. Keep the
# staging directory and error log when rm fails so failures can be inspected.
WORKER = '''
/bin/rm -rf -- "$1/item" &&
    /bin/rm -f -- "$1/error.log" &&
    /bin/rmdir -- "$1"
'''


def delete_background(path):
    # Strip trailing slashes so a symlink to a directory stays a symlink.
    path = os.fspath(path).rstrip("/")
    if not path or os.path.basename(path) in (".", ".."):
        raise ValueError("refusing to delete a root, '.' or '..'")
    source = os.path.abspath(path)
    if os.path.dirname(source) == source:
        raise ValueError("refusing to delete a filesystem root")
    os.lstat(source)

    staging = tempfile.mkdtemp(prefix=".ncdu-delete-", dir=os.path.dirname(source))
    moved = False
    try:
        with open(os.path.join(staging, "error.log"), "xb") as errors:
            # Unlike mv, rename never falls back to a recursive copy on EXDEV.
            os.rename(source, os.path.join(staging, "item"))
            moved = True
            subprocess.Popen(
                ["/bin/sh", "-c", WORKER, "ncdu-delete", staging],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=errors,
                cwd="/",
                start_new_session=True,
                close_fds=True,
            )
    except OSError as error:
        if moved:
            # Do not restore over a newly created item at the original path.
            raise OSError(f"could not start deletion; data retained in {staging!r}: {error}") from error
        log = os.path.join(staging, "error.log")
        if os.path.exists(log):
            os.unlink(log)
        os.rmdir(staging)
        raise


def main():
    if len(sys.argv) != 2:
        print("usage: delete-background PATH", file=sys.stderr)
        return 2
    try:
        delete_background(sys.argv[1])
    except (OSError, ValueError) as error:
        print(f"ncdu background deletion: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
