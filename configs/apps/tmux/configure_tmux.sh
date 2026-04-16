echo "Configuring tmux..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ln -f $current_dir/.tmux.conf ~/

mkdir ~/bin
cp -v $current_dir/set_tmux_agent_status ~/bin/
cp -v $current_dir/clear_tmux_agent_status_if_no_agents ~/bin/
