echo "Configuring custom app icons..."

# Apps with iOS equivalant or nice-looking permutations of default icon can be generated with iconsur
sudo iconsur set /Applications/BBEdit.app -l
sudo iconsur set /Applications/Calibre.app -l
sudo iconsur set /Applications/CHIRP.app -l -s 0.8
sudo iconsur set /Applications/coconutBattery.app -l
sudo iconsur set /Applications/CubicSDR.app -l
sudo iconsur set /Applications/Cryptomator.app
sudo iconsur set /Applications/Dash.app -l
sudo iconsur set /Applications/Disk\ Inventory\ X.app -l
sudo iconsur set /Applications/Firefox.app
sudo iconsur set /Applications/Gramps.app -s 0.7 -l
sudo iconsur set /Applications/Horo.app -l
sudo iconsur set /Applications/Kindle.app
sudo iconsur set /Applications/kitty.app -l -c cccccc
sudo iconsur set /Applications/Microsoft\ Edge.app
sudo iconsur set /Applications/Microsoft\ Excel.app
sudo iconsur set /Applications/Microsoft\ OneNote.app
sudo iconsur set /Applications/Microsoft\ Word.app
sudo iconsur set /Applications/Minecraft.app
sudo iconsur set /Applications/OneDrive.app
sudo iconsur set /Applications/RescueTime.app
sudo iconsur set /Applications/TorBrowser.app -l
sudo iconsur set /Applications/VLC.app
sudo iconsur set /Applications/Vimac.app -l
sudo iconsur set /Applications/Visual\ Studio\ Code.app -l -c 333333
sudo iconsur cache

# Set custom icon images for some applications
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

fileicon set /Applications/Flux.app $current_dir/Flux.icns
touch /Applications/Flux.app

fileicon set /Applications/LibreOffice.app $current_dir/LibreOffice.icns
touch /Applications/LibreOffice.app

fileicon set /Applications/MacDown.app $current_dir/MacDown.icns
touch /Applications/MacDown.app