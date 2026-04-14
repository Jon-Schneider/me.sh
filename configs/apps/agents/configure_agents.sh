echo "Configuring Agents..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.codex"
mkdir -p "$HOME/.gemini"
mkdir -p "$HOME/.kimi"
mkdir -p "$HOME/.config/opencode/plugins"
mkdir -p "$HOME/.agents/skills"
mkdir -p "$HOME/.codex/skills"
mkdir -p "$HOME/.claude/skills"
mkdir -p "$HOME/.gemini/skills"

echo "Configiring ~/.agents..."
ln -f "$current_dir/AGENTS.md" "$HOME/.agents/AGENTS.md"

echo "Configuring Claude..."
ln -f "$current_dir/AGENTS.md" "$HOME/.claude/CLAUDE.md"
ln -f "$current_dir/Claude/settings.json" "$HOME/.claude"
ln -f "$current_dir/Claude/statusline-command.sh" "$HOME/.claude"

echo "Configuring Codex..."
ln -f "$current_dir/AGENTS.md" "$HOME/.codex/AGENTS.md"
ln -f "$current_dir/Codex/config.toml" "$HOME/.codex"
ln -f "$current_dir/Codex/hooks.json" "$HOME/.codex"

echo "Configuring Gemini..."
ln -f "$current_dir/AGENTS.md" "$HOME/.gemini/GEMINI.md"

echo "Configuring Kimi..."
ln -f "$current_dir/AGENTS.md" "$HOME/.kimi/AGENTS.md"

echo "Configuring Opencode..."
ln -f "$current_dir/Opencode/opencode.json" "$HOME/.config/opencode"
ln -f "$current_dir/Opencode/opencode-tmux-agent-status.js" "$HOME/.config/opencode/plugins"

echo "Configuring Skills..."
ln -Fsn "$current_dir/Skills/claude-review" "$HOME/.agents/skills/"

ln -Fsn "$current_dir/Skills/codex-review" "$HOME/.claude/skills/"
ln -Fsn "$current_dir/Skills/codex-review" "$HOME/.gemini/skills/"

ln -Fsn "$current_dir/Skills/rewrite-pr-history" "$HOME/.agents/skills/"
ln -Fsn "$current_dir/Skills/rewrite-pr-history" "$HOME/.claude/skills/"

ln -Fsn "$current_dir/Skills/use-jira" "$HOME/.agents/skills/"
ln -Fsn "$current_dir/Skills/use-jira" "$HOME/.claude/skills/"
