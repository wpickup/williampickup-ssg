#!/bin/bash
# Shared configuration — sourced by all task scripts

SSH_HOST="williampickup"
SSH_USER="will"
REMOTE_PATH="/var/www/htdocs/williampickup.org"

# Resolve project root relative to this script's location (.nova/Scripts/)
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
OUT_DIR="$PROJECT_DIR/_out"
