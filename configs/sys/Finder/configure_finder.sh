echo "Configuring Finder..."
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
defaults write com.apple.finder NewWindowTarget -string "PfHm" # Set new Finder windows without path to open in home dir

# Finder: Expand the Get Info “General”, “Open with”, and “Sharing & Permissions” File Info panes by default:
defaults write com.apple.finder FXInfoPanesExpanded -dict \
    General -bool true \
    OpenWith -bool true \
    Privileges -bool true
	
killall Finder
