#!/bin/bash

# Prerequisites
# You must install the Xcode Command Line tools prior to using homebrew.
# You can do this by installing and opening Xcode, agreeing to the license, and installing the dev
# tools prior to using Homebrew. Or you can run 'xcode-select --install' in the Terminal to install
# just the tools. To avoid configuration issues with Homebrew and Cask I recommend uninstalling and
# reinstalling Brew

function message {
	G='\033[0;32m'
	NC='\033[0m'
	printf "${G}$1${NC}\n"
}

# Set up global .gitignore

cp ./.gitignore ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global

# Install packages managed by Homebrew
function install_brews {
	message "Installing your brews"
	brew update
	brew doctor
	brew install appledoc
	brew install carthage
	brew install mas
	brew install mysql
	brew install postgresql
	brew install yarn
	message "Brews install completed"
}

# Install Applications via Cask
function install_casks {
	message "Installing Casks"
	# brew cask install android-studio
	brew cask install bbedit
	# brew cask install calibre
	brew cask install ccleaner
	brew cask install coconutbattery
	brew cask install cyberduck
	brew cask install dash
	brew cask install disk-inventory-x
	brew cask install epubquicklook
	brew cask install flux
	brew cask install google-chrome
	# brew cask install kindle
	brew cask install libreoffice
	brew cask install macdown
	brew cask install nextcloud
	brew cask install qlmarkdown
	brew cask install qlmobi
	# brew cask install torbrowser
	brew cask install the-unarchiver
	brew cask install visual-studio-code
	message "Finished Installing Casks"
}

# Install Mac App Store Apps
function install_mas {
	mas install 497799835 # Xcode
	mas install 410628904 # Wunderlist
	mas install 407963104 # Pixelmator
	mas install 568494494 # Pocket
	mas install 784801555 # OneNote
	mas install 427475982 # BreakTime
}

# Install Rubygems
function install_gems {
	message "Installing Rubygems"
	rvm use ruby
	gem install cocoapods #sudo for system dir, non-sudo for RVM install
	gem install jekyll
	gem install rails #sudo for system dir, non-sudo for RVM install
	message "Rubygems install completed"
}

# Install Visual Studio Code Packages
function install_vscode_packages {
	code --install-extension Arjun.swagger-viewer
	code --install-extension blanu.vscode-styled-jsx
	code --install-extension formulahendry.code-runner
	code --install-extension ms-vscode.go
	code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
	code --install-extension ms-python.python
	code --install-extension msjsdiag.debugger-for-chrome
	code --install-extension PeterJausovec.vscode-docker
	code --install-extension rebornix.ruby
	code --install-extension redhat.vscode-yaml
	code --install-extension yzhang.markdown-all-in-one
}

# Brew
message "Installing Homebrew"
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
message "Homebrew install completed"

install_brews

# Mac App Store Apps
install_mas

# Cask
message "Installing Cask"
brew tap caskroom/cask
message "Finished Installing Cask"

install_casks

# Ruby and Rails

message "Installing RVM"
\curl -sSL https://get.rvm.io | bash -s stable
source /Users/jon/.rvm/scripts/rvm # Required to run rvm commands
rvm install ruby
# rvm install jruby
# rvm install rbx
message "Finished Installing RVM"

install_gems

install_pip_packages

install_vscode_packages

defaults write com.barebones.bbedit SurfNextPreviousInDisplayOrder -bool YES # Configure BBedit to navigate between tabs in display order, not open order
defaults write com.barebones.bbedit EditorSoftWrap -bool YES
defaults write com.barebones.bbedit SoftWrapStyle -integer 2
defaults write com.barebones.bbedit EditingWindowShowPageGuide -bool NO

# Configure OS to show hidden files in Finder
defaults write com.apple.Finder AppleShowAllFiles true
killall Finder

# Set Screenshot Save Location
defaults write com.apple.screencapture location ~/Downloads

# Copy Atom Keymap file to default Location
cp -v keymap.cson ~/.atom

# Set up .vimrc and .vim
mkdir -p ~/.vim/.backup ~/.vim/.tmp ~/.vim/.undo
cp .vimrc ~/

# Add '~/bin' to PATH
sed -i '' -e '$a\' ~/.bash_profile && echo export "PATH=\"\$PATH:\$HOME/bin\"" >> ~/.bash_profile

message "Configuration Complete"
