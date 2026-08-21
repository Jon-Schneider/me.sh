#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/lib/common.sh"

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

if ! xcode-select -p &>/dev/null; then
	message "Xcode Command Line Tools are not installed"
	exit 1
fi

# Setup SSH
message "Prerequisite 4/4: Generate SSH keys"
if [ ! -f ~/.ssh/id_ed25519 ]; then
	ssh-keygen -t ed25519 -C "jon@jonschneider.me"
fi
ssh-add -K ~/.ssh/id_ed25519
if [ ! -f ~/.ssh/id_rsa ]; then
	ssh-keygen -t rsa -C "jon@jonschneider.me"
fi
ssh-add -K ~/.ssh/id_rsa

message "Configuring Mac..."

# Install Rosetta
message "Installing Rosetta 2..."
sudo softwareupdate --install-rosetta --agree-to-license
message "Rosetta 2 Installed"

# Brew
message "Installing Homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
if ! grep -q 'brew shellenv' ~/.zprofile; then
	echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
brew update
brew doctor || true # brew doctor exits non-zero on warnings, which shouldn't abort setup
brew bundle

# Install trash command-line util, not available via brew
npm install --global trash-cli

# Ruby Config
message "Installing Ruby"
rbenv install $(rbenv install -l | grep -v - | tail -1) # Install Latest MRI Ruby using rbenv, installed via homebrew
export PATH="$HOME/.rbenv/bin:$PATH" # Add rbenv to path
eval "$(rbenv init -)" # Load rbenv

# Configure Tmp Dir
message "Creating ~/Tmp dir..."
mkdir -p ~/Tmp
if [ ! -L ~/Downloads ]; then
	message "~/Downloads is a real folder. Its contents will be moved to ~/Tmp, then it will be replaced with a symlink to ~/Tmp."
	message "Press any key to continue (Ctrl+C to abort):"
	read -n 1 -s
	if [ -d ~/Downloads ]; then
		# Move everything (including dotfiles) out first so nothing is lost when the folder is deleted
		find ~/Downloads -mindepth 1 -maxdepth 1 -exec mv {} ~/Tmp/ \;
	fi
	sudo rm -rf ~/Downloads && ln -s ~/Tmp ~/Downloads # Redirect Downloads to Tmp dir
fi

# Configure repo link for cd
mkdir -p ~/Developer/jsc
ln -sfn ~/Developer/jsc ~/repo
ln -sfn ~/Developer/jsc ~/repos

"${SCRIPT_DIR}/sync_app_config.sh"
"${SCRIPT_DIR}/sync_sys_config.sh"
