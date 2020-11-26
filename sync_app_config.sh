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
ln -Fs $(pwd)/configs/bbedit/Setup ~/Library/Application\ Support/BBEdit/ # Have to symlink dir because changes aren't syncing with hard link (ln)
defaults write com.barebones.bbedit SurfNextPreviousInDisplayOrder -bool YES # Configure BBedit to navigate between tabs in display order, not open order
defaults write com.barebones.bbedit EditorSoftWrap -bool YES
defaults write com.barebones.bbedit SoftWrapStyle -integer 2
defaults write com.barebones.bbedit EditingWindowShowPageGuide -bool NO

# Configure git
message "Configuring git..."
ln -f configs/git/.gitignore ~/.gitignore
ln -f configs/git/.gitconfig ~/.gitconfig
ln -f configs/git/.gitconfig-js ~/.gitconfig_js
ln -f configs/git/.gitconfig-ms ~/.gitconfig_ms

# Configure Hammerspoon
message "Configuring Hammerspoon"
ln -Fs $(pwd)/configs/hammerspoon ~/.hammerspoon # For some reason this would not work with a relative path, an absolute path was required

# Configure Karabiner-Elements
message "Configuring Karabiner Elements..."
ln -f configs/karabiner/karabiner.json ~/.config/karabiner

# Configure Kitty
message "Configuring Kitty..."
mkdir -p ~/.config/kitty 2> /dev/null # Redirect stderr to suppress dir already exists log
ln -f configs/kitty/kitty.conf ~/.config/kitty/

# Configure LLDB
message "Configuring LLDB..."
ln -f configs/lldb/.lldbinit ~/

# Configure vim
message "Configuring Vim..."
mkdir -p ~/.vim/.backup ~/.vim/.tmp ~/.vim/.undo 2> /dev/null # Redirect stderr to suppress dir already exists log
ln -f configs/vim/.vimrc ~/

# Configure Visual Studio Code
message "Configuring Visual Studio Code..."
mkdir -p ~/Library/Application\ Support/Code/User/ 2> /dev/null # Redirect stderr to suppress dir already exists log
ln -f configs/vscode/keybindings.json ~/Library/Application\ Support/Code/User/
ln -f configs/vscode/settings.json ~/Library/Application\ Support/Code/User/

message "Installing Visual Studio Code Extensions"
code --install-extension Arjun.swagger-viewer
code --install-extension blanu.vscode-styled-jsx
code --install-extension formulahendry.code-runner
code --install-extension LaurentTreguier.vscode-simple-icons # I like the 'minimalist' monocrome icons
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
code --install-extension ms-python.python
code --install-extension ms-vscode.cpptools
code --install-extension ms-vscode.go
code --install-extension msjsdiag.debugger-for-chrome
code --install-extension PeterJausovec.vscode-docker
code --install-extension rebornix.ruby
code --install-extension redhat.vscode-yaml
code --install-extension yzhang.markdown-all-in-one

# Configure .zshrc
message "Configuring .zshrc..."
ln -f configs/zsh/.zshrc ~/