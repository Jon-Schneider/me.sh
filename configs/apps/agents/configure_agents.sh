#!/bin/bash
set -euo pipefail

echo "Configuring Agents..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.codex"
mkdir -p "$HOME/.config/opencode/plugins"
mkdir -p "$HOME/.pi/agent/extensions"
mkdir -p "$HOME/.agents/skills"
mkdir -p "$HOME/.codex/skills"
mkdir -p "$HOME/.claude/skills"

echo "Configuring ~/.agents..."
ln -sfn "$current_dir/AGENTS.md" "$HOME/.agents/AGENTS.md"

echo "Configuring Claude..."
ln -sfn "$current_dir/AGENTS.md" "$HOME/.claude/CLAUDE.md"
ln -sfn "$current_dir/Claude/settings.json" "$HOME/.claude/settings.json"
ln -sfn "$current_dir/Claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"

echo "Configuring Codex..."
ln -sfn "$current_dir/Codex/config.toml" "$HOME/.codex/config.toml"
ln -sfn "$current_dir/Codex/hooks.json" "$HOME/.codex/hooks.json"

echo "Configuring Opencode..."
ln -sfn "$current_dir/Opencode/opencode.json" "$HOME/.config/opencode/opencode-shared.json"
ln -sfn "$current_dir/Opencode/opencode-tmux-agent-status.js" "$HOME/.config/opencode/plugins/opencode-tmux-agent-status.js"

echo "Configuring Pi..."
ln -sfn "$current_dir/AGENTS.md" "$HOME/.pi/agent/AGENTS.md"
ln -sfn "$current_dir/Pi/settings.json" "$HOME/.pi/agent/settings.json"
ln -sfn "$current_dir/Pi/extensions/dcg-guard.ts" "$HOME/.pi/agent/extensions/dcg-guard.ts"
ln -sfn "$current_dir/Pi/extensions/tmux-agent-status.ts" "$HOME/.pi/agent/extensions/tmux-agent-status.ts"
ln -sfn "$current_dir/Pi/extensions/statusline.ts" "$HOME/.pi/agent/extensions/statusline.ts"
ln -sfn "$current_dir/Pi/statusline.json" "$HOME/.pi/agent/statusline.json"

echo "Configuring Skills..."
ln -Fsn "$current_dir/Skills/claude-review" "$HOME/.agents/skills/"

ln -Fsn "$current_dir/Skills/codex-review" "$HOME/.claude/skills/"

ln -Fsn "$current_dir/Skills/hate-review" "$HOME/.agents/skills/"
ln -Fsn "$current_dir/Skills/hate-review" "$HOME/.claude/skills/"

ln -Fsn "$current_dir/Skills/hate-reviewer-cycle" "$HOME/.agents/skills/"
ln -Fsn "$current_dir/Skills/hate-reviewer-cycle" "$HOME/.claude/skills/"

ln -Fsn "$current_dir/Skills/patch-commit" "$HOME/.agents/skills/"
ln -Fsn "$current_dir/Skills/patch-commit" "$HOME/.claude/skills/"
ln -Fsn "$current_dir/Skills/patch-commit" "$HOME/.codex/skills/"

ln -Fsn "$current_dir/Skills/rewrite-pr-history" "$HOME/.agents/skills/"
ln -Fsn "$current_dir/Skills/rewrite-pr-history" "$HOME/.claude/skills/"

ln -Fsn "$current_dir/Skills/use-jira" "$HOME/.agents/skills/"
ln -Fsn "$current_dir/Skills/use-jira" "$HOME/.claude/skills/"

echo "Configuring Agent bin..."
ln -sfn "$current_dir/bin/fa" "$HOME/bin/fa"
ln -sfn "$current_dir/bin/pt" "$HOME/bin/pt"
ln -sfn "$current_dir/bin/wt" "$HOME/bin/wt"
ln -sfn "$current_dir/bin/xcsift-for-apple-build-tools" "$HOME/bin/xcsift-for-apple-build-tools"
ln -sfn "$current_dir/bin/sync-opencode-omlx-models" "$HOME/bin/sync-opencode-omlx-models"

# Herdr owns its integration files and rewrites them on update, so install them
# through herdr rather than tracking copies here. This has to run after the
# symlinks above, because installing edits the agent configs in place — those
# edits land in the repo and are stripped back out by the herdr-hooks clean
# filter (see clean_herdr-hooks).
if command -v herdr > /dev/null; then
  echo "Configuring Herdr integrations..."
  for agent in pi claude codex opencode; do
    herdr integration install "$agent"
  done
else
  echo "Skipping Herdr integrations (herdr not installed)"
fi
