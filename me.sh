#!/bin/bash

# Prerequisites
# You must install the Xcode Command Line tools prior to using homebrew.
# You can do this by installing and opening Xcode, agreeing to the license, and installing the dev
# tools prior to using Homebrew. Or you can run 'xcode-select --install' in the Terminal to install
# just the tools. To avoid configuration issues with Homebrew and Cask I recommend uninstalling and
# reinstalling Brew

function show_loading {
	chars="/-\|"

	while :; do
		for (( i=0; i<${#chars}; i++ )); do
			sleep 0.5
			echo -en "${chars:$i:1}" "\r"
		done
	done
}

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
	message "Installing Brews..."
	show_loading
	brew update
	brew doctor
	brew install appledoc
	brew install carthage
	brew install mas
	brew install mysql
	brew install postgresql
	brew install yarn
	brew install zsh
	message "Finished Installing Brews..."
}

# Install Applications via Cask
function install_casks {
	message "Installing Casks"
	show_loading
	brew cask install android-studio
	brew cask install bbedit
	brew cask install calibre
	brew cask install ccleaner
	brew cask install coconutbattery
	brew cask install cryptomator
	brew cask install cyberduck
	brew cask install dash
	brew cask install disk-inventory-x
	brew cask install epubquicklook
	brew cask install flux
	brew cask install google-chrome
	brew cask install karabiner-elements
	brew cask install kindle
	brew cask install iterm2
	brew cask install libreoffice
	brew cask install macdown
	brew cask install nextcloud
	brew cask install qlmarkdown
	brew cask install qlmobi
	brew cask install spectacle
	brew cask install the-unarchiver
	brew cask install torbrowser
	brew cask install visual-studio-code
	message "Finished Installing Casks"
}

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
	show_loading
	rvm use ruby
	gem install cocoapods
	gem install jekyll
	gem install rails
	message "Finished Installing Rubygems"
}

# Install Visual Studio Code Packages
function install_vscode_packages {
	message "Installing Rubygems Visual Studio Code Extensions"
	show_loading
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

install_brews

# Cask
message "Installing Homebrew Cask"
brew tap caskroom/cask
message "Finished Installing Homebrew Cask"

install_casks

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
sh -c "$(wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"

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
