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
npx pagefind \
  --site "$OUT_DIR" \
  --exclude-selectors "nav, footer, .site-header, .skip-link, .breadcrumb"

echo ""
echo "  ✓ Search index written to _out/pagefind/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
