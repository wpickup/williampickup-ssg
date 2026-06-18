#!/bin/bash
# Build the site including draft posts
set -e
source "$( dirname "${BASH_SOURCE[0]}" )/config.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  williampickup-ssg — build (with drafts)"
echo "  $(date '+%d %b %Y %H:%M')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROJECT_DIR"
ruby build.rb --drafts

echo ""
echo "  ✓ Site built to _out/ (drafts included)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
