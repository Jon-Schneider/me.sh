#!/bin/bash

# Prerequisites
# You must install the Xcode Command Line tools prior to using homebrew.
# You can do this by installing and opening Xcode, agreeing to the license, and installing the dev
# tools prior to using Homebrew. Or you can run 'xcode-select --install' in the Terminal to install
# just the tools. To avoid configuration issues with Homebrew and Cask I recommend uninstalling and
# reinstalling Brew

# After, install BBEdit command line tools from Menu "BBEdit" > "Install Command Line Tools"

function message {
	GREEN='\033[0;32m'
	NOCOLOR='\033[0m'
	printf "${GREEN}$1${NOCOLOR}\n"
}

# Brew
message "Installing Homebrew"
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
message "Homebrew install completed"
brew update
brew doctor

message "Installing Brews..."
brew install carthage chisel duti mas zsh-syntax-highlighting
message "Finished Installing Brews..."

# Casks
message "Installing Casks"
brew cask install bbedit calibre coconutbattery cryptomator dash disk-inventory-x drawio epubquicklook flux karabiner-elements kindle kitty ksdiff libreoffice macdown microsoft-edge onedrive rectangle qlmarkdown qlmobi the-unarchiver torbrowser visual-studio-code
brew tap buo/cask-upgrade
message "Finished Installing Casks"

# Mac App Store
message "Installing Mac App Store Apps"
show_loading
mas install 1091189122 # Bear notes 
mas install 587512244  # Kaleidoscope
mas install 407963104  # Pixelmator
mas install 497799835  # Xcode
message "Finished Installing Mac App Store Apps"

# Ruby Config
message "Installing RVM"
show_loading
\curl -sSL https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm # Required to run rvm commands
rvm install ruby
# rvm install jruby
# rvm install rbx
message "Finished Installing RVM"

message "Installing Rubygems"
rvm use ruby
gem install cocoapods
gem install jekyll
gem install rails
message "Finished Installing Rubygems"

# Install Visual Studio Code Plugins
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
message "Finished Installing Visual Studio Code Extensions"

message "Updating System Configuration"

# BBEdit Configuration 
defaults write com.barebones.bbedit SurfNextPreviousInDisplayOrder -bool YES # Configure BBedit to navigate between tabs in display order, not open order
defaults write com.barebones.bbedit EditorSoftWrap -bool YES
defaults write com.barebones.bbedit SoftWrapStyle -integer 2
defaults write com.barebones.bbedit EditingWindowShowPageGuide -bool NO

# Configure OS to show hidden files in Finder
defaults write com.apple.Finder AppleShowAllFiles true
killall Finder

# Create Tmp Dir
mkdir ~/Tmp

# Set Screenshot Save Location
defaults write com.apple.screencapture location ~/Tmp
killall SystemUIServer

# Disable Annoying Screenshot Previews
defaults write com.apple.screencapture show-thumbnail -bool TRUE

# Copy Visual Studio Code config files to default location
cp -v vscode/keybindings.json ~/Library/Application\ Support/Code/User/
cp -v vscode/settings.json ~/Library/Application\ Support/Code/User/

# Set up .vimrc and .vim
mkdir -p ~/.vim/.backup ~/.vim/.tmp ~/.vim/.undo
cp .vimrc ~/

# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# Copy .zshrc
cp -v .zshrc ~/.zshrc

# Copy Kitty .conf
mkdir -p ~/.config/kitty
cp -v kitty.conf ~/.config/kitty/

# Add '~/bin' to bash PATH
sed -i '' -e '$a\' ~/.bash_profile && echo export "PATH=\"\$PATH:\$HOME/bin\"" >> ~/.bash_profile

# Set bash $GOPATH
sed -i '' -e '$a\' ~/.bash_profile && echo export "export GOPATH=\"$HOME/go\"" >> ~/.bash_profile

# Set up Karabiner configuration
mkdir ~/.config
cp -vR karabiner ~/.config

# Copy Rectangle Config
cp com.knollsoft.Rectangle.plist ~/Library/Preferences/

# Crank up the key repeat rates and trackpad speed. We've got stuff to do.
# You will have to log out for these preferences to be applied
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2
defaults write -g com.apple.mouse.scaling 6.0 # Double the default

# Configure git
cp ./.gitignore ~/.gitignore_global # Copy global .gitignore
cp -v .gitconfig ~/.gitconfig # Copy .gitconfig

# Configure Login Script
cp -v login/login.sh ~/
cp -v login/com.user.loginscript.plist ~/Library/LaunchAgents
launchctl load ~/Library/LaunchAgents/com.user.loginscript.plist

# Copy .lldbinit
cp -v .lldbinit ~/

# Set default apps
duti -s com.barebones.bbedit public.plain-text all # All plaintext files. Includes Unix hidden files
duti -s com.barebones.bbedit json all
duti -s com.barebones.bbedit sh all
duti -s com.barebones.bbedit txt all
duti -s com.uranusjr.macdown md all
duti -s com.microsoft.edgemac http # Set Edge as default browser

message "Configuration Complete"
