#!/bin/sh
set -u

if [ -z "${HERDR_PLUGIN_ROOT:-}" ] || [ -z "${HERDR_PLUGIN_STATE_DIR:-}" ]; then
    echo "me.caffeinate: plugin runtime paths are unavailable" >&2
    exit 1
fi

shell_quote() {
    # POSIX single-quote escaping: a'b -> 'a'\''b'
    printf "'"
    printf '%s' "$1" | sed "s/'/'\\\\''/g"
    printf "'"
}

toml_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

helper=$(shell_quote "$HERDR_PLUGIN_ROOT/bin/status-indicator")
state=$(shell_quote "$HERDR_PLUGIN_STATE_DIR")
command=$(toml_escape "$helper $state")

cat <<EOF_SNIPPET
Add this entry to your existing [ui] tab_bar_right array in ~/.config/herdr/config.toml:

{ type = "command", command = "$command", interval_seconds = 5, timeout_seconds = 1 }

Then run:
  herdr server reload-config

The indicator is optional. It prints ☕ only while at least one plugin-owned
caffeinate assertion is actually alive.
EOF_SNIPPET
