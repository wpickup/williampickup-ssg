#!/bin/bash
# Build the site with the Ruby SSG
set -e
source "$( dirname "${BASH_SOURCE[0]}" )/config.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  williampickup-ssg — build"
echo "  $(date '+%d %b %Y %H:%M')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROJECT_DIR"
ruby build.rb "$@"

echo ""
echo "  ✓ Site built to _out/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
