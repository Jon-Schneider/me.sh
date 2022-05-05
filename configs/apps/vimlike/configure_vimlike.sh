echo "Configuring Vimlike Safari Extension..."

mkdir -p ~/Library/Group\ Containers/group.net.jasminestudios.Vimlike/Library/Preferences/ 2> /dev/null # Redirect stderr to suppress dir already exists log
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ln -f $current_dir/group.net.jasminestudios.Vimlike.plist ~/Library/Group\ Containers/group.net.jasminestudios.Vimlike/Library/Preferences/
echo "Configured Vimlike Safari Extension. Extension will need to be manually activated in Safari."