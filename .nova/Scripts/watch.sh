#!/bin/bash
# Watch source files and rebuild automatically on change
# Requires fswatch: brew install fswatch
set -e
source "$( dirname "${BASH_SOURCE[0]}" )/config.sh"

if ! command -v fswatch &>/dev/null; then
  echo "  ✗ fswatch not found. Install it with:"
  echo "      brew install fswatch"
  echo "  Then re-run this task."
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  williampickup-ssg — watch + rebuild"
echo "  $(date '+%d %b %Y %H:%M')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Watching for changes. Press Ctrl-C to stop."
echo ""

# Initial build
cd "$PROJECT_DIR"
ruby build.rb --drafts
echo ""
echo "  ✓ Initial build done — waiting for changes..."
echo ""

# Watch every build input: content, data, templates, the builder itself,
# and the static dirs build.rb copies into the output. Any directory added
# to build.rb (a new *_DIR or STATIC_DIRS entry) should be added here too.
# _drafts/ is gitignored and may not exist on a fresh clone — create it so
# fswatch doesn't fail on a missing path.
mkdir -p "$PROJECT_DIR/_drafts"
fswatch -o \
  "$PROJECT_DIR/_posts" \
  "$PROJECT_DIR/_drafts" \
  "$PROJECT_DIR/_notes" \
  "$PROJECT_DIR/_journeys" \
  "$PROJECT_DIR/_pages" \
  "$PROJECT_DIR/_photos" \
  "$PROJECT_DIR/_books" \
  "$PROJECT_DIR/_data" \
  "$PROJECT_DIR/_templates" \
  "$PROJECT_DIR/_partials" \
  "$PROJECT_DIR/build.rb" \
  "$PROJECT_DIR/css" \
  "$PROJECT_DIR/javascript" \
  "$PROJECT_DIR/fonts" \
  "$PROJECT_DIR/assets" \
  | while read -r count; do
      echo "  → Change detected — rebuilding... ($(date '+%H:%M:%S'))"
      cd "$PROJECT_DIR"
      ruby build.rb --drafts && echo "  ✓ Done" || echo "  ✗ Build failed (see above)"
      echo ""
    done
