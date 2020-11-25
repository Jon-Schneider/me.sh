#!/bin/bash

function message {
	GREEN='\033[0;32m'
	NOCOLOR='\033[0m'
	printf "${GREEN}$1${NOCOLOR}\n"
}

message "Updating System Configuration..."

# Configure Login Script
message "Setting up login script..."
ln login/login.sh ~/bin/
cp -v login/com.user.loginscript.plist ~/Library/LaunchAgents # Unfortunately it doesn't appear plists can be linked (ln)
sudo chown root ~/Library/LaunchAgents/com.user.loginscript.plist
launchctl load ~/Library/LaunchAgents/com.user.loginscript.plist

# Configure Finder
message "Configuring Finder..."
defaults write com.apple.Finder FXPreferredViewStyle clmv # Default to column view
# Unfortunately there is no way to enable grouping by default in finder windows; the best I can do is set my preferred finder grouping and sorting
defaults write com.apple.Finder FXUseGroups -bool true # Group files by default. This gets toggled by Finder when grouping is enabled in a dir but doesn't seem respected by default. Adding anyway.
defaults write com.apple.finder FXPreferredGroupBy -string "Kind" # Default to grouping by Kind
defaults write com.apple.finder FXArrangeGroupViewBy -string "Name" # Sort groups by name

defaults write com.apple.Finder AppleShowAllFiles true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/OneDrive/"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false # Disable the warning when changing a file extension
defaults write com.apple.finder FXPreferredViewStyle -string "clmv" # Use Column View by default
defaults write com.apple.finder WarnOnEmptyTrash -bool false
defaults write com.apple.finder QuitMenuItem -bool YES # Enable Cmd + Q to quit

# Finder: Expand the Get Info “General”, “Open with”, and “Sharing & Permissions” File Info panes by default:
defaults write com.apple.finder FXInfoPanesExpanded -dict \
    General -bool true \
    OpenWith -bool true \
    Privileges -bool true
	
killall Finder

# Disable Annoying Screenshot Previews
message "Disabling annoying screenshot previews..."
defaults write com.apple.screencapture show-thumbnail -bool TRUE

# Set Screenshot Save Location
message "Setting screenshot save location..."
defaults write com.apple.screencapture location ~/Tmp
killall SystemUIServer

# Crank up the key repeat rates and trackpad speed. We've got stuff to do.
# You will have to log out for these preferences to be applied
message "Configuring Keyboard and Trackpad..."
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2
defaults write -g com.apple.mouse.scaling 6.0 # Double the default

# Set default apps
message "Setting default apps..."
duti -s com.binarynights.ForkLift-3 public.folder all
duti -s com.barebones.bbedit public.plain-text all # All plaintext files. Includes Unix hidden files
duti -s com.barebones.bbedit json all
duti -s com.barebones.bbedit sh all
duti -s com.barebones.bbedit txt all
duti -s com.barebones.bbedit pub all # Libreoffice wants to open .pub for some reason, but the only .pub files I see are public keys
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
killall SystemUIServer # Apply Statusbar Changes

#Disable Boot Sound
sudo nvram SystemAudioVolume=" "

# Dxpand Save Panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Automatically quit printer app once print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Enable full keyboard access for all controls
# (e.g. enable Tab in modal dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Enable MacBook Air SuperDrive
sudo nvram boot-args="mbasd=1"

# Configure Dock
defaults write com.apple.dock persistent-apps -array # Remove all icons from dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.Dock autohide-delay -float 1.0 # Delay hidden dock appearance by 1s
defaults write com.apple.dock orientation left # Move dock to left side of screen
defaults write com.apple.dock tilesize -int 50; # Set dock icon size
killall Dock # Restart dock to apply orientation and icon size

# Disable the Launchpad gesture (pinch with thumb and three fingers)
defaults write com.apple.dock showLaunchpadGestureEnabled -int 0

# Check for software updates daily
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1