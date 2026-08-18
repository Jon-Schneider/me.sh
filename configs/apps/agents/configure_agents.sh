echo "Configuring Agents..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.codex"
mkdir -p "$HOME/.config/opencode/plugins"
mkdir -p "$HOME/.pi/agent/extensions"
mkdir -p "$HOME/.agents/skills"
mkdir -p "$HOME/.codex/skills"
mkdir -p "$HOME/.claude/skills"

echo "Configiring ~/.agents..."
ln -f "$current_dir/AGENTS.md" "$HOME/.agents/AGENTS.md"

echo "Configuring Claude..."
ln -f "$current_dir/AGENTS.md" "$HOME/.claude/CLAUDE.md"
ln -f "$current_dir/Claude/settings.json" "$HOME/.claude"
ln -f "$current_dir/Claude/statusline-command.sh" "$HOME/.claude"

echo "Configuring Codex..."
ln -sfn "$current_dir/Codex/config.toml" "$HOME/.codex/config.toml"
ln -sfn "$current_dir/Codex/hooks.json" "$HOME/.codex/hooks.json"

echo "Configuring Opencode..."
ln -f "$current_dir/Opencode/opencode.json" "$HOME/.config/opencode"
ln -f "$current_dir/Opencode/opencode-tmux-agent-status.js" "$HOME/.config/opencode/plugins"

echo "Configuring Pi..."
ln -sfn "$current_dir/Pi/extensions/dcg-guard.ts" "$HOME/.pi/agent/extensions/dcg-guard.ts"
ln -sfn "$current_dir/Pi/extensions/tmux-agent-status.ts" "$HOME/.pi/agent/extensions/tmux-agent-status.ts"

echo "Configuring Skills..."
ln -Fsn "$current_dir/Skills/claude-review" "$HOME/.agents/skills/"

ln -Fsn "$current_dir/Skills/codex-review" "$HOME/.claude/skills/"

ln -Fsn "$current_dir/Skills/hate-review" "$HOME/.agents/skills/"
ln -Fsn "$current_dir/Skills/hate-review" "$HOME/.claude/skills/"

ln -Fsn "$current_dir/Skills/hate-reviewer-cycle" "$HOME/.claude/skills/"

ln -Fsn "$current_dir/Skills/patch-commit" "$HOME/.agents/skills/"
ln -Fsn "$current_dir/Skills/patch-commit" "$HOME/.claude/skills/"
ln -Fsn "$current_dir/Skills/patch-commit" "$HOME/.codex/skills/"

ln -Fsn "$current_dir/Skills/rewrite-pr-history" "$HOME/.agents/skills/"
ln -Fsn "$current_dir/Skills/rewrite-pr-history" "$HOME/.claude/skills/"

ln -Fsn "$current_dir/Skills/use-jira" "$HOME/.agents/skills/"
ln -Fsn "$current_dir/Skills/use-jira" "$HOME/.claude/skills/"

echo "Configuring Agent bin..."
ln -f $current_dir/bin/fa ~/bin/ 
ln -f $current_dir/bin/xcsift-for-apple-build-tools ~/bin/ 
ln -f "$current_dir/bin/sync-opencode-omlx-models" "$HOME/bin/"
