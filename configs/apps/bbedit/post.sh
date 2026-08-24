#!/bin/bash
set -euo pipefail

defaults write com.barebones.bbedit SurfNextPreviousInDisplayOrder -bool YES
defaults write com.barebones.bbedit EditorSoftWrap -bool YES
defaults write com.barebones.bbedit SoftWrapStyle -integer 2
defaults write com.barebones.bbedit EditingWindowShowPageGuide -bool NO
