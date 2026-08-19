#!/usr/bin/env bash
# deploy.sh — build williampickup.org locally for preview
# Usage: ./deploy.sh [--drafts]
#
# This only builds the site locally (useful for previewing before you push).
# Actual deployment happens automatically in GitHub Actions on every push
# to main. To trigger a rebuild without a new commit: gh workflow run deploy.yml

set -euo pipefail

OUT_DIR="${SSG_OUT_DIR:-_out}"

echo "==> Building site..."
ruby build.rb "$@"

echo ""
echo "==> Indexing with Pagefind..."
npx --yes pagefind --site "$OUT_DIR"

echo ""
echo "==> Done. Built to $OUT_DIR."
echo "    Push to main to deploy (or: gh workflow run deploy.yml to rebuild without a new commit)."
