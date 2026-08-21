#!/bin/bash
set -euo pipefail

echo "Configuring tmux..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ln -sfn $current_dir/.tmux.conf ~/.tmux.conf

mkdir -p ~/bin
ln -sfn $current_dir/set_tmux_agent_status ~/bin/set_tmux_agent_status
ln -sfn $current_dir/clear_tmux_agent_status_if_no_agents ~/bin/clear_tmux_agent_status_if_no_agents
ln -sfn $current_dir/clean-claude-copy ~/bin/clean-claude-copy
ln -sfn $current_dir/clean-codex-copy ~/bin/clean-codex-copy
ln -sfn $current_dir/clean-agent-copy ~/bin/clean-agent-copy
ln -sfn $current_dir/tmux-app-key ~/bin/tmux-app-key
ln -sfn $current_dir/tmux-copy-mode-passthrough-binds ~/bin/tmux-copy-mode-passthrough-binds
