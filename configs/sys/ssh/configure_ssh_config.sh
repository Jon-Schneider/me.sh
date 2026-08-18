echo "Configuring SSH..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir -p ~/.ssh
ln -sfn $current_dir/config ~/.ssh/config
