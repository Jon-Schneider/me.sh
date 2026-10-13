#!/bin/bash
# Keep the existing keybinding entrypoint; use the socket-based sidebar walker.
exec /usr/bin/python3 "$HOME/Developer/jsc/me.sh/configs/apps/herdr/herdr-tab-step" "$@"
