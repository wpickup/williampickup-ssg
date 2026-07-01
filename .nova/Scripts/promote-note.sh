#!/bin/bash
# Move a note from _notes/ to _posts/, scaffolding in the recommended
# post front matter fields a note doesn't have (description, topics,
# categories, tags) as blank placeholders.
set -e
source "$( dirname "${BASH_SOURCE[0]}" )/config.sh"

NOTES_DIR="$PROJECT_DIR/_notes"

# ── Build a list of note filenames ────────────────────────────────────────────
shopt -s nullglob
NOTE_FILES=("$NOTES_DIR"/*.md)
shopt -u nullglob

if [ ${#NOTE_FILES[@]} -eq 0 ]; then
  osascript -e 'display alert "No notes found" message "_notes/ is empty." as warning'
  exit 0
fi

NOTE_NAMES=()
for f in "${NOTE_FILES[@]}"; do
  NOTE_NAMES+=("$(basename "$f")")
done

# ── Ask which note to promote via macOS dialog ────────────────────────────────
LIST_AS_APPLESCRIPT=$(printf '"%s", ' "${NOTE_NAMES[@]}")
LIST_AS_APPLESCRIPT="{${LIST_AS_APPLESCRIPT%, }}"

CHOSEN=$(osascript -e "
  tell application \"Nova\"
    activate
  end tell
  set chosenItem to choose from list ${LIST_AS_APPLESCRIPT} with title \"Promote Note\" with prompt \"Move which note to _posts/?\"
  if chosenItem is false then
    error number -128
  end if
  return item 1 of chosenItem
" 2>/dev/null) || exit 0   # exit 0 on Cancel so Nova doesn't show an error

if [ -z "$CHOSEN" ]; then
  exit 0
fi

SRC="$NOTES_DIR/$CHOSEN"
DEST="$PROJECT_DIR/_posts/$CHOSEN"

if [ -f "$DEST" ]; then
  osascript -e "display alert \"File already exists in _posts/\" message \"$DEST\" as warning"
  exit 1
fi

# ── Move it, preferring git mv so history is preserved ────────────────────────
cd "$PROJECT_DIR"
if git ls-files --error-unmatch "_notes/$CHOSEN" >/dev/null 2>&1; then
  git mv "_notes/$CHOSEN" "_posts/$CHOSEN"
else
  mv "$SRC" "$DEST"
fi

# ── Scaffold in missing recommended Post fields ───────────────────────────────
# A note's front matter is only slug/date/title/draft. Post gracefully
# defaults everything else (no crash either way), but the result is a
# thin post — no topic colour, no card description — unless these are
# filled in. Insert blank placeholders for whatever's not already
# present, right after the opening "---", leaving everything else in
# the file untouched (no YAML re-parse/re-dump, so existing formatting
# — including multi-line values — can't be mangled).
ADD=""
grep -q '^description:' "$DEST" || ADD="${ADD}description: \n"
grep -q '^topics:'      "$DEST" || ADD="${ADD}topics: \n"
grep -q '^categories:'  "$DEST" || ADD="${ADD}categories: \n"
grep -q '^tags:'        "$DEST" || ADD="${ADD}tags: \n"

if [ -n "$ADD" ]; then
  awk -v add="$ADD" '
    NR==1 && /^---$/ { print; printf "%s", add; next }
    { print }
  ' "$DEST" > "$DEST.tmp" && mv "$DEST.tmp" "$DEST"
fi

echo "Promoted: _posts/$CHOSEN"
echo "Now live at /posts/${CHOSEN%.md}.html once published — was /notes/${CHOSEN%.md}.html; nothing redirects the old URL."

# ── Open the moved file in Nova ────────────────────────────────────────────────
osascript -e "tell application \"Nova\" to open \"$DEST\""
