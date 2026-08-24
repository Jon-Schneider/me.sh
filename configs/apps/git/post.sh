#!/bin/bash
set -euo pipefail

# ~/.gitconfig has to stay a real, untracked file: it is where `git config
# --global` and machine setup tools (iapsshctl) write, and those writes must not
# land in this repo. It includes the tracked config first, so anything written
# afterwards overrides it.
if [[ -L "$HOME/.gitconfig" ]]; then
  unlink "$HOME/.gitconfig"
fi
if ! grep -qs 'gitconfig_shared' "$HOME/.gitconfig"; then
  existing_config="$(cat "$HOME/.gitconfig" 2>/dev/null || true)"
  {
    printf '[include]\n\tpath = ~/.gitconfig_shared\n'
    if [[ -n "$existing_config" ]]; then
      printf '%s\n' "$existing_config"
    fi
  } > "$HOME/.gitconfig"
fi
