#!/bin/bash
# Move a draft from _drafts/ to _posts/, marking it published
set -e
source "$( dirname "${BASH_SOURCE[0]}" )/config.sh"

DRAFTS_DIR="$PROJECT_DIR/_drafts"

# ── Build a list of draft filenames ───────────────────────────────────────────
shopt -s nullglob
DRAFT_FILES=("$DRAFTS_DIR"/*.md)
shopt -u nullglob

if [ ${#DRAFT_FILES[@]} -eq 0 ]; then
  osascript -e 'display alert "No drafts found" message "_drafts/ is empty." as warning'
  exit 0
fi

DRAFT_NAMES=()
for f in "${DRAFT_FILES[@]}"; do
  DRAFT_NAMES+=("$(basename "$f")")
done

# ── Ask which draft to publish via macOS dialog ───────────────────────────────
LIST_AS_APPLESCRIPT=$(printf '"%s", ' "${DRAFT_NAMES[@]}")
LIST_AS_APPLESCRIPT="{${LIST_AS_APPLESCRIPT%, }}"

CHOSEN=$(osascript -e "
  tell application \"Nova\"
    activate
  end tell
  set chosenItem to choose from list ${LIST_AS_APPLESCRIPT} with title \"Publish Draft\" with prompt \"Move which draft to _posts/?\"
  if chosenItem is false then
    error number -128
  end if
  return item 1 of chosenItem
" 2>/dev/null) || exit 0   # exit 0 on Cancel so Nova doesn't show an error

if [ -z "$CHOSEN" ]; then
  exit 0
fi

SRC="$DRAFTS_DIR/$CHOSEN"
DEST="$PROJECT_DIR/_posts/$CHOSEN"

if [ -f "$DEST" ]; then
  osascript -e "display alert \"File already exists in _posts/\" message \"$DEST\" as warning"
  exit 1
fi

# ── Move it, preferring git mv so history is preserved ────────────────────────
cd "$PROJECT_DIR"
if git ls-files --error-unmatch "_drafts/$CHOSEN" >/dev/null 2>&1; then
  git mv "_drafts/$CHOSEN" "_posts/$CHOSEN"
else
  mv "$SRC" "$DEST"
fi

echo "Published: _posts/$CHOSEN"

# ── Open the moved file in Nova ────────────────────────────────────────────────
osascript -e "tell application \"Nova\" to open \"$DEST\""
