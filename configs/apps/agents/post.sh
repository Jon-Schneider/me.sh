#!/bin/bash
set -euo pipefail

# Herdr owns its integration files and rewrites them on update, so install them
# after managed agent configs have been materialized. Those edits then land in
# deployed copies and stay out of the repository.
if command -v herdr > /dev/null; then
  echo "Configuring Herdr integrations..."
  for agent in pi claude codex opencode; do
    herdr integration install "$agent"
  done
else
  echo "Skipping Herdr integrations (herdr not installed)"
fi
