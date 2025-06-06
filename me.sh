#!/bin/bash

function message {
	GREEN='\033[0;32m'
	NOCOLOR='\033[0m'
	printf "${GREEN}$1${NOCOLOR}\n"
}

# Sign into Mac App Store (mas dependency)
message "Prerequisite 1/4: Sign into App Store. Press any key to continue:"
read -n 1 -s

# Xcode Command Line Tools (brew dependency)
message "Prerequisite 2/4: Install the Xcode Command Line Tools by either installing and then opening Xcode or install the Xcode command line tools with 'xcode-select --install'"
message "After Xcode Command Line Tools are installed press any key to continue:"
read -n 1 -s

# Get sudo
message "Prerequisite 3/4: Sudo"
sudo -v

xcode-select -p 1>/dev/null;echo $?
if [ $? != 0 ]
then
message "Xcode Command Line Tools are not installed"
exit 1
fi

# Setup SSH
message "Prerequisite 4/4: Generate SSH keys"
ssh-keygen -t ed25519 -C "jon@jonschneider.me"
ssh-add -K ~/.ssh/id_ed25519
ssh-keygen -t rsa -C "jon@jonschneider.me"
ssh-add -K ~/.ssh/id_rsa

message "Configuring Mac..."

# Install Rosetta
message "Installing Rosetta 2..."
sudo softwareupdate --install-rosetta
message "Rosetta 2 Installed"

# Brew
message "Installing Homebrew"
- [ ] /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homeberw/bin/brews shellenv)"
brew update
brew doctor
brew bundle

# Install cheat.sh, which is unfortunately not available via brew
message "Installing cheat.sh"
mkdir -p ~/bin/
curl https://cht.sh/:cht.sh > ~/bin/cht.sh
chmod +x ~/bin/cht.sh

# Install trash command-line util, not available via brew
npm install --global trash-cli

# Ruby Config
message "Installing Ruby"
rbenv install $(rbenv install -l | grep -v - | tail -1) # Install Latest RBI Ruby using rbenv, installed via homebrew
export PATH="$HOME/.rbenv/bin:$PATH" # Add rbenv to path
eval "$(rbenv init -)" # Load rbenv

message "Installing Rubygems"
bundle install

# Configure Tmp Dir
message "Creating ~/Tmp dir..."
mkdir ~/Tmp
sudo rm -rf ~/Downloads && ln -s ~/Tmp ~/Downloads # Redirect Downloads to Tmp dir

./sync_app_config.sh
./sync_sys_config.sh