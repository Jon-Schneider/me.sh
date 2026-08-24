#!/bin/bash
set -euo pipefail

extensions=(
	Arjun.swagger-viewer
	blanu.vscode-styled-jsx
	eamodio.gitlens
	formulahendry.code-runner
	mateocerquetella.xcode-12-theme
	ms-kubernetes-tools.vscode-kubernetes-tools
	ms-python.python
	ms-vscode.cpptools
	ms-vscode.go
	ms-azuretools.vscode-docker
	pkief.material-icon-theme
	rangav.vscode-thunder-client
	shopify.ruby-lsp
	redhat.vscode-yaml
	yzhang.markdown-all-in-one
)

for extension in "${extensions[@]}"; do
	code --install-extension "$extension"
done
