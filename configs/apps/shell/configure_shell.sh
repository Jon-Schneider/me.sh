echo "Configuring .zshrc..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ln -f $current_dir/.zshrc ~/
ln -f $current_dir/.p10k.zsh ~/