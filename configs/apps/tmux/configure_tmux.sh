echo "Configuring tmux..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ln -f $current_dir/.tmux.conf ~/