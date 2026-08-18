echo "Configuring Login Script..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ln -sfn "$current_dir/login.sh" ~/bin/login.sh
mkdir -p ~/Library/LaunchAgents
sudo cp -v configs/sys/login/com.user.loginscript.plist ~/Library/LaunchAgents # Unfortunately it doesn't appear plists can be linked (ln)
sudo chown root ~/Library/LaunchAgents/com.user.loginscript.plist
sudo launchctl load ~/Library/LaunchAgents/com.user.loginscript.plist