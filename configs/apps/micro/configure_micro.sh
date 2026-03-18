echo "Configuring micro..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir -p ~/.config/micro 2> /dev/null # Redirect stderr to suppress dir already exists log

ln -f $current_dir/bindings.json ~/.config/micro
ln -f $current_dir/settings.json ~/.config/micro