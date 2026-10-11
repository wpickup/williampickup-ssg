#!/bin/bash
# Build the site then generate the Pagefind search index
set -e
source "$( dirname "${BASH_SOURCE[0]}" )/config.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  williampickup-ssg — build + index"
echo "  $(date '+%d %b %Y %H:%M')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "→ Building site..."
cd "$PROJECT_DIR"
ruby build.rb

echo ""
echo "→ Building Pagefind search index..."
# Indexing options (excluded selectors etc.) come from pagefind.yml in the
# project root — Pagefind reads it from the working directory, which the
# `cd` above already set.
npx --yes pagefind --site "$OUT_DIR"

echo ""
echo "  ✓ Search index written to $OUT_DIR/pagefind/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
