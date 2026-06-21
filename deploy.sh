#!/usr/bin/env bash
# deploy.sh — build and deploy williampickup.org
# Usage: ./deploy.sh [--drafts]
# Set DEPLOY_DEST to your rsync destination, e.g. user@host:/var/www/williampickup.org/

set -euo pipefail

DEPLOY_DEST="${DEPLOY_DEST:-}"
OUT_DIR="${SSG_OUT_DIR:-_out}"

echo "==> Building site..."
ruby build.rb "$@"

echo ""
echo "==> Indexing with Pagefind..."
npx --yes pagefind --site "$OUT_DIR"

if [ -z "$DEPLOY_DEST" ]; then
  echo ""
  echo "Build complete. To deploy, set DEPLOY_DEST and re-run:"
  echo "  DEPLOY_DEST=user@host:/path/to/webroot ./deploy.sh"
  exit 0
fi

echo ""
echo "==> Deploying to ${DEPLOY_DEST}..."
rsync -avz --delete \
  --omit-dir-times \
  --no-perms \
  --exclude '.DS_Store' \
  --exclude 'drafts/' \
  "$OUT_DIR/" "${DEPLOY_DEST}"

echo ""
echo "==> Sending webmentions for new outbound links..."
ruby send_webmentions.rb || echo "  (non-fatal — deploy already succeeded)"

if ! git diff --quiet -- _data/webmentions_sent.json 2>/dev/null; then
  git add _data/webmentions_sent.json
  git commit -m "Update webmention state" -q
  echo "  → Committed updated webmention state (not pushed)"
fi

echo ""
echo "==> Done."
