#!/bin/bash
set -euo pipefail

echo "Configuring Finicky..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ln -sfn $current_dir/.finicky.js ~/.finicky.js