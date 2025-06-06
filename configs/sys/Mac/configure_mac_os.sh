# Create Developer Dir
mkdir "~/Developer" # I used to use '~/src' but then I found out '~/Developer' has a system icon

# Disable Screenshot Previews
echo "Disabling screenshot previews..."
defaults write com.apple.screencapture show-thumbnail -bool FALSE

# Set Screenshots Save Location
echo "Setting screenshot save location..."
defaults write com.apple.screencapture location ~/Tmp # System Screenshots
defaults write com.apple.iphonesimulator ScreenShotSaveLocation -string ~/Tmp # iPhone Simulator Screenshots
killall SystemUIServer

# Crank up the key repeat rates and trackpad speed. We've got stuff to do.
# You will have to log out for these preferences to be applied, or run 'killall Dock' or 'killall SystemUIServer'
echo "Configuring Keyboard and Trackpad..."
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2
defaults write -g com.apple.trackpad.scaling 3.0

# Set default apps
echo "Setting default apps..."
duti -s com.barebones.bbedit public.plain-text all # All plaintext files. Includes Unix hidden files
duti -s com.barebones.bbedit public.data all # I need this to open Podfiles using bbedit instead of TextEdit. I don't know if this is universal or just my project
duti -s com.barebones.bbedit json all
duti -s com.barebones.bbedit pub all # Libreoffice wants to open .pub for some reason, but the only .pub files I see are public keys
duti -s com.barebones.bbedit sh all
duti -s com.barebones.bbedit ts all # VLC recognizes .ts as a media file, but the only .ts files I see are typescript
duti -s com.barebones.bbedit txt all
duti -s com.barebones.bbedit yml all
duti -s abnerworks.Typora md all
duti -s com.googe.Chrome http # Set Edge as default browser
duti -s com.macpaw.site.theunarchiver zip # Use The Unarchiver for zips

# Override system theme to set certain apps to always display in dark or light mode
# To reset run 'defaults delete [bundleid] NSRequiresAquaSystemAppearance'
echo "Overriding system theme in specific apps..."
defaults write com.apple.iCal NSRequiresAquaSystemAppearance -bool yes # Calendar should always be light mode
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

#Disable Boot Sound
sudo nvram StartupMute=%01

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

# Configure Dock
defaults write com.apple.dock persistent-apps -array # Remove all icons from dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.Dock autohide-delay -float 0.1
defaults write com.apple.dock autohide-time-modifier -float 0.25
defaults write com.apple.dock tilesize -int 50; # Set dock icon size
defaults write com.apple.Dock static-only -bool true # Only show running apps on dock
defaults write com.apple.dock wvous-corner-ignore-modifier -bool YES # Disable Notes.app opening from corner mouseover
killall Dock # Restart dock to apply orientation and icon size

# Disable the Launchpad gesture (pinch with thumb and three fingers)
defaults write com.apple.dock showLaunchpadGestureEnabled -int 0

# Check for software updates daily
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

# Enable TouchId for Command Line Sudo. https://nicholasmangold.com/blog/how-use-sudo-touch-id-mac
if grep -i "pam_tid.so" /etc/pam.d/sudo
then
  echo "Sudo already configured to use TouchID"
else
  echo "Configuring sudo to accep TouchId"
sudo sed -i '' '2i\
auth       sufficient     pam_tid.so\
' /etc/pam.d/sudo
fi

# Reduce obnoxious spacing between menu bar icons
defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 7
defaults -currentHost write -globalDomain NSStatusItemSpacing -int 7