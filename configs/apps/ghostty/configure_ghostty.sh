echo "Configuring Ghostty..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir ~/.config/ghostty
ln -f $current_dir/config ~/.config/ghostty/config