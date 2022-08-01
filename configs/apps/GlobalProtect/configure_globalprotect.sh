echo "Configuring GlobalProtect..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Disable GlobalProtect autoconnecting at startup
sudo /usr/libexec/PlistBuddy -c "set :RunAtLoad false" /Library/LaunchAgents/com.paloaltonetworks.gp.pangpa.plist
sudo /usr/libexec/PlistBuddy -c "set :RunAtLoad false" /Library/LaunchAgents/com.paloaltonetworks.gp.pangps.plist
sudo /usr/libexec/PlistBuddy -c "delete :KeepAlive" /Library/LaunchAgents/com.paloaltonetworks.gp.pangps.plist
sudo /usr/libexec/PlistBuddy -c "add :KeepAlive bool false" /Library/LaunchAgents/com.paloaltonetworks.gp.pangps.plist