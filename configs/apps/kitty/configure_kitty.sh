echo "Configuring Kitty..."
mkdir -p ~/.config/kitty 2> /dev/null # Redirect stderr to suppress dir already exists log
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ln -f $current_dir/kitty.conf ~/.config/kitty/