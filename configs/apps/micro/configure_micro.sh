echo "Configuring micro..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir -p ~/.config/micro 2> /dev/null # Redirect stderr to suppress dir already exists log

ln -sfn $current_dir/bindings.json ~/.config/micro/bindings.json
ln -sfn $current_dir/settings.json ~/.config/micro/settings.json