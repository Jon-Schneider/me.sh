#!/bin/bash

function message {
	GREEN='\033[0;32m'
	NOCOLOR='\033[0m'
	printf "${GREEN}$1${NOCOLOR}\n"
}

# Xcode Command Line Tools (brew dependency)
message "To start, install the Xcode Command Line Tools by either installing and then opening Xcode or install the Xcode command line tools with 'xcode-select --install'"
message "After Xcode Command Line Tools are installed press any key to continue:"
read -n 1 -s

xcode-select -p 1>/dev/null;echo $?
if [ $? != 0 ]
then
message "Xcode Command Line Tools are not installed"
exit 1
fi

# Brew
message "Installing Homebrew"
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
message "Homebrew install completed"
brew update
brew doctor

message "Installing Brews..."
brew install carthage chisel duti mas zsh-syntax-highlighting
message "Finished Installing Brews..."

# Install cheat.sh, which is unfortunately not available via brew
message "Installing cheat.sh"
mkdir -p ~/bin/
curl https://cht.sh/:cht.sh > ~/bin/cht.sh
chmod +x ~/bin/cht.sh
message "Finished installing cheat.sh"

# Casks
message "Installing Casks" 
brew cask install bbedit calibre coconutbattery cryptomator dash disk-inventory-x drawio epubquicklook flux hammerspoon karabiner-elements kindle kitty ksdiff libreoffice macdown microsoft-edge onedrive qlmarkdown qlmobi the-unarchiver torbrowser visual-studio-code
brew tap buo/cask-upgrade
message "Finished Installing Casks"

# Mac App Store
message "Installing Mac App Store Apps"
show_loading
mas install 587512244  # Kaleidoscope
mas install 784801555  # OneNote
mas install 407963104  # Pixelmator
mas install 497799835  # Xcode
message "Finished Installing Mac App Store Apps"

# Ruby Config
message "Installing RVM"
show_loading
curl -sSL https://get.rvm.io | bash -s stable
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
message "Configuring BBEdit..."
mkdir -p ~/Library/Application\ Support/BBEdit
ln -s ~/src/me.sh/bbedit/Setup ~/Library/Application\ Support/BBEdit/Setup # Have to symlink dir because changes aren't syncing with hard link (ln)
defaults write com.barebones.bbedit SurfNextPreviousInDisplayOrder -bool YES # Configure BBedit to navigate between tabs in display order, not open order
defaults write com.barebones.bbedit EditorSoftWrap -bool YES
defaults write com.barebones.bbedit SoftWrapStyle -integer 2
defaults write com.barebones.bbedit EditingWindowShowPageGuide -bool NO

# Configure OS to show hidden files in Finder
message "Configuring Finder to show hidden files..."
defaults write com.apple.Finder AppleShowAllFiles true
killall Finder

# Create Tmp Dir
message "Creating ~/Tmp dir..."
mkdir ~/Tmp

# Redirect Downloads to Tmp dir
sudo rm -rf ~/Downloads && ln -s ~/Tmp ~/Downloads

# Set Screenshot Save Location
message "Setting screenshot save location..."
defaults write com.apple.screencapture location ~/Tmp
killall SystemUIServer

# Disable Annoying Screenshot Previews
message "Disabling annoying screenshot previews..."
defaults write com.apple.screencapture show-thumbnail -bool TRUE

# Visual Studio Code Config
message "Configuring Visual Studio Code..."
mkdir ~/Library/Application\ Support/Code/User/
ln vscode/keybindings.json ~/Library/Application\ Support/Code/User/
ln vscode/settings.json ~/Library/Application\ Support/Code/User/

# Configure vom
message "Configuring Vim..."
mkdir -p ~/.vim/.backup ~/.vim/.tmp ~/.vim/.undo
ln .vimrc ~/

# Install Oh My Zsh
message "Installing Oh My Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# Configure .zshrc
message "Configuring .zshrc..."
ln .zshrc ~/

# Kitty Config
message "Configuirng Kitty..."
mkdir -p ~/.config/kitty
ln kitty.conf ~/.config/kitty/

# Karabiner Config
message "Configuring Karabiner Elements..."
ln karabiner/karabiner.json ~/.config/karabiner

# Configure Hammerspoon
message "Configuring Hammerspoon"
ln -s $(pwd)/hammerspoon ~/.hammerspoon # For some reason this would not work with a relative path, an absolute path was required

# Crank up the key repeat rates and trackpad speed. We've got stuff to do.
# You will have to log out for these preferences to be applied
message "Configuring Keyboard and Trackpad..."
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2
defaults write -g com.apple.mouse.scaling 6.0 # Double the default

# Configure git
message "Configuring git..."
ln .gitignore ~/.gitignore_global
ln .gitconfig ~/.gitconfig

# Configure Login Script
message "Setting up login script..."
ln login/login.sh ~/bin/
cp -v login/com.user.loginscript.plist ~/Library/LaunchAgents # Unfortunately it doesn't appear plists can be linked (ln)
sudo chown root ~/Library/LaunchAgents/com.user.loginscript.plist
launchctl load ~/Library/LaunchAgents/com.user.loginscript.plist

# Configure .lldbinit
message "Configuring lldb config..."
ln .lldbinit ~/

# Set default apps
message "Setting default apps..."
duti -s com.barebones.bbedit public.plain-text all # All plaintext files. Includes Unix hidden files
duti -s com.barebones.bbedit json all
duti -s com.barebones.bbedit sh all
duti -s com.barebones.bbedit txt all
duti -s com.uranusjr.macdown md all
duti -s com.microsoft.edgemac http # Set Edge as default browser

# Theming
# Override system theme to set certain apps to always display in dark or light mode.
# To reset run 'defaults delete [bundleid] NSRequiresAquaSystemAppearance'
message "Overriding system theme in specific apps..."
defaults write com.microsoft.onenote.mac NSRequiresAquaSystemAppearance -bool no # OneNote should always be dark mode

message "Configuration Complete"
