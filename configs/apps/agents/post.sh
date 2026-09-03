#!/bin/bash
set -euo pipefail

skills_manifest="$ME_UNIT_DIR/external-skills.yml"

if [[ -f "$skills_manifest" ]]; then
  if ! command -v npx > /dev/null; then
    echo "npx not found; run 'me homebrew' first" >&2
    exit 1
  fi

  skill_agents=()
  while IFS= read -r agent; do
    skill_agents+=("$agent")
  done < <(yq -r '.agents[]' "$skills_manifest")

  while IFS=$'\t' read -r source skill; do
    echo "Installing agent skill $skill from $source..."
    npx -y skills@latest add "$source" \
      --global \
      --yes \
      --skill "$skill" \
      --agent "${skill_agents[@]}"
  done < <(yq -r '.skills[] | [.source, .name] | @tsv' "$skills_manifest")
fi

# Machine-local Pi extensions (*.local.ts) are never committed, so they cannot
# be declared in config.yml. Link them here instead, stripping the `.local`
# suffix so Pi loads them under their real names.
local_extensions_dir="$ME_UNIT_DIR/Pi/extensions"
pi_extensions_dir="$HOME/.pi/agent/extensions"
if [[ -d "$local_extensions_dir" ]]; then
  mkdir -p "$pi_extensions_dir"
  shopt -s nullglob
  for src in "$local_extensions_dir"/*.local.ts; do
    base="$(basename "$src" .local.ts)"
    dest="$pi_extensions_dir/$base.ts"
    if [[ -e "$dest" && ! -L "$dest" ]]; then
      echo "$dest exists and is not a symlink; leaving it untouched" >&2
      continue
    fi
    ln -sfn "$src" "$dest"
  done
  shopt -u nullglob
fi

# Herdr owns its integration files and rewrites them on update, so install them
# after managed agent configs have been materialized. Those edits then land in
# deployed copies and stay out of the repository.
if command -v herdr > /dev/null; then
  for agent in pi claude codex opencode; do
    herdr integration install "$agent"
  done
else
  echo "Skipping Herdr integrations (herdr not installed)"
fi
