echo "Configuring Ghostty..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir ~/.config/ghostty
mkdir ~/.config/ghostty/themes

ln -f $current_dir/config ~/.config/ghostty/config
ln -f $current_dir/themes/jon ~/.config/ghostty/themes/jon