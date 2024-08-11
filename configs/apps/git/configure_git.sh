echo "Configuring git..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ln -f $current_dir/.gitignore ~/.gitignore
ln -f $current_dir/.gitconfig ~/.gitconfig
ln -f $current_dir/.gitconfig-js ~/.gitconfig_js
ln -f $current_dir/.gitconfig-ms ~/.gitconfig_ms
ln -f $current_dir/.gitattributes ~/.gitattributes