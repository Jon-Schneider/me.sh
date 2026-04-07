echo "Configuring agent-safehouse..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p "$HOME/.config/agent-safehouse/profiles"

ln -Fsn "$current_dir/55-integrations-optional" "$HOME/.config/agent-safehouse/profiles/55-integrations-optional"