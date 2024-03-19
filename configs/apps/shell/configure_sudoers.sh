echo "Configuring sudoers"

# https://www.smileykeith.com/2021/08/12/xcode-select-sudoers/
echo "%admin ALL=NOPASSWD: /usr/bin/xcode-select,/usr/bin/xcodebuild -runFirstLaunch" | sudo tee /etc/sudoers.d/xcode