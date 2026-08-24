#!/bin/bash
set -euo pipefail

local_dir="$HOME/.config/me.sh/karabiner"
local_module="$local_dir/local.libsonnet"
output="$HOME/.config/karabiner/karabiner.json"

if ! command -v jsonnet > /dev/null; then
  echo "jsonnet not found. Install it with 'brew install go-jsonnet'." >&2
  exit 1
fi

mkdir -p "$local_dir" "$(dirname "$output")"

if [[ ! -f "$local_module" ]]; then
  echo "Seeding empty $local_module"
  printf '{\n  rules: [],\n}\n' > "$local_module"
fi

# Machine-private rules live outside Git; -J resolves `import
# 'local.libsonnet'` to them.
temp_output="$(mktemp)"
trap 'rm -f "$temp_output"' EXIT
jsonnet -J "$local_dir" "$ME_UNIT_DIR/karabiner.jsonnet" > "$temp_output"
mv "$temp_output" "$output"
trap - EXIT

echo "Rendered $output"
