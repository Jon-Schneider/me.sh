#!/bin/bash

function message {
	GREEN='\033[0;32m'
	NOCOLOR='\033[0m'
	printf "${GREEN}$1${NOCOLOR}\n"
}

message "Updating Application Configuration..."

# Configure BBEdit 
message "Configuring BBEdit..."
mkdir -p ~/Library/Application\ Support/BBEdit
ln -s $(pwd)/bbedit/Setup ~/Library/Application\ Support/BBEdit/Setup # Have to symlink dir because changes aren't syncing with hard link (ln)
defaults write com.barebones.bbedit SurfNextPreviousInDisplayOrder -bool YES # Configure BBedit to navigate between tabs in display order, not open order
defaults write com.barebones.bbedit EditorSoftWrap -bool YES
defaults write com.barebones.bbedit SoftWrapStyle -integer 2
defaults write com.barebones.bbedit EditingWindowShowPageGuide -bool NO

# Configure git
message "Configuring git..."
ln git/.gitignore ~/.gitignore
ln git/.gitconfig ~/.gitconfig
ln git/.gitconfig-js ~/.gitconfig_js
ln git/.gitconfig-ms ~/.gitconfig_ms

# Configure Hammerspoon
message "Configuring Hammerspoon"
ln -s $(pwd)/hammerspoon ~/.hammerspoon # For some reason this would not work with a relative path, an absolute path was required

# Configure Karabiner-Elements
message "Configuring Karabiner Elements..."
ln karabiner/karabiner.json ~/.config/karabiner

# Configure Kitty
message "Configuring Kitty..."
mkdir -p ~/.config/kitty
ln kitty.conf ~/.config/kitty/

# Configure LLDB
message "Configuring LLDB..."
ln .lldbinit ~/

# Configure vim
message "Configuring Vim..."
mkdir -p ~/.vim/.backup ~/.vim/.tmp ~/.vim/.undo
ln .vimrc ~/

# Configure Visual Studio Code
message "Configuring Visual Studio Code..."
mkdir ~/Library/Application\ Support/Code/User/
ln vscode/keybindings.json ~/Library/Application\ Support/Code/User/
ln vscode/settings.json ~/Library/Application\ Support/Code/User/

# Configure .zshrc
message "Configuring .zshrc..."
ln .zshrc ~/