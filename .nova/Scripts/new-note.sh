#!/bin/bash
# Create a new draft note and open it in Nova
set -e
source "$( dirname "${BASH_SOURCE[0]}" )/config.sh"

# ── Ask for title via macOS dialog ────────────────────────────────────────────
TITLE=$(osascript -e '
  tell application "Nova"
    activate
  end tell
  set result to text returned of (display dialog "New note title (optional — leave blank for an untitled note):" default answer "" with title "New Note" buttons {"Cancel", "Create"} default button "Create")
' 2>/dev/null) || exit 0   # exit 0 on Cancel so Nova doesn't show an error

# ── Derive slug and date ──────────────────────────────────────────────────────
TODAY=$(date '+%Y-%m-%d')
if [ -n "$TITLE" ]; then
  SLUG=$(echo "$TITLE" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9 ]//g' \
    | sed 's/  */ /g' \
    | sed 's/ /-/g' \
    | sed 's/^-//;s/-$//')
else
  SLUG="untitled"
fi

FILE="$PROJECT_DIR/_notes/${TODAY}-${SLUG}.md"

# ── Bail if file already exists ───────────────────────────────────────────────
if [ -f "$FILE" ]; then
  osascript -e "display alert \"File already exists\" message \"$FILE\" as warning"
  exit 1
fi

# ── Write front matter — a note's own shape, not a post's ─────────────────────
# draft: true here, not the _drafts/ folder — Note has no location-based
# drafting like Post does; load_notes only ever reads _notes/. Publish by
# removing this line (or setting it to false) once the note is ready.
cat > "$FILE" << FRONTMATTER
---
slug: ${TODAY}-${SLUG}
date: ${TODAY}
FRONTMATTER

if [ -n "$TITLE" ]; then
  echo "title: $TITLE" >> "$FILE"
fi

cat >> "$FILE" << FRONTMATTER
draft: true
---

FRONTMATTER

echo "Created: $FILE"

# ── Open in Nova ──────────────────────────────────────────────────────────────
osascript -e "tell application \"Nova\" to open \"$FILE\""
