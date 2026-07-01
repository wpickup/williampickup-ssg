#!/bin/bash
# Open the site documentation in Nova
source "$( dirname "${BASH_SOURCE[0]}" )/config.sh"
osascript -e "tell application \"Nova\" to open \"$PROJECT_DIR/DOCUMENTATION.md\""
