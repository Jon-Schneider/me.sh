echo "Configuring .zshrc..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir -p ~/.config/htop 2> /dev/null # Redirect stderr to suppress dir already exists log
ln -sfn $current_dir/.zshrc ~/.zshrc
ln -sfn $current_dir/.zsh_plugins ~/.zsh_plugins
ln -sfn $current_dir/starship.toml ~/.config/starship.toml
ln -sfn $current_dir/autoenv.zsh ~/bin/autoenv.zsh

# Setup fastlane completions
# bundle exec fastlane enable_auto_complete

touch ~/.zshrc_local # Creates a local-only .zshrc file that is loaded by .zshrc