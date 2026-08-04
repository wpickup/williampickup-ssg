#!/bin/zsh
set -euo pipefail

ROOT="${1:-$PWD}"
cd "$ROOT"

if ! command -v bundle >/dev/null 2>&1; then
  echo "bundler is not installed or not on PATH" >&2
  exit 1
fi

mkdir -p .nova-lsp-logs

typeset -a pids

cleanup() {
  for pid in "${pids[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
}

trap cleanup EXIT INT TERM

start_server() {
  local name="$1"
  shift
  echo "Starting $name..."
  "$@" > ".nova-lsp-logs/${name}.log" 2>&1 &
  pids+=("$!")
}

start_server ruby-lsp bundle exec ruby-lsp
start_server rubocop bundle exec rubocop --lsp
start_server erb-lint bundle exec erb_lint --lsp

echo "Language servers running in $ROOT"
echo "Logs: $ROOT/.nova-lsp-logs"
echo "Press Ctrl-C to stop all servers"

wait
