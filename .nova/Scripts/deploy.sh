#!/bin/bash
# Build, index, and deploy to Vultr via rsync over SSH
set -e
source "$( dirname "${BASH_SOURCE[0]}" )/config.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  williampickup-ssg — build + deploy"
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
echo "→ Deploying to $SSH_HOST:$REMOTE_PATH ..."
rsync \
  --archive \
  --compress \
  --delete \
  --human-readable \
  --progress \
  --omit-dir-times \
  --no-perms \
  --exclude='.DS_Store' \
  --exclude='drafts/' \
  "$OUT_DIR/" \
  "$SSH_USER@$SSH_HOST:$REMOTE_PATH/"

touch "$PROJECT_DIR/.last-build"

echo ""
echo "  ✓ Deploy complete"

echo "→ Sending webmentions for new outbound links..."
ruby "$PROJECT_DIR/send_webmentions.rb" || echo "  (non-fatal — deploy already succeeded)"

if ! git -C "$PROJECT_DIR" diff --quiet -- _data/webmentions_sent.json 2>/dev/null; then
  git -C "$PROJECT_DIR" add _data/webmentions_sent.json
  git -C "$PROJECT_DIR" commit -m "Update webmention state" -q
  echo "  → Committed updated webmention state (not pushed)"
fi

echo "→ Checking live CSP headers..."
CSP=$(curl -sI "https://williampickup.org/" | grep -i "content-security-policy")
if echo "$CSP" | grep -q "wasm-unsafe-eval"; then
  echo "  ✓ CSP contains wasm-unsafe-eval"
else
  echo "  ⚠ WARNING: CSP missing wasm-unsafe-eval — search may not work"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ Build + deploy finished"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
