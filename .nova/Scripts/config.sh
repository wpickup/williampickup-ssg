#!/bin/bash
# Shared configuration — sourced by all task scripts

# Resolve project root relative to this script's location (.nova/Scripts/)
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"

# Nova-triggered builds write straight to the local preview folder so the
# generator (here, in Web-Development) stays separate from what's actually
# served at ~/Sites. This is a dedicated subfolder, not ~/Sites/williampickup.org
# itself — build.rb does `rm_rf` + recreate on every build, which would
# otherwise destroy anything else living alongside the site (e.g. this
# project's own .claude/launch.json). Override with SSG_OUT_DIR if you ever
# need to, but don't rely on it propagating from a shell profile — Nova's
# task runner is GUI-launched and may not inherit exported shell variables
# the way a terminal does.
OUT_DIR="${SSG_OUT_DIR:-/Users/will/Sites/williampickup.org/_site}"
export SSG_OUT_DIR="$OUT_DIR"

# Same propagation concern as above applies to secrets — a real token
# can't live in this file (it's committed to git), and Nova's GUI task
# runner may not see a shell-profile-exported var. Read from a gitignored
# local file instead, created once with:
#   echo "your-token" > .webmention-token
if [ -z "${WEBMENTION_TOKEN:-}" ] && [ -f "$PROJECT_DIR/.webmention-token" ]; then
  export WEBMENTION_TOKEN="$(cat "$PROJECT_DIR/.webmention-token")"
fi
