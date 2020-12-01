echo "Configuring Visual Studio Code..."
mkdir -p ~/Library/Application\ Support/Code/User/ 2> /dev/null # Redirect stderr to suppress dir already exists log
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ln -f $current_dir/keybindings.json ~/Library/Application\ Support/Code/User/
ln -f $current_dir/settings.json ~/Library/Application\ Support/Code/User/