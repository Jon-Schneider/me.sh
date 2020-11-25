#!/bin/bash

function message {
	GREEN='\033[0;32m'
	NOCOLOR='\033[0m'
	printf "${GREEN}$1${NOCOLOR}\n"
}

message "Running 'bundle install'..."
bundle install

message "Running 'brew bundle'..."
brew bundle