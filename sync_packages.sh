#!/bin/bash
set -euo pipefail

repo_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$repo_root" || exit 1

source "lib/common.sh"

message "Running 'brew bundle'..."
brew bundle --verbose # Slow so I want verbose output to know something is happening

message "Installing Visual Studio Code Extensions"
code --install-extension Arjun.swagger-viewer
code --install-extension blanu.vscode-styled-jsx
code --install-extension eamodio.gitlens
code --install-extension formulahendry.code-runner
code --install-extension mateocerquetella.xcode-12-theme
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
code --install-extension ms-python.python
code --install-extension ms-vscode.cpptools
code --install-extension ms-vscode.go
code --install-extension ms-azuretools.vscode-docker # replaces deprecated PeterJausovec.vscode-docker
code --install-extension pkief.material-icon-theme
code --install-extension rangav.vscode-thunder-client
code --install-extension shopify.ruby-lsp # replaces unmaintained rebornix.ruby
code --install-extension redhat.vscode-yaml
code --install-extension yzhang.markdown-all-in-one
