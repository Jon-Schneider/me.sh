echo "Configuring custom app icons..."

# Apps with iOS equivalant or nice-looking permutations of default icon can be generated with iconsur
sudo iconsur set /Applications/calibre.app -l
sudo iconsur set /Applications/CHIRP.app -l -s 0.8
sudo iconsur set /Applications/coconutBattery.app -l
sudo iconsur set /Applications/CubicSDR.app -l
sudo iconsur set /Applications/Gramps.app -s 0.7 -l
sudo iconsur set /Applications/Horo.app -l
sudo iconsur set /Applications/RescueTime.app
sudo iconsur set /Applications/VLC.app
sudo iconsur cache

# Set custom icon images for some applications
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

sudo iconsur cache # Update the system icon cache and reload Finder & Dock