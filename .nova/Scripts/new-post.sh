#!/bin/bash
# Create a new draft post and open it in Nova
set -e
source "$( dirname "${BASH_SOURCE[0]}" )/config.sh"

# ── Ask for title via macOS dialog ────────────────────────────────────────────
TITLE=$(osascript -e '
  tell application "Nova"
    activate
  end tell
  set result to text returned of (display dialog "New post title:" default answer "" with title "New Post" buttons {"Cancel", "Create"} default button "Create")
' 2>/dev/null) || exit 0   # exit 0 on Cancel so Nova doesn't show an error

if [ -z "$TITLE" ]; then
  exit 0
fi

# ── Derive slug and date ──────────────────────────────────────────────────────
TODAY=$(date '+%Y-%m-%d')
SLUG=$(echo "$TITLE" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9 ]//g' \
  | sed 's/  */ /g' \
  | sed 's/ /-/g' \
  | sed 's/^-//;s/-$//')

FILE="$PROJECT_DIR/_drafts/${TODAY}-${SLUG}.md"

# ── Bail if file already exists ───────────────────────────────────────────────
if [ -f "$FILE" ]; then
  osascript -e "display alert \"File already exists\" message \"$FILE\" as warning"
  exit 1
fi

# ── Write front matter ────────────────────────────────────────────────────────
cat > "$FILE" << FRONTMATTER
---
title: $TITLE
slug: $SLUG
date: $TODAY
description:
topics:
categories:
tags:
image_url:
image_focal_point:
use_featured_image: false
has_sidenotes: false
featured: false
---

FRONTMATTER

echo "Created: $FILE"

# ── Open in Nova ──────────────────────────────────────────────────────────────
osascript -e "tell application \"Nova\" to open \"$FILE\""
