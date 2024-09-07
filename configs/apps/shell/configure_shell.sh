echo "Configuring .zshrc..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ln -f $current_dir/.zshrc ~/
ln -f $current_dir/.zsh_plugins ~/
ln -f $current_dir/.p10k.zsh ~/

# Setup fastlane completions
bundle exec fastlane enable_auto_complete

touch ~/.zshrc_local # Creates a local-only .zshrc file that is loaded by .zshrc