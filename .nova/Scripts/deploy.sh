#!/bin/bash
# Build locally (sanity check), then trigger the real deploy via
# GitHub Actions -> GitHub Pages. Deployment itself always runs in CI now,
# not from this machine — this just kicks it off and watches it finish.
set -e
source "$( dirname "${BASH_SOURCE[0]}" )/config.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  williampickup-ssg — build + deploy"
echo "  $(date '+%d %b %Y %H:%M')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "→ Building site (local sanity check)..."
cd "$PROJECT_DIR"
ruby build.rb

echo ""
echo "→ Building Pagefind search index..."
npx pagefind \
  --site "$OUT_DIR" \
  --exclude-selectors "nav, footer, .site-header, .skip-link, .breadcrumb"

touch "$PROJECT_DIR/.last-build"
echo "  ✓ Local build OK"

if ! command -v gh >/dev/null 2>&1; then
  echo ""
  echo "  ⚠ gh CLI not found — can't trigger the deploy workflow from here."
  echo "    Install it (brew install gh), run 'gh auth login', or trigger"
  echo "    the deploy manually: https://github.com/wpickup/williampickup-ssg/actions/workflows/deploy.yml"
  exit 1
fi

echo ""
echo "→ Triggering GitHub Actions deploy..."
gh workflow run deploy.yml -R wpickup/williampickup-ssg

echo "→ Waiting for it to start..."
sleep 5
RUN_ID=$(gh run list -R wpickup/williampickup-ssg --workflow=deploy.yml --limit 1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN_ID" -R wpickup/williampickup-ssg --exit-status

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ Build + deploy finished"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
