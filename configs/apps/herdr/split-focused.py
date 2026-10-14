"""Split the shortcut's focused pane while keeping focus on the original."""

import os
import sys

from herdr_api import api


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in {"right", "down"}:
        print("usage: split-focused.py right|down", file=sys.stderr)
        return 64
    api("pane.split", target_pane_id=os.environ["HERDR_ACTIVE_PANE_ID"],
        direction=sys.argv[1], focus=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
