echo "Configuring tmux..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ln -f $current_dir/.tmux.conf ~/

mkdir -p ~/bin
cp -v $current_dir/set_tmux_agent_status ~/bin/
cp -v $current_dir/clear_tmux_agent_status_if_no_agents ~/bin/
cp -v $current_dir/clean-claude-copy ~/bin/
cp -v $current_dir/clean-codex-copy ~/bin/
cp -v $current_dir/clean-gemini-copy ~/bin/
cp -v $current_dir/clean-agent-copy ~/bin/
cp -v $current_dir/tmux-app-key ~/bin/
cp -v $current_dir/tmux-micro-key ~/bin/
cp -v $current_dir/tmux-copy-mode-passthrough-binds ~/bin/
