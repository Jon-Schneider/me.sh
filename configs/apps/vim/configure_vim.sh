echo "Configuring Vim..."
mkdir -p ~/.vim/.backup ~/.vim/.tmp ~/.vim/.undo 2> /dev/null # Redirect stderr to suppress dir already exists log
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ln -sfn $current_dir/.vimrc ~/.vimrc