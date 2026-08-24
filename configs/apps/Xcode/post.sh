#!/bin/bash
set -euo pipefail

# Configure Xcode to display build duration, not finish time.
defaults write com.apple.dt.Xcode ShowBuildOperationDuration YES
