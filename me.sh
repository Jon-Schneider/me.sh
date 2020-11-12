#!/bin/bash

function message {
	GREEN='\033[0;32m'
	NOCOLOR='\033[0m'
	printf "${GREEN}$1${NOCOLOR}\n"
}

# Sign into Mac App Store (mas dependency)
message "Prerequisite 1/3: Sign into App Store. Press any key to continue:"
read -n 1 -s

# Xcode Command Line Tools (brew dependency)
message "Prerequisite 2/3: Install the Xcode Command Line Tools by either installing and then opening Xcode or install the Xcode command line tools with 'xcode-select --install'"
message "After Xcode Command Line Tools are installed press any key to continue:"
read -n 1 -s

# Get sudo
message "Prerequisite 3/3: Sudo"
sudo -v

xcode-select -p 1>/dev/null;echo $?
if [ $? != 0 ]
then
message "Xcode Command Line Tools are not installed"
exit 1
fi

# Brew
message "Installing Homebrew"
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew update
brew doctor
brew bundle

# Install cheat.sh, which is unfortunately not available via brew
message "Installing cheat.sh"
mkdir -p ~/bin/
curl https://cht.sh/:cht.sh > ~/bin/cht.sh
chmod +x ~/bin/cht.sh

# Ruby Config
message "Installing RVM"
show_loading
curl -sSL https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm # Required to run rvm commands
rvm install ruby
# rvm install jruby
# rvm install rbx

message "Installing Rubygems"
rvm use ruby
bundle install

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

message "Updating System Configuration"

# BBEdit Configuration 
message "Configuring BBEdit..."
mkdir -p ~/Library/Application\ Support/BBEdit
ln -s $(pwd)/bbedit/Setup ~/Library/Application\ Support/BBEdit/Setup # Have to symlink dir because changes aren't syncing with hard link (ln)
defaults write com.barebones.bbedit SurfNextPreviousInDisplayOrder -bool YES # Configure BBedit to navigate between tabs in display order, not open order
defaults write com.barebones.bbedit EditorSoftWrap -bool YES
defaults write com.barebones.bbedit SoftWrapStyle -integer 2
defaults write com.barebones.bbedit EditingWindowShowPageGuide -bool NO

# Configure Finder
message "Configuring Finder ..."
defaults write com.apple.Finder AppleShowAllFiles true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/OneDrive/"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false # Disable the warning when changing a file extension
defaults write com.apple.finder FXPreferredViewStyle -string "clmv" # Use Column View by default
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# Expand the Get Info “General”, “Open with”, and “Sharing & Permissions” File Info panes by default:
defaults write com.apple.finder FXInfoPanesExpanded -dict \
    General -bool true \
    OpenWith -bool true \
    Privileges -bool true
	
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
ln git/.gitignore ~/.gitignore
ln git/.gitconfig ~/.gitconfig
ln git/.gitconfig-js ~/.gitconfig_js
ln git/.gitconfig-ms ~/.gitconfig_ms

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

# Override system theme to set certain apps to always display in dark or light mode.
# To reset run 'defaults delete [bundleid] NSRequiresAquaSystemAppearance'
message "Overriding system theme in specific apps..."
defaults write com.microsoft.onenote.mac NSRequiresAquaSystemAppearance -bool no # OneNote should always be dark mode

message "Misc. Config..."

# Disable Aidrop by default
defaults write com.apple.NetworkBrowser DisableAirDrop -bool YES

# Hide Siri in Statusbar
defaults write com.apple.Siri StatusMenuVisible NO

# Hide Time Machine, Volume, User icon in Statusbar
for domain in ~/Library/Preferences/ByHost/com.apple.systemuiserver.*; do
    defaults write "${domain}" dontAutoLoad -array \
        "/System/Library/CoreServices/Menu Extras/TimeMachine.menu" \
        "/System/Library/CoreServices/Menu Extras/Volume.menu" \
        "/System/Library/CoreServices/Menu Extras/User.menu"
done
defaults write com.apple.systemuiserver menuExtras -array \
    "/System/Library/CoreServices/Menu Extras/Bluetooth.menu" \
    "/System/Library/CoreServices/Menu Extras/AirPort.menu" \
    "/System/Library/CoreServices/Menu Extras/Battery.menu" \
    "/System/Library/CoreServices/Menu Extras/Clock.menu"

# Apply Statusbar Changes
killall SystemUIServer

#Disable Boot Sound
sudo nvram SystemAudioVolume=" "

# Dxpand Save Panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Enable full keyboard access for all controls
# (e.g. enable Tab in modal dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Enable MacBook Air SuperDrive
sudo nvram boot-args="mbasd=1"

# Configure Dock
defaults write com.apple.dock persistent-apps -array # Remove all icons from dock
defaults write com.apple.dock autohide -bool true

# Disable the Launchpad gesture (pinch with thumb and three fingers)
defaults write com.apple.dock showLaunchpadGestureEnabled -int 0

# Check for software updates daily
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

message "Configuration Complete"
