echo "Configuring Login Script..."
ln -f configs/sys/login/login.sh ~/bin/
sudo cp -v configs/sys/login/com.user.loginscript.plist ~/Library/LaunchAgents # Unfortunately it doesn't appear plists can be linked (ln)
sudo chown root ~/Library/LaunchAgents/com.user.loginscript.plist
launchctl load ~/Library/LaunchAgents/com.user.loginscript.plist