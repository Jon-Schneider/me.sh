#!/bin/bash

function message {
	GREEN='\033[0;32m'
	NOCOLOR='\033[0m'
	printf "${GREEN}$1${NOCOLOR}\n"
}

# Sign into Mac App Store (mas dependency)
message "Prerequisite 1/3: Sign into App Store. Press any key to continue:"
read -n 1 -s

# Xcode Command Line Tools (brew dependency)
message "Prerequisite 2/3: Install the Xcode Command Line Tools by either installing and then opening Xcode or install the Xcode command line tools with 'xcode-select --install'"
message "After Xcode Command Line Tools are installed press any key to continue:"
read -n 1 -s

# Get sudo
message "Prerequisite 3/3: Sudo"
sudo -v

xcode-select -p 1>/dev/null;echo $?
if [ $? != 0 ]
then
message "Xcode Command Line Tools are not installed"
exit 1
fi

# Brew
message "Installing Homebrew"
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew update
brew doctor
brew bundle

# Install cheat.sh, which is unfortunately not available via brew
message "Installing cheat.sh"
mkdir -p ~/bin/
curl https://cht.sh/:cht.sh > ~/bin/cht.sh
chmod +x ~/bin/cht.sh

# Ruby Config
message "Installing RVM"
show_loading
curl -sSL https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm # Required to run rvm commands
rvm install ruby
# rvm install jruby
# rvm install rbx

message "Installing Rubygems"
rvm use ruby
bundle install

# Install Visual Studio Code Plugins
message "Installing Visual Studio Code Extensions"
code --install-extension Arjun.swagger-viewer
code --install-extension blanu.vscode-styled-jsx
code --install-extension formulahendry.code-runner
code --install-extension LaurentTreguier.vscode-simple-icons # I like the 'minimalist' monocrome icons
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
code --install-extension ms-python.python
code --install-extension ms-vscode.cpptools
code --install-extension ms-vscode.go
code --install-extension msjsdiag.debugger-for-chrome
code --install-extension PeterJausovec.vscode-docker
code --install-extension rebornix.ruby
code --install-extension redhat.vscode-yaml
code --install-extension yzhang.markdown-all-in-one

# Install Oh My Zsh
message "Installing Oh My Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# Configure Tmp Dir
message "Creating ~/Tmp dir..."
mkdir ~/Tmp
sudo rm -rf ~/Downloads && ln -s ~/Tmp ~/Downloads # Redirect Downloads to Tmp dir

# Configure Login Script
message "Setting up login script..."
ln login/login.sh ~/bin/
cp -v login/com.user.loginscript.plist ~/Library/LaunchAgents # Unfortunately it doesn't appear plists can be linked (ln)
sudo chown root ~/Library/LaunchAgents/com.user.loginscript.plist
launchctl load ~/Library/LaunchAgents/com.user.loginscript.plist

./sync_app_config.sh
./sync_system_config.sh