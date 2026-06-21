#!/bin/bash
# Shared configuration — sourced by all task scripts

SSH_HOST="williampickup"
SSH_USER="will"
REMOTE_PATH="/var/www/htdocs/williampickup.org"

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
