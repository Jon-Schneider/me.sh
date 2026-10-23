#!/usr/bin/python3
"""Compatibility entrypoint for the local me.confirm-close plugin."""

from pathlib import Path
import runpy


if __name__ == "__main__":
    runpy.run_path(str(Path(__file__).resolve().with_name("plugin-confirm-close") / "close.py"),
                   run_name="__main__")
