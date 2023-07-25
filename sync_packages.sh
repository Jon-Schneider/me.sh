#!/bin/bash

function message {
	GREEN='\033[0;32m'
	NOCOLOR='\033[0m'
	printf "${GREEN}$1${NOCOLOR}\n"
}

message "Running 'bundle install'..."
bundle install

message "Running 'brew bundle'..."
brew bundle --verbose # Slow so I want verbose output to know something is happening

message "Installing Visual Studio Code Extensions"
code --install-extension Arjun.swagger-viewer
code --install-extension blanu.vscode-styled-jsx
code --install-extension eamodio.gitlens
code --install-extension formulahendry.code-runner
code --install-extension LaurentTreguier.vscode-simple-icons # I like the 'minimalist' monocrome icons
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
code --install-extension ms-python.python
code --install-extension ms-vscode.cpptools
code --install-extension ms-vscode.go
code --install-extension msjsdiag.debugger-for-chrome
code --install-extension PeterJausovec.vscode-docker
code --install-extension rangav.vscode-thunder-client
code --install-extension rebornix.ruby
code --install-extension redhat.vscode-yaml
code --install-extension yzhang.markdown-all-in-one

configs/sys/Icons/configure_app_icons.sh