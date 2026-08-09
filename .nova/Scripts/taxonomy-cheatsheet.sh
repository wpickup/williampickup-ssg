#!/bin/bash
# Regenerate taxonomy.md and open it in Nova
set -e
source "$( dirname "${BASH_SOURCE[0]}" )/config.sh"

cd "$PROJECT_DIR"
ruby taxonomy.rb

osascript -e "tell application \"Nova\" to open \"$PROJECT_DIR/taxonomy.md\""
