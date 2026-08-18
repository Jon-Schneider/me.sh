echo "Configuring git..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ln -sfn $current_dir/.gitignore ~/.gitignore
ln -sfn $current_dir/.gitconfig ~/.gitconfig
ln -sfn $current_dir/.gitconfig-js ~/.gitconfig_js
ln -sfn $current_dir/.gitconfig-ms ~/.gitconfig_ms
ln -sfn $current_dir/.gitattributes ~/.gitattributes
ln -sfn $current_dir/git-branch-select ~/bin/git-branch-select