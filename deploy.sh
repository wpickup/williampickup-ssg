#!/usr/bin/env bash
# deploy.sh — build williampickup.org locally for preview
# Usage: ./deploy.sh [--drafts]
#
# This only builds the site locally (useful for previewing before you push).
# Actual deployment happens via GitHub Actions -> GitHub Pages:
#   gh workflow run deploy.yml

set -euo pipefail

OUT_DIR="${SSG_OUT_DIR:-_out}"

echo "==> Building site..."
ruby build.rb "$@"

echo ""
echo "==> Indexing with Pagefind..."
npx --yes pagefind --site "$OUT_DIR"

echo ""
echo "==> Done. Built to $OUT_DIR."
echo "    To deploy: gh workflow run deploy.yml"
