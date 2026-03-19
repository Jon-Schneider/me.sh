echo "Configuring Agents..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir ~/.claude
mkdir ~/.codex
mkdir ~/.gemini
mkdir ~/.kimi
mkdir -p ~/.config/opencode/plugins
mkdir -p "~/.agents/skills"
mkdir -p "~/.claude/skills"
mkdir -p "~/.gemini/skills/"

echo "Configuring Claude..."
ln -f $current_dir/AGENTS.md ~/.claude/CLAUDE.md
ln -f $current_dir/Claude/settings.json ~/.claude

echo "Configuring Codex..."
ln -f $current_dir/AGENTS.md ~/.codex/AGENTS.md
ln -f $current_dir/Codex/config.toml ~/.codex

echo "Configuring Gemini..."
ln -f $current_dir/AGENTS.md ~/.gemini/GEMINI.md

echo "Configuring Kimi..."
ln -f $current_dir/AGENTS.md ~/.kimi/AGENTS.md

echo "Configuring Opencode..."
ln -f $current_dir/Opencode/opencode.json ~/.config/opencode
ln -f $current_dir/Opencode/opencode-tmux-agent-status.js ~/.config/opencode/plugins

echo "Configuring Skills..."
ln -f $current_dir/Skills/codex-review "~/.claude/skills/"
ln -f $current_dir/Skills/codex-review "~/.gemini/skills/"

ln -Fs $current_dir/Skills/use-jira "~/.agents/skills/"
ln -Fs $current_dir/Skills/use-jira "~/.claude/skills/"