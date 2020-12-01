#!/bin/bash

function message {
	GREEN='\033[0;32m'
	NOCOLOR='\033[0m'
	printf "${GREEN}$1${NOCOLOR}\n"
}

message "Updating Application Configuration..."

# Recursively execute all 'config_*.sh scripts in configs/apps'
find -E configs/apps -name 'configure_*.sh' -exec bash {} \;