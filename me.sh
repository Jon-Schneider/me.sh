# I am Jon (and so can you!)

# Prerequisites
# You must install the Xcode Command Line tools prior to using homebrew. 
# You can do this by installing and opening Xcode, agreeing to the license, and installing the dev tools prior to using 
# Homebrew. Or you can run 'xcode-select --install' in the Terminal to install just the tools.
# To avoid configuration issues with Homebrew and Cask I recommend uninstalling and reinstalling Brew

function message {
	G='\033[0;32m'
	NC='\033[0m'
	printf "${G}$1${NC}\n"
}

# Set up global .gitignore

cp ./.gitignore ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global

# Install packages managed by Homebrew
function install_brews {
	message "Installing your brews"
	brew update
	brew doctor
	brew install appledoc
	brew install carthage
	brew install mas
	brew install mysql
	brew install postgresql
	brew install python
	message "Brews install completed"
}

# Install Applications via Cask
function install_casks {
	message "Installing Casks"
	# Personal commented out
	brew cask install android-studio
	brew cask install atom
	brew cask install audacity
	# brew cask install calibre
	brew cask install ccleaner
	brew cask install coconutbattery
	brew cask install cyberduck
	brew cask install dash
	brew cask install deploymate
	brew cask install disk-inventory-x
	brew cask install dukto
	brew cask install evernote
	brew cask install gimp
	brew cask install google-chrome
	# brew cask install kindle
	brew cask install libreoffice
	brew cask install macdown
	# brew cask install minecraft
	brew cask install owncloud
	brew cask install qlmarkdown
	brew cask install qlmobi
	brew cask install slack
	brew cask install sonic-visualiser
	brew cask install textwrangler
	# brew cask install torbrowser
	brew cask install the-unarchiver
	brew cask install transmission
	brew cask install virtualbox
	brew cask install vlc
	message "Finished Installing Casks"
}

# Install Mac App Store Apps
function install_mas {
	mas install 497799835 # Xcode
	mas install 407963104 # Pixelmator
	mas install 784801555 # OneNote
	mas install 427475982 # BreakTime
}

# Install Rubygems
function install_gems {
	message "Installing Rubygems"
	rvm use ruby
	gem install cocoapods #sudo for system dir, non-sudo for RVM install
	gem install rails #sudo for system dir, non-sudo for RVM install
	message "Rubygems install completed"
}

# Install Atom Packages
function install_atom_packages {
	message "Installing Atom Packages"
	apm install language-swift
	apm install swift-debugger
	apm install minimap
	apm install atom-terminal
	apm instal autocomplete-clang
	message "Finished Installing Atom Packages"
}

# Install Pip Packages
function install_pip_packages {
	message "Installing Pip Packages"
	pip install -U pip
	pip install grip
	message "Finished Installing Pip Packages"
}

# Brew
message "Installing Homebrew"
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
message "Homebrew install completed"

install_brews

# Mac App Store Apps
install_mas

# Cask
message "Installing Cask"
brew tap caskroom/cask
message "Finished Installing Cask"

install_casks

# Ruby and Rails

message "Installing RVM"
\curl -sSL https://get.rvm.io | bash -s stable
rvm install ruby
rvm install jruby
rvm install rbx
message "Finished Installing RVM"

install_gems

install_pip_packages

install_atom_packages

# Configure TextWrangler to navigate between tabs in display order, not open order
defaults write com.barebones.textwrangler SurfNextPreviousInDisplayOrder -bool YES

message "Configuration Complete! Now you are Jon too!"
