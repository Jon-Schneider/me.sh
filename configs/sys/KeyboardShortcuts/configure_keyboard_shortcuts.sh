echo "Configuring System Keyboard Shortcuts..."
mkdir -p ~/Library/LaunchAgents
sudo cp -v configs/sys/KeyboardShortcuts/com.local.KeyRemapping.plist ~/Library/LaunchAgents # Unfortunately it doesn't appear plists can be linked (ln)
sudo chown root ~/Library/LaunchAgents/com.local.KeyRemapping.plist
sudo launchctl load ~/Library/LaunchAgents/com.local.KeyRemapping.plist