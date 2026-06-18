#!/usr/bin/env bash
# deploy.sh — build and deploy williampickup.org
# Usage: ./deploy.sh [--drafts]
# Set DEPLOY_DEST to your rsync destination, e.g. user@host:/var/www/williampickup.org/

set -euo pipefail

DEPLOY_DEST="${DEPLOY_DEST:-}"

echo "==> Building site..."
ruby build.rb "$@"

echo ""
echo "==> Indexing with Pagefind..."
npx --yes pagefind --site _out

if [ -z "$DEPLOY_DEST" ]; then
  echo ""
  echo "Build complete. To deploy, set DEPLOY_DEST and re-run:"
  echo "  DEPLOY_DEST=user@host:/path/to/webroot ./deploy.sh"
  exit 0
fi

echo ""
echo "==> Deploying to ${DEPLOY_DEST}..."
rsync -avz --delete \
  --exclude '.DS_Store' \
  --exclude 'drafts/' \
  _out/ "${DEPLOY_DEST}"

echo ""
echo "==> Done."
