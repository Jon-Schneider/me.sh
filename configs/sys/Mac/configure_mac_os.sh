
# Disable Screenshot Previews
echo "Disabling screenshot previews..."
defaults write com.apple.screencapture show-thumbnail -bool TRUE

# Set Screenshot Save Location
echo "Setting screenshot save location..."
defaults write com.apple.screencapture location ~/Tmp
killall SystemUIServer

# Crank up the key repeat rates and trackpad speed. We've got stuff to do.
# You will have to log out for these preferences to be applied
echo "Configuring Keyboard and Trackpad..."
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2
defaults write -g com.apple.mouse.scaling 6.0 # Double the default

# Set default apps
echo "Setting default apps..."
duti -s com.barebones.bbedit public.plain-text all # All plaintext files. Includes Unix hidden files
duti -s com.barebones.bbedit json all
duti -s com.barebones.bbedit sh all
duti -s com.barebones.bbedit txt all
duti -s com.barebones.bbedit pub all # Libreoffice wants to open .pub for some reason, but the only .pub files I see are public keys
duti -s com.uranusjr.macdown md all
duti -s com.microsoft.edgemac http # Set Edge as default browser

# Override system theme to set certain apps to always display in dark or light mode.
# To reset run 'defaults delete [bundleid] NSRequiresAquaSystemAppearance'
echo "Overriding system theme in specific apps..."
defaults write com.microsoft.onenote.mac NSRequiresAquaSystemAppearance -bool no # OneNote should always be dark mode

echo "Configuring Statusbar..."
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

echo "Setting Misc. Config..."

# Disable Aidrop by default
defaults write com.apple.NetworkBrowser DisableAirDrop -bool YES

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
defaults write com.apple.Dock autohide-delay -float 0.1
defaults write com.apple.dock autohide-time-modifier -float 0.25
defaults write com.apple.dock orientation left # Move dock to left side of screen
defaults write com.apple.dock tilesize -int 50; # Set dock icon size
killall Dock # Restart dock to apply orientation and icon size

# Disable the Launchpad gesture (pinch with thumb and three fingers)
defaults write com.apple.dock showLaunchpadGestureEnabled -int 0

# Check for software updates daily
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1