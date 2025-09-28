echo "Configuring custom app icons..."

# Apps with iOS equivalant or nice-looking permutations of default icon can be generated with iconsur
sudo iconsur set /Applications/VLC.app

# Set custom icon images for some applications
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

sudo iconsur cache # Update the system icon cache and reload Finder & Dock