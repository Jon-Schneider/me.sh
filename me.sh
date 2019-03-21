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

# Install Mac App Store Apps
function install_mas {
	message "Installing Mac App Store Apps"
	show_loading
	mas install 427475982 # BreakTime
	mas install 784801555 # OneNote
	mas install 407963104 # Pixelmator
	mas install 497799835 # Xcode
	message "Finished Installing Mac App Store Apps"
}

# Install Rubygems
function install_gems {
	message "Installing Rubygems"
	rvm use ruby
	gem install cocoapods
	gem install jekyll
	gem install rails
	message "Finished Installing Rubygems"
}

# Install Visual Studio Code Packages
function install_vscode_packages {
	message "Installing Rubygems Visual Studio Code Extensions"
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
	message "Finished Installing Rubygems Visual Studio Code Extensions"
}

# Brew
message "Installing Homebrew"
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
message "Homebrew install completed"
brew update
brew doctor

message "Installing Brews..."
brew install appledoc carthage mas mysql postgresql yarn zsh
message "Finished Installing Brews..."

# Cask
message "Installing Homebrew Cask"
brew tap caskroom/cask
message "Finished Installing Homebrew Cask"

message "Installing Casks"
brew cask install android-studio bbedit calibre coconutbattery cryptomator dash disk-inventory-x epubquicklook flux google-chrome karabiner-elements kindle iterm2 libreoffice macdown nextcloud qlmarkdown qlmobi spectacle the-unarchiver torbrowser visual-studio-code
message "Finished Installing Casks"

install_mas

message "Installing RVM"
show_loading
\curl -sSL https://get.rvm.io | bash -s stable
source /Users/jon/.rvm/scripts/rvm # Required to run rvm commands
rvm install ruby
# rvm install jruby
# rvm install rbx
message "Finished Installing RVM"

install_gems

install_vscode_packages

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

# Add '~/bin' to bash PATH
sed -i '' -e '$a\' ~/.bash_profile && echo export "PATH=\"\$PATH:\$HOME/bin\"" >> ~/.bash_profile

# Set bash $GOPATH
sed -i '' -e '$a\' ~/.bash_profile && echo export "export GOPATH=\"$HOME/go\"" >> ~/.bash_profile

# Set up Karabiner configuration
mkdir ~/.config
cp -vR karabiner ~/.config

# Crank up the key repeat rates. Note you may have to log out for these preferences to be applied
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2

message "Configuration Complete"
