#!/bin/bash

function message {
	GREEN='\033[0;32m'
	NOCOLOR='\033[0m'
	printf "${GREEN}$1${NOCOLOR}\n"
}

message "Updating Application Configuration..."

# Configure BBEdit 
message "Configuring BBEdit..."
mkdir -p ~/Library/Application\ Support/BBEdit 2> /dev/null # Redirect stderr to suppress dir already exists log
ln -Fs $(pwd)/configs/apps/bbedit/Setup ~/Library/Application\ Support/BBEdit/ # Have to symlink dir because changes aren't syncing with hard link (ln)
defaults write com.barebones.bbedit SurfNextPreviousInDisplayOrder -bool YES # Configure BBedit to navigate between tabs in display order, not open order
defaults write com.barebones.bbedit EditorSoftWrap -bool YES
defaults write com.barebones.bbedit SoftWrapStyle -integer 2
defaults write com.barebones.bbedit EditingWindowShowPageGuide -bool NO

# Configure git
message "Configuring git..."
ln -f configs/apps/git/.gitignore ~/.gitignore
ln -f configs/apps/git/.gitconfig ~/.gitconfig
ln -f configs/apps/git/.gitconfig-js ~/.gitconfig_js
ln -f configs/apps/git/.gitconfig-ms ~/.gitconfig_ms

# Configure Hammerspoon
message "Configuring Hammerspoon"
ln -fhs $(pwd)/configs/apps/hammerspoon ~/.hammerspoon # For some reason this would not work with a relative path, an absolute path was required

# Configure Karabiner-Elements
message "Configuring Karabiner Elements..."
ln -f configs/apps/karabiner/karabiner.json ~/.config/karabiner

# Configure Kitty
message "Configuring Kitty..."
mkdir -p ~/.config/kitty 2> /dev/null # Redirect stderr to suppress dir already exists log
ln -f configs/apps/kitty/kitty.conf ~/.config/kitty/

# Configure LLDB
message "Configuring LLDB..."
ln -f configs/apps/lldb/.lldbinit ~/

# Configure vim
message "Configuring Vim..."
mkdir -p ~/.vim/.backup ~/.vim/.tmp ~/.vim/.undo 2> /dev/null # Redirect stderr to suppress dir already exists log
ln -f configs/apps/vim/.vimrc ~/

# Configure Visual Studio Code
message "Configuring Visual Studio Code..."
mkdir -p ~/Library/Application\ Support/Code/User/ 2> /dev/null # Redirect stderr to suppress dir already exists log
ln -f configs/apps/vscode/keybindings.json ~/Library/Application\ Support/Code/User/
ln -f configs/apps/vscode/settings.json ~/Library/Application\ Support/Code/User/

# Configure .zshrc
message "Configuring .zshrc..."
ln -f configs/apps/zsh/.zshrc ~/